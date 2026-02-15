#!/bin/bash
# Pre-flight check for Grok source in tech-research skill
# Delegates to ask-grok's preflight if available, otherwise checks directly
# Exit codes: 0 = ready, 1 = needs login, 2 = needs MCP config, 3 = grok skill missing

ASK_GROK_DIR="$HOME/.claude/skills/ask-grok"
ASK_GROK_PREFLIGHT="$ASK_GROK_DIR/scripts/preflight.sh"

# Prefer delegating to ask-grok's preflight
if [ -f "$ASK_GROK_PREFLIGHT" ]; then
    exec bash "$ASK_GROK_PREFLIGHT"
fi

# Fallback: check MCP config directly
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

# MCP is configured but we can't check login without ask-grok's status.json
echo "STATUS: NEEDS_LOGIN"
echo "ACTION: ask-grok skill not found at $ASK_GROK_DIR. Install it for persistent login tracking, or verify login in Playwright snapshot."
exit 1
