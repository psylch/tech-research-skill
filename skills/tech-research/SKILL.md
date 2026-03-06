---
name: tech-research
description: Comprehensive technical research by combining multiple intelligence sources — Grok (X/Twitter developer discussions via browser automation), DeepWiki (AI-powered GitHub repository analysis), and WebSearch. Dispatches parallel subagents for each source and synthesizes findings into a unified report. This skill should be used when evaluating technologies, comparing libraries/frameworks, researching GitHub repos, gauging developer sentiment, or investigating technical architecture decisions. Trigger phrases include "tech research", "research this technology", "技术调研", "调研一下", "compare libraries", "evaluate framework", "investigate repo".
---

# Tech Research

Orchestrate multi-source technical research by dispatching parallel subagents to gather intelligence from X/Twitter (via Grok), GitHub repositories (via DeepWiki), and the web (via WebSearch). Synthesize all findings into a single actionable report.

**Architecture:** The main agent orchestrates research using one of two modes — lightweight (Task Subagents) or heavyweight (Agent Teammates) — chosen based on research complexity.

## Language

**Match user's language**: Respond in the same language the user uses. If the user writes in Chinese, the entire research report should be in Chinese. If in English, report in English.

## Research Mode Selection

Before dispatching any agents, determine the appropriate mode:

| Signal | → Mode |
|--------|--------|
| Single topic, multiple data sources (Grok + DeepWiki + WebSearch) | **Light** → Task Subagents |
| Multiple independent topics/competitors needing cross-comparison | **Heavy** → Agent Teammates |
| Research may produce follow-up questions requiring dynamic re-scoping | **Heavy** → Agent Teammates |
| Agent count ≥ 4 | **Heavy** → Agent Teammates |

### Light Mode (default for single-topic research)

Dispatch up to 3 Task Subagents (`Task` with `subagent_type: "general-purpose"`). Each handles one data source independently. The main agent synthesizes results after all return.

### Heavy Mode (for multi-topic / competitive research)

Use `TeamCreate` to create a research team → `TaskCreate` for each research task → spawn Agent Teammates (via `Task` with `team_name` and `name` parameters) → coordinate via `SendMessage`. Teammates can:

- Communicate to avoid duplication ("I found Project A uses the same approach as B — focus on their differentiators")
- Share discoveries across tasks ("The blog post I found compares all 3 frameworks, sending you the link")
- Dynamically adjust scope based on what others have found

## When to Use

- Evaluating a technology, library, or framework for adoption
- Comparing alternatives (e.g., "Zustand vs Jotai vs Redux")
- Investigating a GitHub repo's architecture and community reception
- Gauging developer sentiment on a new API, tool, or announcement
- Cross-language research (Chinese/Japanese developer communities)

## Research Sources

| Source | What It Provides | Best For |
|--------|-----------------|----------|
| **Grok** (X/Twitter) | Real developer opinions, @handles, post URLs | Sentiment, expert discovery, niche recommendations |
| **DeepWiki** (GitHub) | AI-powered repo analysis, architecture, API docs | Understanding codebases, comparing repo internals. **Only use `ask_question`** — never `read_wiki_structure` or `read_wiki_contents` (they return massive dumps that easily exceed context limits) |
| **WebSearch** | Official docs, blog posts, benchmarks, tutorials | Facts, performance data, official announcements |

## Source Degradation

Not every source will be available every time. Follow this degradation strategy:

| Source | If unavailable | Fallback |
|--------|---------------|----------|
| Grok | No browser backend or not logged in | Skip. Note in report: "Grok source skipped — [reason]." |
| DeepWiki | No `owner/repo` known, or API error | Skip. Note in report: "DeepWiki skipped — [reason]." |
| WebSearch | Tool unavailable (rare) | Skip. Note in report. |

**Minimum viable research:** At least one source must return results. If all sources fail, report the failures and suggest the user check their environment setup.

## Grok Browser Backend

Grok requires browser automation with login state. Multiple backends are supported, detected in priority order:

| Priority | Backend | MCP Server Name | Pros | Cons |
|----------|---------|----------------|------|------|
| 1 | **Claude-in-Chrome** | `claude-in-chrome` | Zero setup, uses user's Chrome login state | Occupies user's visible Chrome window |
| 2 | **Playwright-Grok** | `playwright-grok` | Dedicated profile, login persists, doesn't block default Playwright | One-time setup required |
| 3 | **Playwright** (default) | `playwright` | Already configured for most users | No login persistence, may not be logged in |

