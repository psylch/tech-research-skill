# tech-research

[中文文档](README.zh.md)

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill for multi-source technical research. Gathers intelligence from complementary sources and synthesizes findings into a unified report — using lightweight subagents for simple queries or coordinated agent teammates for heavy competitive research.

| Source | Tool | What It Provides |
|--------|------|------------------|
| **Xquik** | `xquik_source.py` + Hermes Tweet/Xquik key | Structured X post search and trends without browser state |
| **Grok** | Browser automation → grok.com | X (Twitter) developer discussions, sentiment, expert discovery |
| **DeepWiki** | DeepWiki MCP → `ask_question` | AI-powered GitHub repository analysis, architecture, API docs |
| **WebSearch** | Built-in web search | Official docs, benchmarks, blog posts, recent announcements |

## Installation

### Via skills.sh (recommended)

```bash
npx skills add psylch/tech-research-skill -g -y
```

### Via Claude Code Plugin Marketplace

```shell
/plugin marketplace add psylch/tech-research-skill
/plugin install tech-research@psylch-tech-research-skill
```

Restart Claude Code after installation.

## Prerequisites

- **Claude Code** or any agent that supports [skills.sh](https://skills.sh/)
- **Browser automation** for Grok (optional — Grok source is skipped if unavailable):
  - **Claude-in-Chrome** (zero setup, recommended), or
  - **Playwright MCP** (auto-setup via `grok_setup.sh`)
- **Hermes Tweet / Xquik key** for structured X evidence (optional):
  - `XQUIK_API_KEY` or `HERMES_TWEET_API_KEY`
  - skipped automatically when neither variable is set
- **DeepWiki MCP** for GitHub repository analysis (optional)

### Optional Xquik Source

When a Hermes Tweet/Xquik key is configured, the skill can collect structured
read-only X evidence without opening a browser:

```bash
python ~/.agents/skills/tech-research/scripts/xquik_source.py search "Claude Code workflows" --limit 8
python ~/.agents/skills/tech-research/scripts/xquik_source.py trends --woeid 1 --limit 10
```

Use this source for quick tweet evidence, trend hints, and fallback coverage
when Grok browser access is unavailable. Grok remains useful for richer
summaries and expert discovery.

### Grok Browser Backend

Grok requires browser automation with a logged-in session. The skill supports multiple backends, detected in priority order:

| Priority | Backend | MCP Server | Setup |
|----------|---------|------------|-------|
| 1 | **Claude-in-Chrome** | `claude-in-chrome` | Zero setup — uses your Chrome login state |
| 2 | **Playwright-Grok** | `playwright-grok` | One-time: run `grok_setup.sh setup` to create from existing Playwright config |
| 3 | **Playwright** (default) | `playwright` | Works but no login persistence |

> **Important**: Do NOT modify your default `playwright` MCP to add `--user-data-dir`. This forces ALL browser operations through a single profile, breaking parallel agent usage. The skill uses a separate `playwright-grok` instance instead.

#### Quick Setup (if no Claude-in-Chrome)

If you have Playwright MCP configured, run:

```bash
bash ~/.agents/skills/tech-research/scripts/grok_setup.sh setup
```

This clones your `playwright` config as `playwright-grok` with a dedicated profile directory. Then restart Claude Code and log into Grok once in the new browser window.

### Login Status Cache

Login state is cached at `~/.claude/tech-research/.grok-status.json`:

- **`logged_in`** — Long-lived, no expiry. Valid until a subagent detects an actual logout.
- **`logged_out`** — Auto-expires after 2 hours, then retries optimistically.
- **No file** — Optimistic, assumes logged in.

```bash
# Check current status
bash ~/.agents/skills/tech-research/scripts/grok_setup.sh check

# Clear cached status (after re-logging in)
bash ~/.agents/skills/tech-research/scripts/grok_setup.sh reset
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
2. **Pre-flight** — detects best available browser backend and login status for Grok
3. **Select mode** — chooses Light or Heavy mode based on research complexity
4. **Dispatch** — launches research agents in the appropriate mode
5. **Synthesize** — merges findings into a structured report with TL;DR, comparison matrix, and actionable recommendation

### Research Modes

| Signal | Mode |
|--------|------|
| Single topic, multiple data sources | **Light** — up to 4 parallel Task Subagents, each handling one data source |
| Multiple topics/competitors needing cross-comparison | **Heavy** — Agent Teammates that can communicate, share discoveries, and avoid duplication |
| Research may require dynamic re-scoping | **Heavy** |
| Agent count ≥ 4 | **Heavy** |

Not every research task uses every source. The skill selects sources based on the question type:

| Research Type | Xquik | Grok | DeepWiki | WebSearch |
|---------------|-------|------|----------|-----------|
| "Should we use library X?" | Maybe | Yes | Yes | Yes |
| "What are devs saying about X?" | Yes | Yes | No | Maybe |
| "How does repo X work internally?" | No | No | Yes | Maybe |
| "Compare X vs Y performance" | Maybe | Maybe | Yes (both) | Yes |

## Key Design Decisions

- **Grok queries must include X/Twitter keywords** (e.g., "developers on X say...") to avoid falling back to broad web search, which would duplicate WebSearch
- **Each Grok query opens a fresh page** — no multi-turn conversations in the same session
- **DeepWiki uses `ask_question` only** — `read_wiki_structure` and `read_wiki_contents` return massive dumps that easily exceed context limits
- **Grok post URLs are verified** — the subagent navigates to 2-3 cited URLs to check if they actually exist
- **Optimistic login** — assumes Grok is logged in unless a previous attempt recorded `logged_out`; avoids prompting the user unnecessarily
- **Self-recovery** — the skill includes a diagnostic decision tree for handling script failures, stale status files, and browser issues

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Grok always skipped despite being logged in | Run `grok_setup.sh reset` to clear stale status |
| `grok_setup.sh check` returns unexpected results | Verify `~/.claude.json` has correct MCP server names |
| Status file corrupted | Delete `~/.claude/tech-research/.grok-status.json` |
| Script fails entirely | The skill falls back to ToolSearch-based MCP detection automatically |

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
│           ├── grok_setup.sh         # Backend detection, setup, and login status management
│           └── xquik_source.py       # Optional structured X evidence source
├── README.md
├── README.zh.md
└── LICENSE
```

## License

MIT
