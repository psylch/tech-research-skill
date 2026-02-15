# Subagent Prompt Templates

Complete prompt templates for dispatching research subagents. Copy and customize the `[PLACEHOLDERS]`.

## Grok Subagent Template

```
Research a technical topic using Grok (grok.com) via Playwright browser automation.

## Your Task
[RESEARCH_QUESTION — e.g., "What are iOS developers saying about SwiftData vs Core Data?"]

## Pre-flight
Run: bash ${CLAUDE_PLUGIN_ROOT}/skills/tech-research/scripts/grok_preflight.sh
- Exit 0 (READY): proceed to Step 1
- Exit 1 (NEEDS_LOGIN): proceed to Step 1, verify login in snapshot
- Exit 2 (NOT_CONFIGURED): return "BLOCKED: MCP not configured"
- Any other: return "BLOCKED: [error message]"

## Step 1: Open a Fresh Grok Page
**IMPORTANT: Always start a NEW tab/page for each Grok query. Do NOT ask multiple questions in the same Grok session** — follow-up questions in the same chat degrade answer quality and may hit rate limits. One query per page, then close/leave it.

1. Use ToolSearch to load Playwright tools (query: "+playwright navigate snapshot click type")
2. Navigate to https://grok.com (in a new tab if one is already open)
3. Take a snapshot — if `link "Sign in"` visible (not logged in):
   - Run: bash ${CLAUDE_PLUGIN_ROOT}/skills/tech-research/scripts/grok_update_status.sh logout
   - Return: "BLOCKED: Grok session expired. User needs to log in once in the Playwright browser window."

## Step 2: Query Grok
4. Click "Model select" button, then click the "Fast" menu item
5. Fill the chat input (it's a contenteditable div, NOT a standard input):
   ```js
   async (page) => {
     const editor = await page.$('[contenteditable="true"]');
     await editor.click();
     await editor.fill('[GROK_QUERY]');
     return 'Filled';
   }
   ```
6. Take a snapshot to find the "Submit" button ref, then click it

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

7. Wait for response: use browser_run_code with page.waitForTimeout(8000)
8. Take a snapshot to read the full response
9. If "Stop model response" button is still visible, wait 5s and snapshot again

## Step 3: Report
10. For 2-3 X post URLs in the response, navigate to verify they exist and content matches
11. Run: bash ${CLAUDE_PLUGIN_ROOT}/skills/tech-research/scripts/grok_update_status.sh login
12. Return findings in this format:

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
