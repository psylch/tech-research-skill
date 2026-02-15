---
name: tech-research
description: Comprehensive technical research by combining multiple intelligence sources — Grok (X/Twitter developer discussions via Playwright), DeepWiki (AI-powered GitHub repository analysis), and WebSearch. Dispatches parallel subagents for each source and synthesizes findings into a unified report. This skill should be used when evaluating technologies, comparing libraries/frameworks, researching GitHub repos, gauging developer sentiment, or investigating technical architecture decisions. Trigger phrases include "tech research", "research this technology", "技术调研", "调研一下", "compare libraries", "evaluate framework", "investigate repo".
---

# Tech Research

Orchestrate multi-source technical research by dispatching parallel subagents to gather intelligence from X/Twitter (via Grok), GitHub repositories (via DeepWiki), and the web (via WebSearch). Synthesize all findings into a single actionable report.

**Architecture:** The main agent orchestrates research by dispatching up to 3 parallel subagents. Each subagent handles one data source to keep the main context clean.

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

## Workflow

### 1. Analyze the Research Question

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

### 2. Dispatch Parallel Subagents

Launch subagents concurrently using `Task`. See [references/subagent_templates.md](references/subagent_templates.md) for complete prompt templates.

**Grok subagent:**
```
Task(subagent_type: "general-purpose", description: "Ask Grok about [topic]", prompt: <grok_template>)
```

**DeepWiki subagent:**
```
Task(subagent_type: "general-purpose", description: "DeepWiki research [repo]", prompt: <deepwiki_template>)
```

**WebSearch subagent:**
```
Task(subagent_type: "general-purpose", description: "Web research [topic]", prompt: <websearch_template>)
```

### 3. Synthesize and Report

After all subagents return, merge findings into a unified report:

```markdown
## Tech Research: [Topic]

### TL;DR
[2-3 sentence executive summary with clear recommendation]

### Community Sentiment (from X/Twitter)
- [Key opinions with @username attribution]
- [Verified post URLs]

### Repository Analysis (from DeepWiki)
- Architecture overview
- Code quality observations
- API design patterns
- Activity and maintenance status

### Web Intelligence
- Official documentation highlights
- Benchmark data
- Blog post insights
- Recent announcements

### Comparison Matrix (if comparing alternatives)
| Criteria | Option A | Option B |
|----------|----------|----------|
| [criterion] | [finding] | [finding] |

### Recommendation
[Clear, actionable recommendation based on all sources]

### Limitations
[What couldn't be verified or found]
```

## Query Strategy Reference

For crafting effective Grok queries, see [references/query_strategies.md](references/query_strategies.md).

## Grok Pre-flight

Before dispatching a Grok subagent, run the pre-flight check:

```bash
bash ~/.claude/skills/tech-research/scripts/grok_preflight.sh
```

| Exit Code | Action |
|-----------|--------|
| `0` READY | Dispatch Grok subagent |
| `1` NEEDS_LOGIN | Dispatch anyway; subagent will verify |
| `2` NOT_CONFIGURED | Skip Grok source, note in report |

If Grok is unavailable, proceed with DeepWiki + WebSearch only.

## Tips

- For CJK communities, query Grok in the target language directly
- DeepWiki accepts up to 10 repos in a single query for comparisons
- WebSearch is best for recent information (include current year in queries)
- Always verify Grok post URLs before citing — accuracy is ~80%
- Run subagents in parallel to minimize total research time