**IMPORTANT**: Do NOT modify the user's default `playwright` MCP to add `--user-data-dir`. This would force ALL browser operations through a single profile, breaking parallel agent usage. Instead, use a separate `playwright-grok` instance.

### Grok Pre-flight

Before dispatching a Grok subagent, detect the best available browser backend. There are two paths:

**Path A — claude-in-chrome (runtime detection, no script needed):**
If `mcp__claude-in-chrome__*` tools are available in your current session, you already have the best backend. The chrome extension is injected at runtime and **never appears in `~/.claude.json`**, so the shell script cannot detect it. Skip the preflight script entirely — set `backend=chrome` and proceed to dispatch.

**Path B — Playwright fallback (script-based detection):**
If claude-in-chrome is NOT available, run the preflight script to detect playwright backends:

```bash
bash ${SKILL_PATH}/scripts/grok_setup.sh check
```

The script outputs preflight JSON: `{"ready": true, "backend": "playwright-grok", "login_status": "logged_in", "hint": "..."}`.

Key fields: `ready` (boolean), `backend` (`playwright-grok`/`playwright`/`none`), `login_status` (`logged_in`/`logged_out`/`unknown`), `hint` (human-readable summary).

**Live validation note:** Preflight checks MCP server presence in `~/.claude.json` (existence check) but cannot live-test browser MCP connectivity from shell — MCP servers are runtime-managed by Claude Code and only accessible during agent execution. The skill compensates with optimistic dispatch: assume the backend works, then update the login status cache based on actual browser interaction results (see Login Status Cache below).

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| `0` READY | Backend available | Pass `backend` value to Grok subagent. If `login_status` is `logged_out`, skip Grok and note in report. Otherwise dispatch subagent (optimistic). |
| `1` NEEDS_SETUP | Has playwright, no playwright-grok | **Setup-first gate:** Run `grok_setup.sh setup` immediately (before any research). Setup backs up `~/.claude.json` before modifying it (backup path is in the output JSON). If setup succeeds, inform user they need to restart Claude Code for playwright-grok to activate, then proceed with research using `backend=playwright` as a degraded fallback for this session only. Do NOT start research and discover the setup need mid-way. |
| `2` NOT_AVAILABLE | No browser MCP at all | Skip Grok source entirely. Note in report. |

**Config safety:** The setup command always creates a timestamped backup of `~/.claude.json` before writing. If the new config causes issues, restore with the rollback command in the setup output (e.g., `cp ~/.claude.json.backup.<timestamp> ~/.claude.json`).

### Login Status Cache

Login state is cached at `~/.claude/tech-research/.grok-status.json`. Cache semantics: `logged_in` persists until a subagent observes logout; `logged_out` auto-expires after 2 hours (or clear with `grok_setup.sh reset`); `unknown`/missing = optimistic, try Grok.

**Subagent responsibility:** After interacting with Grok, update login status:
- Success: `bash ${SKILL_PATH}/scripts/grok_setup.sh status logged_in <backend>`
- "Sign in" page: `bash ${SKILL_PATH}/scripts/grok_setup.sh status logged_out <backend>`

**Cache corruption recovery:** If the status file is corrupted (invalid JSON, permission errors), delete it (`rm ~/.claude/tech-research/.grok-status.json`) and proceed in optimistic mode. See [references/troubleshooting.md](references/troubleshooting.md) for the full decision tree.

## Workflow

Progress:
- [ ] Step 1: Preflight — Run `grok_setup.sh check`, complete any setup BEFORE research
- [ ] Step 2: Analyze — Break question into per-source sub-queries
- [ ] Step 3: Dispatch — Launch subagents in parallel (Light or Heavy mode)
- [ ] Step 4: Synthesize — Merge findings into unified report

### 1. Preflight Gate (MUST run first)

Run preflight **before doing anything else**. This determines which sources are available and whether one-time setup is needed.

1. Check if `mcp__claude-in-chrome__*` tools are available in your session.
   - **Yes** → `backend=chrome`, skip the script, proceed directly to Step 2.
   - **No** → Run `bash ${SKILL_PATH}/scripts/grok_setup.sh check` and act on exit code:

