# Troubleshooting & Self-Recovery

When encountering issues during Grok research, use this decision tree to diagnose and recover. **Core principle: the browser snapshot is ground truth. The status file is only a cache. Any conflict → trust what you see in the browser.**

## Decision Tree

```
Problem detected
├─ Script-level failure (grok_setup.sh errors or unexpected exit code)
│  └─ Bypass the script entirely
│     └─ Use ToolSearch to detect MCP availability directly:
│        1. ToolSearch("+claude-in-chrome") → found? use chrome backend
│        2. ToolSearch("+playwright-grok") → found? use playwright-grok
│        3. ToolSearch("+playwright") → found? use playwright
│        4. None found → skip Grok source
│
├─ Status file inconsistency (cached state doesn't match reality)
│  ├─ Status says "logged_in" but browser shows "Sign in"
│  │  └─ Session expired. Update status to logged_out.
│  │     Skip Grok for this research. Report: "Grok session expired,
│  │     log in at grok.com in [browser] then run grok_setup.sh reset"
│  │
│  ├─ Status says "logged_out" but unsure if user re-logged in
│  │  └─ Check if status has expired (>2 hours). If expired, try
│  │     optimistically. If still fresh, skip Grok.
│  │
│  └─ Status file corrupted (invalid JSON, permission error)
│     └─ Delete the file: rm ~/.claude/tech-research/.grok-status.json
│        Proceed in optimistic mode (treat as unknown).
│
├─ Browser-level failure
│  ├─ Grok page loads but UI elements not found (site redesign?)
│  │  └─ Do NOT retry in a loop. Report: "Grok UI may have changed,
│  │     unable to interact. Skipping Grok source."
│  │
│  ├─ Browser not responding / timeout
│  │  └─ Retry once. If still failing, skip Grok source.
│  │
│  └─ Rate limited by Grok
│     └─ Do NOT retry. Report limitation. Proceed with other sources.
│
└─ All browser backends unavailable
   └─ Proceed with DeepWiki + WebSearch only.
      Note in report: "Grok source skipped — no browser backend available."
```

## Common Scenarios

**"Grok keeps saying not logged in even though I logged in"**
1. Check which backend is being used: `grok_setup.sh check`
2. If using `playwright-grok`: verify you logged in within that specific browser profile, not your regular Chrome
3. If using `claude-in-chrome`: verify you're logged into grok.com in your Chrome browser
4. Clear stale status: `grok_setup.sh reset`

**"grok_setup.sh check returns unexpected results"**
1. Verify `~/.claude.json` exists and has valid JSON
2. Check that the expected MCP server names are correct (`claude-in-chrome`, `playwright-grok`, `playwright`)
3. If the script itself fails, bypass it — use ToolSearch directly to find available browser tools

**"Everything was working, now Grok source is always skipped"**
1. Check status file: read `~/.claude/tech-research/.grok-status.json`
2. If `logged_out` with old timestamp → run `grok_setup.sh reset`
3. If file is corrupted → delete it manually
4. Re-run research — subagent will re-detect login state
