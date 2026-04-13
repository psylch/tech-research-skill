# Subagent Prompt Templates — Role Contracts

Each template below is a **complete, self-contained contract** for one research role. If you were dispatched here by tech-research (or are running it inline), read only the section matching your role — you do NOT need to read `SKILL.md`. The orchestrator already ran preflight and chose your parameters.

**For every role:** before calling any tool not already loaded in your session, check the deferred-tool list and load what you need via `ToolSearch select:<tool1>,<tool2>,...`. Required tools per role are listed in each template. Skipping this step will return `InputValidationError` on the first call.

**Browser singleton rule:** only the Grok role may touch a browser. DeepWiki and WebSearch roles MUST NOT load any browser skill or MCP.

---

## Grok Subagent Template

**Role contract — self-contained. Do not read SKILL.md.**

**Parameters you will receive from the orchestrator:**
- `RESEARCH_QUESTION` — the topic to investigate
- `BACKEND` — one of `better-agent-browser` / `browser-use` / `chrome` / `playwright-grok` / `playwright`
- `GROK_QUERY` — the pre-crafted X/Twitter-scoped query

**Deferred tools to load first:**
- `better-agent-browser`/`browser-use`: no MCP tools needed — use bash + the CLI binary. Load the `better-agent-browser` skill for the bash helper scripts.
- `chrome`: `ToolSearch select:mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__read_page,mcp__claude-in-chrome__form_input,mcp__claude-in-chrome__computer`
- `playwright-grok`: `ToolSearch select:mcp__playwright-grok__browser_navigate,mcp__playwright-grok__browser_snapshot,mcp__playwright-grok__browser_fill_form,mcp__playwright-grok__browser_evaluate,mcp__playwright-grok__browser_click`
- `playwright`: same as above but `mcp__playwright__*`

**Full instructions (use this as your prompt body):**

```
Research a technical topic using Grok (grok.com) via browser automation.

## Your Task
[RESEARCH_QUESTION — e.g., "What are iOS developers saying about SwiftData vs Core Data?"]

## Browser Backend: [BACKEND]

Use the following tools based on your assigned backend:

### If BACKEND=better-agent-browser (agent-browser CLI)
Capability verified by main agent via `command -v agent-browser`.
1. Load the `better-agent-browser` skill. Read its SKILL.md "Hard Rules" and Layer 0b sections in full before acting.
2. **Default to HEADLESS Chrome.** If Chrome is not already running on port 9333 with `~/.chrome-debug-profile`, follow the Layer 0b "First-time Chrome setup" recipe — it uses `--headless=new --disable-gpu`.
3. **NEVER use `open -a "Google Chrome"`** on macOS. Launch the binary directly per the skill.
4. Connect via `bash ${SKILL_PATH_BAB}/scripts/browser-connect.sh 9333` (where `SKILL_PATH_BAB` is the better-agent-browser skill path). If the returned `mode=layer2`, another agent holds the lock — switch to the CDP proxy per Layer 2, or abort and ask the orchestrator to serialize.
5. Use `agent-browser tab new https://grok.com` for each query (one query per tab).
6. Use `agent-browser snapshot -i` to inspect state; `agent-browser click @eN` / `agent-browser fill @eN "text"` to interact.
7. When done, `agent-browser tab close` then `bash ${SKILL_PATH_BAB}/scripts/browser-disconnect.sh 9333` to release the lock.

### If BACKEND=browser-use (browser-use CLI)
Capability verified by main agent via `command -v browser-use`.
1. Drive the `browser-use` CLI directly per its own docs — this skill does not wrap it.
2. **Default to headless.** Consult `browser-use --help` for the headless flag (typically `--headless` or via its config file). Do not launch a visible browser unless the task requires interactive login.
3. Open https://grok.com, check login state (see Step 0), run the query, capture the response.
4. Respect the singleton rule — do not start multiple browser-use instances racing over the same profile.

### If BACKEND=chrome (Claude-in-Chrome)
1. Use ToolSearch("+claude-in-chrome") to load browser tools
2. Use mcp__claude-in-chrome__navigate to open https://grok.com
3. Use mcp__claude-in-chrome__read_page to check page state
4. Use mcp__claude-in-chrome__form_input to type queries
5. Use mcp__claude-in-chrome__computer to click buttons

