#!/bin/bash
# Grok browser backend detection, setup, and login status management
#
# Usage:
#   grok_setup.sh check    — Detect best available browser backend + login status
#   grok_setup.sh setup    — Create playwright-grok MCP from existing playwright config
#   grok_setup.sh reset    — Clear cached login status (after user re-logs in)
#   grok_setup.sh status <logged_in|logged_out>  — Update login status cache
#
# Check exit codes:
#   0  READY         — Backend available (BACKEND= chrome | playwright-grok | playwright)
#   1  NEEDS_SETUP   — Has playwright, can run 'setup' to create playwright-grok
#   2  NOT_AVAILABLE  — No browser backend found, skip Grok source
#
# Status file: ~/.claude/tech-research/.grok-status.json

set -euo pipefail

CLAUDE_JSON="$HOME/.claude.json"
STATUS_DIR="$HOME/.claude/tech-research"
STATUS_FILE="$STATUS_DIR/.grok-status.json"

# Logged-out status expires after this many hours (user may have re-logged in)
LOGOUT_EXPIRY_HOURS=2

# --- Helpers ---

ensure_status_dir() {
    mkdir -p "$STATUS_DIR"
}

read_mcp_servers() {
    # Read mcpServers keys from ~/.claude.json
    python3 -c "
import json, sys
try:
    config = json.load(open('$CLAUDE_JSON'))
    servers = config.get('mcpServers', {})
    for name in servers:
        print(name)
except Exception:
    pass
" 2>/dev/null
}

has_mcp_server() {
    local name="$1"
    read_mcp_servers | grep -qx "$name"
}

get_playwright_config() {
    # Extract playwright MCP config as JSON
    python3 -c "
import json
config = json.load(open('$CLAUDE_JSON'))
pw = config.get('mcpServers', {}).get('playwright', {})
if pw:
    print(json.dumps(pw))
else:
    print('')
" 2>/dev/null
}

read_login_status() {
    # Returns: logged_in | logged_out | unknown
    # logged_out auto-expires after LOGOUT_EXPIRY_HOURS
    python3 -c "
import json, time, sys
try:
    data = json.load(open('$STATUS_FILE'))
    status = data.get('status', 'unknown')
    ts = data.get('timestamp', 0)
    age_hours = (time.time() - ts) / 3600
    backend = data.get('backend', '')

    if status == 'logged_out' and age_hours > $LOGOUT_EXPIRY_HOURS:
        # Expired logged_out — user may have re-logged in, be optimistic
        print('unknown')
    else:
        print(status)
except Exception:
    print('unknown')
" 2>/dev/null
}

write_login_status() {
    local status="$1"
    local backend="${2:-}"
    ensure_status_dir
    python3 -c "
import json, time
data = {
    'status': '$status',
    'backend': '$backend',
    'timestamp': time.time()
}
with open('$STATUS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
}

# --- Commands ---

cmd_check() {
    # Priority 1: claude-in-chrome (user's real Chrome, has login state)
    if has_mcp_server "claude-in-chrome"; then
        local login_status
        login_status=$(read_login_status)
        echo "BACKEND=chrome"
        echo "LOGIN_STATUS=$login_status"
        echo "STATUS: READY"
        echo "ACTION: Use claude-in-chrome tools for Grok queries."
        exit 0
    fi

    # Priority 2: playwright-grok (dedicated profile with login persistence)
    if has_mcp_server "playwright-grok"; then
        local login_status
        login_status=$(read_login_status)
        echo "BACKEND=playwright-grok"
        echo "LOGIN_STATUS=$login_status"
        echo "STATUS: READY"
        echo "ACTION: Use playwright-grok tools for Grok queries."
        exit 0
    fi

    # Priority 3: playwright (default, no profile — works but may not be logged in)
    if has_mcp_server "playwright"; then
        echo "BACKEND=playwright"
        echo "LOGIN_STATUS=unknown"
        echo "STATUS: NEEDS_SETUP"
        echo "ACTION: Has playwright MCP. Run 'grok_setup.sh setup' to create a dedicated playwright-grok instance with login persistence."
        exit 1
    fi

    # Nothing available
    echo "BACKEND=none"
    echo "LOGIN_STATUS=unknown"
    echo "STATUS: NOT_AVAILABLE"
    echo "ACTION: No browser MCP configured. Install Playwright MCP or Claude-in-Chrome extension to enable Grok source."
    exit 2
}

cmd_setup() {
    if ! [ -f "$CLAUDE_JSON" ]; then
        echo "ERROR: $CLAUDE_JSON not found."
        exit 1
    fi

    if has_mcp_server "playwright-grok"; then
        echo "playwright-grok already configured in $CLAUDE_JSON. No action needed."
        exit 0
    fi

    local pw_config
    pw_config=$(get_playwright_config)
    if [ -z "$pw_config" ]; then
        echo "ERROR: No 'playwright' MCP server found in $CLAUDE_JSON. Configure playwright MCP first."
        exit 1
    fi

    # Add playwright-grok by cloning playwright config with --user-data-dir
    python3 -c "
import json, sys

config = json.load(open('$CLAUDE_JSON'))
pw = config['mcpServers']['playwright']

# Deep copy and add --user-data-dir
import copy
grok = copy.deepcopy(pw)
args = grok.get('args', [])

# Only add if not already present
if '--user-data-dir' not in ' '.join(str(a) for a in args):
    args.extend(['--user-data-dir', '$HOME/.playwright-grok-profile'])
    grok['args'] = args

config['mcpServers']['playwright-grok'] = grok

with open('$CLAUDE_JSON', 'w') as f:
    json.dump(config, f, indent=2)

print('SUCCESS: Added playwright-grok to $CLAUDE_JSON')
print('  Profile dir: $HOME/.playwright-grok-profile')
print('  Restart Claude Code to activate the new MCP server.')
" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to update $CLAUDE_JSON."
        exit 1
    fi
}

cmd_reset() {
    if [ -f "$STATUS_FILE" ]; then
        rm -f "$STATUS_FILE"
        echo "Login status cache cleared. Next Grok query will check login state fresh."
    else
        echo "No cached login status to clear."
    fi
}

cmd_status() {
    local new_status="${1:-}"
    local backend="${2:-}"
    if [ -z "$new_status" ]; then
        echo "Usage: grok_setup.sh status <logged_in|logged_out> [backend]"
        exit 1
    fi
    write_login_status "$new_status" "$backend"
    echo "Login status updated: $new_status (backend: ${backend:-unspecified})"
}

# --- Main ---

case "${1:-}" in
    check)  cmd_check ;;
    setup)  cmd_setup ;;
    reset)  cmd_reset ;;
    status) cmd_status "${2:-}" "${3:-}" ;;
    *)
        echo "Usage: grok_setup.sh <check|setup|reset|status>"
        echo ""
        echo "  check   — Detect best browser backend and login status"
        echo "  setup   — Create playwright-grok MCP from existing playwright"
        echo "  reset   — Clear cached login status"
        echo "  status  — Update login status (logged_in|logged_out)"
        exit 1
        ;;
esac
