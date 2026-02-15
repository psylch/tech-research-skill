# tech-research

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for multi-source technical research. Dispatches parallel subagents to gather intelligence from three sources and synthesizes findings into a unified report.

| Source | Tool | What It Provides |
|--------|------|------------------|
| **Grok** | Playwright browser automation → grok.com | X (Twitter) developer discussions, sentiment, expert discovery |
| **DeepWiki** | DeepWiki MCP → `ask_question` | AI-powered GitHub repository analysis, architecture, API docs |
| **WebSearch** | Built-in web search | Official docs, benchmarks, blog posts, recent announcements |

## Installation

### Via Plugin Marketplace (recommended)

In Claude Code, add the marketplace and install:

```shell
/plugin marketplace add psylch/tech-research-skill
/plugin install tech-research@psylch-tech-research-skill
```

### Manual Install

```bash
git clone https://github.com/psylch/tech-research-skill.git ~/.claude/skills/tech-research
```

> Note: manual install puts the skill at the legacy `~/.claude/skills/` path. The plugin method is preferred for auto-updates and discoverability.

Restart Claude Code after installation.

## Prerequisites

- **Claude Code** v1.0.33+ (for plugin support)
- **Playwright MCP** configured with `--user-data-dir` for persistent Grok login (optional — Grok source is skipped if unavailable)
- **DeepWiki MCP** configured for GitHub repository analysis (optional)

### Playwright MCP Setup (for Grok)

Add to your `~/.claude.json`:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@anthropic-ai/mcp-playwright", "--user-data-dir", "/tmp/playwright-user-data"]
    }
  }
}
```

## Usage

In Claude Code, use any of these trigger phrases:

```
/tech-research
调研一下 Zustand vs Jotai
research this technology: Bun
compare libraries: Vite vs Turbopack
evaluate framework: SolidJS
```

## How It Works

1. **Analyze** — breaks the research question into sub-queries for each source
2. **Dispatch** — launches up to 3 parallel subagents (Grok, DeepWiki, WebSearch)
3. **Synthesize** — merges findings into a structured report with TL;DR, comparison matrix, and actionable recommendation

Not every research task uses all 3 sources. The skill selects sources based on the question type:

| Research Type | Grok | DeepWiki | WebSearch |
|---------------|------|----------|-----------|
| "Should we use library X?" | Yes | Yes | Yes |
| "What are devs saying about X?" | Yes | No | Maybe |
| "How does repo X work internally?" | No | Yes | Maybe |
| "Compare X vs Y performance" | Maybe | Yes (both) | Yes |

## Key Design Decisions

- **Grok queries must include X/Twitter keywords** (e.g., "developers on X say...") to avoid falling back to broad web search, which would duplicate WebSearch
- **Each Grok query opens a fresh page** — no multi-turn conversations in the same session
- **DeepWiki uses `ask_question` only** — `read_wiki_structure` and `read_wiki_contents` return massive dumps that easily exceed context limits
- **Grok post URLs are verified** — the subagent navigates to 2-3 cited URLs to check if they actually exist

## File Structure

```
tech-research-skill/
├── .claude-plugin/
│   └── plugin.json                   # Plugin manifest
├── skills/
│   └── tech-research/
│       ├── SKILL.md                  # Main skill definition
│       ├── references/
│       │   ├── subagent_templates.md # Prompt templates for each subagent
│       │   └── query_strategies.md   # Grok query crafting strategies
│       └── scripts/
│           ├── grok_preflight.sh     # Pre-flight check for Grok
│           └── grok_update_status.sh # Track Grok login state
├── README.md
├── README.zh.md
└── LICENSE
```

## Optional: ask-grok Skill

This plugin optionally delegates to the [ask-grok](https://github.com/nicobailon/ask-grok-claude-code) skill for Grok login state tracking. If `ask-grok` is not installed, the plugin falls back to checking login via Playwright snapshots each time.

## License

MIT
