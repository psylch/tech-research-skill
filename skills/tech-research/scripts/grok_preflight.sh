#!/bin/bash
# Pre-flight check for Grok source in tech-research plugin
# Exit codes: 0 = ready, 1 = needs login check, 2 = needs MCP config

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_FILE="$SCRIPT_DIR/../.grok-status.json"
CLAUDE_JSON="$HOME/.claude.json"

if [ ! -f "$CLAUDE_JSON" ]; then
    echo "STATUS: NOT_CONFIGURED"
    echo "ACTION: No ~/.claude.json found. Configure Playwright MCP with --user-data-dir."
    exit 2
fi

HAS_PLAYWRIGHT=$(python3 -c "
import json
config = json.load(open('$CLAUDE_JSON'))
servers = config.get('mcpServers', {})
pw = servers.get('playwright', {})
args = pw.get('args', [])
has_udd = '--user-data-dir' in ' '.join(args)
print('True' if pw and has_udd else 'False')
" 2>/dev/null)

if [ "$HAS_PLAYWRIGHT" != "True" ]; then
    echo "STATUS: NOT_CONFIGURED"
    echo "ACTION: Add Playwright MCP with --user-data-dir to ~/.claude.json, then restart Claude Code."
    exit 2
fi

# Check persisted login status
if [ -f "$STATUS_FILE" ]; then
    LOGGED_IN=$(python3 -c "
import json, time
data = json.load(open('$STATUS_FILE'))
status = data.get('status', 'unknown')
ts = data.get('timestamp', 0)
age_hours = (time.time() - ts) / 3600
# Consider status stale after 24 hours
if age_hours > 24:
    print('stale')
else:
    print(status)
" 2>/dev/null)

    if [ "$LOGGED_IN" = "login" ]; then
        echo "STATUS: READY"
        echo "ACTION: Playwright MCP configured, Grok login recently verified."
        exit 0
    fi
fi

echo "STATUS: NEEDS_LOGIN"
echo "ACTION: Playwright MCP configured. Verify Grok login in Playwright snapshot."
exit 1
