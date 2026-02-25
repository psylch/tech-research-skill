#!/bin/bash
# Grok browser backend detection, setup, and login status management
#
# Usage:
#   grok_setup.sh check      — Detect best available browser backend + login status (JSON)
#   grok_setup.sh preflight  — Alias for check
#   grok_setup.sh setup      — Create playwright-grok MCP from existing playwright config
#   grok_setup.sh reset      — Clear cached login status (after user re-logs in)
#   grok_setup.sh status <logged_in|logged_out>  — Update login status cache
#
# Exit codes:
#   0  Success / READY
#   1  Recoverable error (e.g., needs setup, missing args)
#   2  Unrecoverable error (no browser backend available)
#
# Status file: ~/.claude/tech-research/.grok-status.json

set -euo pipefail

CLAUDE_JSON="$HOME/.claude.json"
STATUS_DIR="$HOME/.claude/tech-research"
STATUS_FILE="$STATUS_DIR/.grok-status.json"

# Logged-out status expires after this many hours (user may have re-logged in)
LOGOUT_EXPIRY_HOURS=2

# --- Helpers ---

# Bootstrap safety: verify python3 is available before anything else.
# All JSON output in this script uses python3, so if it's missing we must
# report the error using plain printf (no circular dependency).
if ! command -v python3 &>/dev/null; then
    printf '{"error":"python3_not_found","hint":"python3 is required but not installed. Install Python 3: brew install python3 (macOS) or apt install python3 (Linux)","recoverable":false}\n' >&2
    exit 2
fi

ensure_status_dir() {
    mkdir -p "$STATUS_DIR"
}

emit_error() {
    local error="$1"
    local hint="$2"
    local recoverable="${3:-true}"
    _ERR="$error" _HINT="$hint" _REC="$recoverable" python3 -c "
import json, os
rec = os.environ['_REC'] == 'true'
print(json.dumps({'error': os.environ['_ERR'], 'hint': os.environ['_HINT'], 'recoverable': rec}))
" >&2
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
    # Status is per-backend: pass backend name as $1 to match against cached entry
    local query_backend="${1:-}"
    _QB="$query_backend" python3 -c "
import json, time, os
try:
    data = json.load(open('$STATUS_FILE'))
    status = data.get('status', 'unknown')
    ts = data.get('timestamp', 0)
    age_hours = (time.time() - ts) / 3600
    cached_backend = data.get('backend', '')
    query_backend = os.environ.get('_QB', '')

    # If a specific backend is requested and the cache is for a different backend,
    # the cached status does not apply — return unknown
    if query_backend and cached_backend and query_backend != cached_backend:
        print('unknown')
    elif status == 'logged_out' and age_hours > $LOGOUT_EXPIRY_HOURS:
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
    # NOTE: This preflight checks MCP server presence in ~/.claude.json (existence)
    # but cannot live-test browser MCP connectivity. MCP servers are runtime-managed
    # by Claude Code and inaccessible from shell scripts. The skill compensates with
    # optimistic dispatch + post-interaction status caching (see write_login_status).
    local login_status
    local backend
    local ready
    local hint
    local exit_code

    # Priority 1: claude-in-chrome (user's real Chrome, has login state)
    if has_mcp_server "claude-in-chrome"; then
        backend="chrome"
        login_status=$(read_login_status "$backend")
        ready=true
        hint="Grok ready via chrome backend"
        exit_code=0

    # Priority 2: playwright-grok (dedicated profile with login persistence)
    elif has_mcp_server "playwright-grok"; then
        backend="playwright-grok"
        login_status=$(read_login_status "$backend")
        ready=true
        hint="Grok ready via playwright-grok backend"
        exit_code=0

    # Priority 3: playwright (default, no profile — works but may not be logged in)
    elif has_mcp_server "playwright"; then
        login_status="unknown"
        backend="playwright"
        ready=false
        hint="Has playwright MCP. Run 'grok_setup.sh setup' to create a dedicated playwright-grok instance with login persistence."
        exit_code=1

    # Nothing available
    else
        login_status="unknown"
        backend="none"
        ready=false
        hint="No browser MCP configured. Install Playwright MCP or Claude-in-Chrome extension to enable Grok source."
        exit_code=2
    fi

    # Build and output standard preflight JSON
    _READY="$ready" _BACKEND="$backend" _LOGIN="$login_status" _HINT="$hint" python3 -c "
import json, os
ready = os.environ['_READY'] == 'true'
backend = os.environ['_BACKEND']
login_status = os.environ['_LOGIN']
hint = os.environ['_HINT']
result = {
    'ready': ready,
    'backend': backend,
    'login_status': login_status,
    'dependencies': {
        'browser_mcp': {
            'status': 'ok' if ready else 'missing',
            'backend': backend
        }
    },
    'credentials': {
        'grok_login': {
            'status': login_status
        }
    },
    'services': {},
    'hint': hint
}
print(json.dumps(result, indent=2))
"
    exit "$exit_code"
}