### If BACKEND=playwright-grok
1. Use ToolSearch("+playwright-grok") to load browser tools
2. Use mcp__playwright-grok__browser_navigate to open https://grok.com
3. Use mcp__playwright-grok__browser_snapshot to check page state
4. Use mcp__playwright-grok__browser_fill_form or mcp__playwright-grok__browser_evaluate to type queries
5. Use mcp__playwright-grok__browser_click to click buttons

### If BACKEND=playwright
1. Use ToolSearch("+playwright") to load browser tools
2. Use mcp__playwright__browser_navigate to open https://grok.com
3. Use mcp__playwright__browser_snapshot to check page state
4. Use mcp__playwright__browser_fill_form or mcp__playwright__browser_evaluate to type queries
5. Use mcp__playwright__browser_click to click buttons

## Step 0: Verify login state BEFORE any query work

**Abort early if logged out — do NOT spend minutes mining only to discover logout at the end.**

1. Load browser tools for your backend (see "Browser Backend" section above).
2. Navigate to https://grok.com (or https://x.com/home if grok.com doesn't show a login wall clearly).
3. Read the page state (snapshot / read_page / `agent-browser snapshot -i`).
4. Classify:
   - **Login wall visible** (any of: "Sign in" / "Log in" / "Create account" / "Enter your password" / redirect to x.com/login):
     - If `BACKEND` is an MCP backend (`chrome` / `playwright-grok` / `playwright`): run `bash ${SKILL_PATH}/scripts/grok_setup.sh status logged_out [BACKEND]`. Skip for CLI backends (`better-agent-browser` / `browser-use`) — `grok_setup.sh` tracks only MCP state.
     - Write one line to your final output: `"GROK_SKIPPED: not logged in on [BACKEND]. User should log into grok.com in the [browser description] profile, then re-run tech-research."`
     - **ABORT.** Do NOT attempt to log in yourself. Do NOT proceed to Step 1.
   - **Chat interface visible** → logged in, proceed to Step 1.
5. If you cannot classify confidently after one snapshot, take a screenshot, report "GROK_SKIPPED: login state unknown, see screenshot", and abort.

## Step 1: Query Grok

**IMPORTANT: Always start a NEW tab/page for each Grok query. Do NOT ask multiple questions in the same Grok session** — follow-up questions in the same chat degrade answer quality and may hit rate limits. One query per page, then close/leave it.

1. Select "Fast" model if a model selector is available
2. Fill the chat input with your query (see query crafting rules below)
3. Submit the query
4. Wait for response (8-10 seconds)
5. Read the full response. If still generating, wait 5s and read again.

### CRITICAL: Grok Query Crafting Rules

Grok's unique value is access to X (Twitter) posts and developer discussions. If your query doesn't explicitly mention X/Twitter, Grok will fall back to broad web search — making it redundant with the WebSearch subagent.

**Every Grok query MUST include X/Twitter-scoping keywords** such as:
- "X 上的开发者怎么看..." / "What are developers saying on X about..."
- "Twitter 用户对...的评价" / "X user opinions on..."
- "搜索 X 上关于...的讨论" / "Search X posts about..."
- "有哪些开发者在 X 上推荐过..." / "Which developers on X recommend..."

**BAD** (will trigger broad web search, duplicates WebSearch):
- "What are the pros and cons of Zustand?"
- "Compare React vs Vue"

**GOOD** (scoped to X/Twitter community):
- "What are developers saying on X about Zustand vs Jotai? Show me recent posts and opinions"
- "Search X posts where developers discuss their experience migrating from Redux to Zustand"
- "X 上的开发者怎么评价 SwiftData？有哪些吐槽和推荐？"

The Grok query to use:
---
[GROK_QUERY — MUST contain X/Twitter-scoping keywords per rules above]
---

## Step 2: Report

1. For 2-3 X post URLs in the response, navigate to verify they exist and content matches
2. Update login status (MCP backends only — skip for `better-agent-browser` and `browser-use`, their profiles persist on disk):
   ```bash
   bash ${SKILL_PATH}/scripts/grok_setup.sh status logged_in [BACKEND]
   ```
