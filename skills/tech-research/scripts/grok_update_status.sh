#!/bin/bash
# Update Grok login status for tech-research skill
# Delegates to ask-grok's update_status if available
# Usage:
#   scripts/grok_update_status.sh login    — mark as logged in
#   scripts/grok_update_status.sh logout   — mark as logged out

ASK_GROK_UPDATE="$HOME/.claude/skills/ask-grok/scripts/update_status.sh"

if [ -f "$ASK_GROK_UPDATE" ]; then
    exec bash "$ASK_GROK_UPDATE" "$1"
fi

echo "WARN: ask-grok skill not installed. Login status not persisted."
echo "Grok queries will verify login via Playwright snapshot each time."
