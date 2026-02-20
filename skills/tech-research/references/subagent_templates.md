# Subagent Prompt Templates

Complete prompt templates for dispatching research subagents. Copy and customize the `[PLACEHOLDERS]`.

## Grok Subagent Template

The Grok subagent receives a `BACKEND` parameter that determines which browser tools to use. Replace `[BACKEND]` with the value from `grok_setup.sh check`.

```
Research a technical topic using Grok (grok.com) via browser automation.

## Your Task
[RESEARCH_QUESTION — e.g., "What are iOS developers saying about SwiftData vs Core Data?"]

## Browser Backend: [BACKEND]

Use the following tools based on your assigned backend:

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

## Step 1: Open Grok and Check Login

**IMPORTANT: Always start a NEW tab/page for each Grok query. Do NOT ask multiple questions in the same Grok session** — follow-up questions in the same chat degrade answer quality and may hit rate limits. One query per page, then close/leave it.

1. Load browser tools using ToolSearch as described above for your backend
2. Navigate to https://grok.com
3. Check the page state (snapshot/read_page):
   - If "Sign in" link/button is visible → NOT logged in:
     - Run: bash ${SKILL_PATH}/scripts/grok_setup.sh status logged_out [BACKEND]
     - Return: "GROK_SKIPPED: Not logged in. User should log into grok.com in [browser description], then run `grok_setup.sh reset`."
   - If chat interface is visible → logged in, proceed to Step 2

## Step 2: Query Grok

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

## Step 3: Report

1. For 2-3 X post URLs in the response, navigate to verify they exist and content matches
2. Update login status:
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

## DeepWiki Subagent Template

```
Research GitHub repositories using the DeepWiki MCP tools.

## Your Task
[RESEARCH_QUESTION — e.g., "Analyze the architecture and API design of zustand vs jotai"]

## Repositories to Analyze
[REPO_LIST — e.g., "pmndrs/zustand", "pmndrs/jotai"]

## Step 1: Ask Targeted Questions
For each repository, use ToolSearch to load deepwiki tools (query: "+deepwiki"), then call mcp__deepwiki__ask_question directly with questions like:

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

## WebSearch Subagent Template

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
