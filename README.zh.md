# tech-research

一个 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 技能，用于多源技术调研。通过并行派发子 agent 从三个数据源采集情报，并合成为统一的调研报告。

| 数据源 | 工具 | 提供什么 |
|--------|------|----------|
| **Grok** | Playwright 浏览器自动化 → grok.com | X (Twitter) 开发者讨论、社区情感、专家发现 |
| **DeepWiki** | DeepWiki MCP → `ask_question` | AI 驱动的 GitHub 仓库分析、架构、API 文档 |
| **WebSearch** | 内置搜索 | 官方文档、基准测试、博客文章、近期公告 |

## 安装

```bash
git clone https://github.com/psylch/tech-research-skill.git ~/.claude/skills/tech-research
```

安装后重启 Claude Code。

## 前置要求

- **Claude Code**，需要有 Task 工具权限（用于派发子 agent）
- **Playwright MCP**，配置 `--user-data-dir` 以保持 Grok 登录状态（可选——Grok 不可用时自动跳过）
- **DeepWiki MCP**，用于 GitHub 仓库分析（可选）

### Playwright MCP 配置（用于 Grok）

在 `~/.claude.json` 中添加：

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

## 使用方式

在 Claude Code 中使用以下触发短语：

```
/tech-research
调研一下 Zustand vs Jotai
research this technology: Bun
compare libraries: Vite vs Turbopack
技术调研：SolidJS
```

## 工作原理

1. **分析** — 将调研问题拆解为各数据源的子查询
2. **派发** — 并行启动最多 3 个子 agent（Grok、DeepWiki、WebSearch）
3. **合成** — 合并发现为结构化报告，包含 TL;DR、对比矩阵和可执行建议

不是每次调研都需要全部 3 个数据源。技能会根据问题类型选择：

| 调研类型 | Grok | DeepWiki | WebSearch |
|----------|------|----------|-----------|
| "要不要用库 X？" | 是 | 是 | 是 |
| "开发者怎么看 X？" | 是 | 否 | 可能 |
| "仓库 X 内部怎么实现的？" | 否 | 是 | 可能 |
| "X 和 Y 性能对比" | 可能 | 是（两个） | 是 |

## 关键设计决策

- **Grok 查询必须包含 X/Twitter 关键词**（如"X 上的开发者怎么看..."），避免退化为通用搜索，与 WebSearch 重复
- **每次 Grok 查询开新页面** — 不在同一会话中多次提问
- **DeepWiki 只用 `ask_question`** — `read_wiki_structure` 和 `read_wiki_contents` 返回的内容量太大，容易超出 context 限制
- **验证 Grok 引用的推文链接** — 子 agent 会实际访问 2-3 个引用的 URL 检查是否真实存在

## 文件结构

```
tech-research/
├── SKILL.md                          # 主技能定义
├── references/
│   ├── subagent_templates.md         # 各子 agent 的完整提示词模板
│   └── query_strategies.md           # Grok 查询策略（5 种模式）
└── scripts/
    ├── grok_preflight.sh             # Grok 可用性预检脚本
    └── grok_update_status.sh         # 跟踪 Grok 登录状态
```

## 可选：ask-grok 技能

本技能可选地委托 [ask-grok](https://github.com/nicobailon/ask-grok-claude-code) 技能来追踪 Grok 登录状态。如果未安装 ask-grok，会退化为每次通过 Playwright 截图检查登录状态。

## 许可

MIT