3. Return findings in this format:

### Grok Findings: [Topic]
#### Key Findings
- [Finding with @username attribution]
#### Verified Posts
| Post | Author | Status | Content Match |
|------|--------|--------|--------------|
| [URL] | @handle | Real/Fake | Yes/No |
#### Discovered Resources
- [GitHub repos, tools, blog posts mentioned]
#### Limitations
- [What Grok couldn't find]
```

---

## DeepWiki Subagent Template

**Role contract — self-contained. Do not read SKILL.md. Do NOT load any browser skill or browser MCP.**

**Parameters you will receive from the orchestrator:**
- `RESEARCH_QUESTION` — the topic to investigate
- `REPO_LIST` — one or more `owner/repo` strings
- `CUSTOM_QUESTIONS` — optional topic-specific questions

**Deferred tools to load first:**
```
ToolSearch select:mcp__deepwiki__ask_question
```

**Full instructions (use this as your prompt body):**

```
Research GitHub repositories using the DeepWiki MCP tools.

## Your Task
[RESEARCH_QUESTION — e.g., "Analyze the architecture and API design of zustand vs jotai"]

## Repositories to Analyze
[REPO_LIST — e.g., "pmndrs/zustand", "pmndrs/jotai"]

## Step 1: Ask Targeted Questions
Call mcp__deepwiki__ask_question directly with questions like:

**IMPORTANT: Do NOT use `read_wiki_structure` or `read_wiki_contents`. Always use `ask_question` directly — it provides faster, more focused answers without needing to browse the wiki structure first.**

Questions to ask:
- "What is the overall architecture of this repository?"
- "What are the core APIs and how do they work?"
- "What design patterns does this codebase use?"
- "How does [specific feature] work internally?"
- [CUSTOM_QUESTIONS — specific to the research topic]

If comparing repos, ask parallel questions to enable direct comparison.

## Step 2: Report
Return findings in this format:

### DeepWiki Findings: [Topic]

#### [Repo 1: owner/repo]
- **Architecture**: [overview]
- **Core APIs**: [key APIs and usage]
- **Design Patterns**: [notable patterns]
- **Strengths**: [observed strengths]
- **Concerns**: [any issues or limitations]

#### [Repo 2: owner/repo] (if comparing)
[Same structure]

#### Comparison (if applicable)
| Aspect | Repo A | Repo B |
|--------|--------|--------|
| [aspect] | [finding] | [finding] |
```

---

## WebSearch Subagent Template

**Role contract — self-contained. Do not read SKILL.md. Do NOT load any browser skill or browser MCP.**

**Parameters you will receive from the orchestrator:**
- `RESEARCH_QUESTION` — the topic to investigate
- `TOPIC` — keyword form for search queries
- `CURRENT_YEAR` — for recency-scoped searches

**Deferred tools to load first:**
```
ToolSearch select:WebSearch,WebFetch
```

**Full instructions (use this as your prompt body):**

```
Research a technical topic using web search.

## Your Task
[RESEARCH_QUESTION — e.g., "Find benchmarks and comparisons for Zustand vs Jotai in 2026"]

## Search Queries
Execute these WebSearch queries (adjust as needed):
1. "[TOPIC] comparison [CURRENT_YEAR]"
2. "[TOPIC] benchmark performance"
3. "[TOPIC] vs [ALTERNATIVE] pros cons"
4. "[TOPIC] official documentation"

## Guidelines
- Include the current year in queries for recent results
- Follow up on promising results with WebFetch to read full articles
- Focus on authoritative sources: official docs, reputable blogs, conference talks
- Extract concrete data: benchmarks, bundle sizes, API differences

## Report
Return findings in this format:

### Web Research Findings: [Topic]

#### Official Documentation
- [Key points from official docs]

#### Benchmarks & Performance
- [Data points with source URLs]

#### Community Articles
- [Notable blog posts or tutorials with URLs]

#### Recent Announcements
- [Any recent news or updates]

#### Sources
- [Title](URL)
- [Title](URL)
```