```
Exit code 0 (READY)     → Note the backend and login_status, proceed to Step 2.
Exit code 1 (NEEDS_SETUP) → Run `grok_setup.sh setup` NOW.
                            If setup succeeds, tell the user:
                              "playwright-grok has been configured. Restart Claude Code
                               to activate it. For this session, Grok will use the
                               default playwright backend as a fallback."
                            Then proceed to Step 2 with backend=playwright.
Exit code 2 (NOT_AVAILABLE) → Grok is unavailable. Proceed to Step 2 without Grok.
```

**Key principle:** Setup completes before research begins. Never discover setup needs mid-research.

### 2. Analyze the Research Question

Break the user's question into sub-queries for each source:

- **Grok query**: Developer opinions, community sentiment, expert recommendations
- **DeepWiki query**: Repository architecture, API design, code quality (requires `owner/repo`)
- **WebSearch query**: Official docs, benchmarks, comparisons, recent announcements

Not every research task needs all 3 sources. Select sources based on the question:

| Research Type | Grok | DeepWiki | WebSearch |
|---------------|------|----------|-----------|
| "Should we use library X?" | Yes | Yes (if OSS) | Yes |
| "What are devs saying about X?" | Yes | No | Maybe |
| "How does repo X work internally?" | No | Yes | Maybe |
| "Compare X vs Y performance" | Maybe | Yes (both repos) | Yes |
| "What's new in framework X?" | Yes | No | Yes |

### 3. Dispatch Research Agents

Choose the dispatch method based on the research mode selected above.

#### Light Mode: Task Subagents

Launch subagents concurrently using `Task`. See [references/subagent_templates.md](references/subagent_templates.md) for complete prompt templates.

**Grok subagent:**
```
Task(subagent_type: "general-purpose", description: "Ask Grok about [topic]", prompt: <grok_template with BACKEND>)
```

**DeepWiki subagent:**
```
Task(subagent_type: "general-purpose", description: "DeepWiki research [repo]", prompt: <deepwiki_template>)
```

**WebSearch subagent:**
```
Task(subagent_type: "general-purpose", description: "Web research [topic]", prompt: <websearch_template>)
```

#### Heavy Mode: Agent Teammates

```
1. TeamCreate(team_name: "research-[topic]")
2. TaskCreate(subject: "Research [Project A]", description: "...", activeForm: "Researching [Project A]")
3. TaskCreate(subject: "Research [Project B]", description: "...", activeForm: "Researching [Project B]")
4. Task(subagent_type: "general-purpose", team_name: "research-[topic]", name: "researcher-a", prompt: "...")
5. Task(subagent_type: "general-purpose", team_name: "research-[topic]", name: "researcher-b", prompt: "...")
6. Coordinate via SendMessage — share findings, adjust scope, avoid duplication
7. Synthesize after all teammates report back
8. Shutdown teammates and TeamDelete when done
```

Each teammate should use all relevant data sources (Grok, DeepWiki, WebSearch) for their assigned topic, rather than splitting by data source.

### 4. Synthesize and Report

After all subagents return, merge findings into a unified report with these sections:

- **TL;DR** — 2-3 sentence executive summary with clear recommendation
- **Community Sentiment** (from X/Twitter) — Key opinions with @username attribution and post URLs
- **Repository Analysis** (from DeepWiki) — Architecture, code quality, API design, maintenance status
- **Web Intelligence** — Official docs, benchmarks, blog insights, announcements
- **Comparison Matrix** (if comparing alternatives) — Criteria-based table
- **Recommendation** — Clear, actionable recommendation based on all sources
- **Limitations** — What couldn't be verified, including skipped sources and why

## Grok Query Strategies

See [references/grok_query_overview.md](references/grok_query_overview.md) for strategy selection table and [references/query_strategies.md](references/query_strategies.md) for full prompt templates.

## Troubleshooting & Self-Recovery

See [references/troubleshooting.md](references/troubleshooting.md) for the full decision tree and common scenarios.

## Tips

- For CJK communities, query Grok in the target language directly
- DeepWiki accepts up to 10 repos in a single query for comparisons
- WebSearch is best for recent information (include current year in queries)
- Always verify Grok post URLs before citing — accuracy is ~80%
- Run subagents in parallel to minimize total research time
