# tech-research

[English](README.md)

一个 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill，用于多源技术调研。从三个数据源采集情报并合成为统一报告——简单查询用轻量子 agent（Task Subagent），重度竞品调研用可互相协作的 Agent Teammate。

| 数据源 | 工具 | 提供什么 |
|--------|------|----------|
| **Grok** | 浏览器自动化 → grok.com | X (Twitter) 开发者讨论、社区情感、专家发现 |
| **DeepWiki** | DeepWiki MCP → `ask_question` | AI 驱动的 GitHub 仓库分析、架构、API 文档 |
| **WebSearch** | 内置搜索 | 官方文档、基准测试、博客文章、近期公告 |

## 安装

```bash
npx skills add psylch/tech-research-skill -g -y
```

安装后重启 Claude Code。

## 前置要求

- **Claude Code** 或任何支持 [skills.sh](https://skills.sh/) 的 agent
- **浏览器自动化**，用于 Grok（可选——不可用时自动跳过）：
  - **Claude-in-Chrome**（零配置，推荐），或
  - **Playwright MCP**（通过 `grok_setup.sh` 自动配置）
- **DeepWiki MCP**，用于 GitHub 仓库分析（可选）

### Grok 浏览器后端

Grok 需要有登录态的浏览器自动化。skill 支持多种后端，按优先级检测：

| 优先级 | 后端 | MCP Server | 配置 |
|--------|------|------------|------|
| 1 | **Claude-in-Chrome** | `claude-in-chrome` | 零配置——直接使用 Chrome 登录态 |
| 2 | **Playwright-Grok** | `playwright-grok` | 一次性：运行 `grok_setup.sh setup` 从现有 Playwright 配置派生 |
| 3 | **Playwright**（默认） | `playwright` | 可用但无登录持久化 |

> **重要**：不要修改默认的 `playwright` MCP 来添加 `--user-data-dir`。这会让所有浏览器操作都走同一个 profile，破坏多 agent 并发能力。skill 会使用独立的 `playwright-grok` 实例。

#### 快速配置（无 Claude-in-Chrome 时）

如果已配置 Playwright MCP，运行：

```bash
bash ~/.agents/skills/tech-research/scripts/grok_setup.sh setup
```

这会将你的 `playwright` 配置复制为 `playwright-grok`，附带专用 profile 目录。然后重启 Claude Code，在新浏览器窗口中登录一次 Grok。

### 登录状态缓存

登录状态缓存在 `~/.claude/tech-research/.grok-status.json`：

- **`logged_in`** — 长期有效，不过期。直到 subagent 检测到实际登出才更新。
- **`logged_out`** — 2 小时后自动过期，之后乐观重试。
- **无文件** — 乐观模式，假设已登录。

```bash
# 检查当前状态
bash ~/.agents/skills/tech-research/scripts/grok_setup.sh check

# 清除缓存状态（重新登录后）
bash ~/.agents/skills/tech-research/scripts/grok_setup.sh reset
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
2. **预检** — 检测最佳可用浏览器后端和 Grok 登录状态
3. **选模式** — 根据调研复杂度选择 Light 或 Heavy 模式
4. **派发** — 以对应模式启动调研 agent
5. **合成** — 合并发现为结构化报告，包含 TL;DR、对比矩阵和可执行建议

### 调研模式

| 信号 | 模式 |
|------|------|
| 单一主题，多数据源 | **Light** — 最多 3 个并行 Task Subagent，各查一个数据源 |
| 多个主题/竞品需要交叉比较 | **Heavy** — Agent Teammate，可互相通信、共享发现、避免重复 |
| 调研过程可能需要动态调整范围 | **Heavy** |
| agent 数量 ≥ 4 | **Heavy** |

不是每次调研都需要全部 3 个数据源。skill 会根据问题类型选择：

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
- **乐观登录** — 默认假设 Grok 已登录，除非之前的尝试记录了 `logged_out`；避免不必要地打扰用户
- **自修复** — skill 包含完整的故障诊断决策树，处理脚本失败、状态文件陈旧、浏览器异常等情况

## 故障排除

| 症状 | 修复方法 |
|------|----------|
| Grok 明明登录了却总被跳过 | 运行 `grok_setup.sh reset` 清除陈旧状态 |
| `grok_setup.sh check` 返回异常结果 | 检查 `~/.claude.json` 中的 MCP server 名称是否正确 |
| 状态文件损坏 | 删除 `~/.claude/tech-research/.grok-status.json` |
| 脚本整体失败 | skill 会自动回退到基于 ToolSearch 的 MCP 检测 |

## 文件结构

```
tech-research-skill/
├── .claude-plugin/
│   └── plugin.json                   # 插件清单
├── skills/
│   └── tech-research/
│       ├── SKILL.md                  # 主 skill 定义
│       ├── references/
│       │   ├── subagent_templates.md # 各子 agent 的提示词模板
│       │   └── query_strategies.md   # Grok 查询策略
│       └── scripts/
│           └── grok_setup.sh        # 后端检测、配置、登录状态管理
├── README.md
├── README.zh.md
└── LICENSE
```

## 许可

MIT
