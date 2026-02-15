#!/bin/bash
# Update Grok login status for tech-research plugin
# Usage:
#   scripts/grok_update_status.sh login    — mark as logged in
#   scripts/grok_update_status.sh logout   — mark as logged out

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_FILE="$SCRIPT_DIR/../.grok-status.json"

if [ -z "$1" ]; then
    echo "Usage: grok_update_status.sh [login|logout]"
    exit 1
fi

python3 -c "
import json, time
data = {'status': '$1', 'timestamp': time.time()}
with open('$STATUS_FILE', 'w') as f:
    json.dump(data, f)
print('Grok status updated: $1')
" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "WARN: Could not persist login status. Grok login will be verified via Playwright snapshot."
fi
