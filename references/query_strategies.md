# Grok Query Strategies

Choose the right strategy based on the research goal. **Strategy matters more than the topic itself.**

## Strategy A: Expert Discovery (HIGHEST success rate)

Best for: Finding people to follow, information sources, active practitioners.

```
Who are the most active and insightful [technology] developers on X that are worth following for [specific area] tips? I want developers who regularly share code snippets, tutorials, or real-world experience — not just news aggregators. Give me their @handles, what they're known for, and link to a recent notable post from each.
```

## Strategy B: Community Sentiment (HIGH success rate for popular topics)

Best for: New API launches, WWDC announcements, major framework releases.

```
Search X posts about [technology/announcement]. What are developers saying about:
1. [Specific aspect 1]
2. [Specific aspect 2]
3. Pain points or surprises
4. Best practices shared by prominent developers

Please include specific X post URLs or exact @username + date references so I can verify. Focus on posts from [time range].
```

## Strategy C: Technology Selection (MEDIUM success rate)

Best for: Choosing between libraries, understanding what the community actually uses.

```
What [type of tool/library] are [platform] developers currently using or recommending on X? I'm building [project description] and want to know what the community is actually choosing in [year]. Include @username references and post URLs where possible.
```

## Strategy D: CJK Developer Research (MEDIUM success rate)

Best for: Chinese/Japanese community insights. Query in the target language directly.

```
搜索 X 上中文开发者关于 [technology] 的讨论。我想知道 [specific questions]。请给出具体的推文链接和 @用户名。
```

## Strategy E: Workflow/Tool Discovery

Best for: Discovering how other developers use Claude Code, MCP servers, AI coding tools.

```
How are developers on X using [tool, e.g. Claude Code] for [domain, e.g. iOS development]? I want to know about skills, MCP servers, workflows, or automation techniques they've shared. Include @username and post URLs.
```

## Strategies to AVOID

- **Too-specific technical queries** (e.g., "CSS column pagination bug in WKWebView for CJK") — X is not Stack Overflow. Broaden the topic.
- **Searching for a specific library name** when it's niche — instead, search for the **need** it fulfills.

## Key Rules

- Always ask Grok to "include specific X post URLs or @username + date references"
- For non-English communities, query in the target language directly
- If Fast mode returns insufficient results, broaden the query before switching to Expert mode