cmd_setup() {
    if ! [ -f "$CLAUDE_JSON" ]; then
        emit_error "~/.claude.json not found" "Ensure Claude Code is installed and has been run at least once" "false"
        exit 2
    fi

    if has_mcp_server "playwright-grok"; then
        python3 -c "
import json
print(json.dumps({'hint': 'playwright-grok already configured. No action needed.'}, indent=2))
"
        exit 0
    fi

    local pw_config
    pw_config=$(get_playwright_config)
    if [ -z "$pw_config" ]; then
        emit_error "No playwright MCP server found" "Configure playwright MCP in ~/.claude.json first, then re-run setup" "true"
        exit 1
    fi

    # Config safety: backup ~/.claude.json before modifying
    local backup_path="${CLAUDE_JSON}.backup.$(date +%Y%m%d_%H%M%S)"
    if ! cp "$CLAUDE_JSON" "$backup_path"; then
        emit_error "Failed to create backup" "Could not copy ~/.claude.json to $backup_path. Check disk space and permissions." "true"
        exit 1
    fi

    # Add playwright-grok by cloning playwright config with --user-data-dir
    local setup_output
    if ! setup_output=$(python3 -c "
import json, sys, copy

config = json.load(open('$CLAUDE_JSON'))
pw = config['mcpServers']['playwright']

# Deep copy and add --user-data-dir
grok = copy.deepcopy(pw)
args = grok.get('args', [])

# Only add if not already present
if '--user-data-dir' not in ' '.join(str(a) for a in args):
    args.extend(['--user-data-dir', '$HOME/.playwright-grok-profile'])
    grok['args'] = args

config['mcpServers']['playwright-grok'] = grok

with open('$CLAUDE_JSON', 'w') as f:
    json.dump(config, f, indent=2)
" 2>&1); then
        emit_error "Failed to update ~/.claude.json" "Backup saved at $backup_path. Restore with: cp $backup_path ~/.claude.json. Detail: $setup_output" "true"
        exit 1
    fi

    # Post-setup verification: re-read the config and confirm playwright-grok exists
    if ! has_mcp_server "playwright-grok"; then
        emit_error "Setup verification failed" "playwright-grok was not found in ~/.claude.json after writing. The file may have been modified concurrently or the write failed silently." "true"
        exit 1
    fi

    python3 -c "
import json
print(json.dumps({
    'hint': 'Added playwright-grok to ~/.claude.json and verified. Restart Claude Code to activate.',
    'profile_dir': '$HOME/.playwright-grok-profile',
    'backup': '$backup_path',
    'rollback': 'cp $backup_path ~/.claude.json',
    'verified': True
}, indent=2))
"
}

cmd_reset() {
    if [ -f "$STATUS_FILE" ]; then
        rm -f "$STATUS_FILE"
        python3 -c "import json; print(json.dumps({'hint': 'Login status cache cleared. Next Grok query will check login state fresh.'}, indent=2))"
    else
        python3 -c "import json; print(json.dumps({'hint': 'No cached login status to clear.'}, indent=2))"
    fi
}

cmd_status() {
    local new_status="${1:-}"
    local backend="${2:-}"
    if [ -z "$new_status" ]; then
        emit_error "Missing status argument" "Usage: grok_setup.sh status <logged_in|logged_out> [backend]" "true"
        exit 1
    fi
    write_login_status "$new_status" "$backend"
    python3 -c "import json; print(json.dumps({'hint': 'Login status updated: $new_status (backend: ${backend:-unspecified})'}, indent=2))"
}

# --- Main ---

case "${1:-}" in
    check|preflight)  cmd_check ;;
    setup)  cmd_setup ;;
    reset)  cmd_reset ;;
    status) cmd_status "${2:-}" "${3:-}" ;;
    *)
        emit_error "Unknown subcommand: ${1:-}" "Valid subcommands: check, preflight, setup, reset, status" "true"
        exit 1
        ;;
esac
