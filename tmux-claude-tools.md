# Tmux + Claude Code Tools

## Security + Capability Scorecard (Audited 2026-03-18/19)

### Tmux Agent Tools

| Repo | Crit | High | Med | Low | Power | Top 3 Features | Verdict |
|---|---|---|---|---|---|---|---|
| [tmuxcc](https://github.com/nyanko3141592/tmuxcc) | 0 | 0 | 1 | 2 | 3/5 | Live pane preview; multi-agent tree view (Claude/Codex/Gemini/OpenCode); batch approval gating | Safe. Best lightweight monitor |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | 0 | 2 | 4 | 3 | 5/5 | 32-agent staged pipeline (plan→PRD→exec→verify); smart model routing saves 30-50% tokens; persistent verification loops | Safe with awareness. Most sophisticated orchestration |
| [Codeman](https://github.com/Ark0N/Codeman) | 0 | 2 | 4 | 3 | 4/5 | Mobile-first web UI + QR auth; 24hr respawn controller with context auto-cycling; remote access via Cloudflare tunnel | Set `CODEMAN_PASSWORD` + `CODEMAN_NO_AUTOSTART=1` before install |
| [agent-tmux-monitor](https://github.com/damelLP/agent-tmux-monitor) | 2 | 2 | 3 | 2 | 2/5 | Real-time context/token usage tracking; hook-based passive monitoring (~300ms); jump-to-session shortcuts | Build from source; single-user only |
| [agent-view](https://github.com/Frayo44/agent-view) | 2 | 4 | 4 | 3 | 3/5 | Universal tool support (any CLI agent); git worktree isolation per session; session forking with fresh branches | Caution — systemic shell injection pattern |
| [tmux-orchestrator-ai-code](https://github.com/bufanoc/tmux-orchestrator-ai-code) | 1 | 4 | 3 | 0 | 5/5 (concept) | Hierarchical agent teams (orchestrator→PM→engineer); self-scheduling check-ins; cross-project coordination | Do not use — transformative idea, prototype-quality code |

### Development Workflow Frameworks

| Repo | Crit | High | Med | Low | Power | Top 3 Features | Verdict |
|---|---|---|---|---|---|---|---|
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | 0 | 0 | 2 | 1 | 4/5 | Artifact-guided DAG workflow (proposal→spec→design→tasks); delta spec management with archival; supports 20+ AI tools | Safe. Set `OPENSPEC_TELEMETRY=0`. Cleanest of the frameworks |
| [superpowers](https://github.com/obra/superpowers) | 0 | 0 | 2 | 0 | 4/5 | TDD-first methodology with Iron Laws; structured plan→spec→subagent workflow; visual brainstorming companion (localhost) | Safe. Aggressive skill-loading language may feel heavyweight |
| [gstack](https://github.com/garrytan/gstack) | 0 | 1 | 3 | 0 | 4/5 | Headless browser CLI (Playwright); 15+ lifecycle commands (/investigate, /review, /ship, /qa); safety hooks (/careful, /freeze, /guard) | Safe. 2 leftover `eval` scripts in `bin/` |
| [spec-kit](https://github.com/github/spec-kit) | 0 | 3 | 3 | 0 | 4/5 | Spec-driven dev scaffolding (PRD→plan→tasks→code); multi-agent command gen for 22+ tools; extension/preset ecosystem | Safe from core. Caution with community extensions |
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 0 | 2 | 5 | 0 | 4/5 | Hook infrastructure (auto-format, secret detection, context tracking); ~30 agents + ~40 slash commands; continuous learning "instinct" system | Safe. Don't copy `@latest` MCP entries blindly |
| [get-shit-done](https://github.com/gsd-build/get-shit-done) | 0 | 3 | 2 | 0 | 4/5 | Wave-based parallel execution; context-rot monitoring with graceful handoffs; multi-runtime install (6+ AI tools) | Safe. Use granular perms, not `--dangerously-skip-permissions`. Memecoin in README |
| [humanlayer](https://github.com/humanlayer/humanlayer) | 1 | 3 | 3 | 1 | 4/5 | Human-in-the-loop approval gate (MCP server); multi-agent research planning; git-backed `thoughts` persistent context | Edit out `--dangerously-skip-permissions` from `ralph_impl.md` and `oneshot.md` |

### Recommended Stacks

**Tmux agent management:**
1. **oh-my-claudecode** — orchestration engine (highest capability, reasonable security)
2. **tmuxcc** — monitoring layer (cleanest code, solid visibility)
3. **Codeman** — remote/persistence layer (24/7 autonomy, needs config hardening)

**Development workflow (pick one or combine):**
1. **OpenSpec** — cleanest security, best for brownfield/spec-driven work
2. **superpowers** — best for TDD-heavy workflows
3. **gstack** — unique browser testing integration, good safety hooks

### Cross-Model Interop (CC ↔ Codex/ChatGPT)

Tools evaluated for enabling persistent, structured interaction between Claude Code and OpenAI Codex CLI (or ChatGPT API).

#### Baseline: Claude Code itself

| Tool | Crit | High | Med | Low | Power | Top 3 Security-Relevant Features | Verdict |
|---|---|---|---|---|---|---|---|
| **Claude Code** (v1.0.34) | 0 | 2 | 4 | 3 | 5/5 | Per-tool permission allow/deny gate; plugin blocklist with server-side revocation; opt-in MCP server loading | Safe with awareness. Your existing attack surface — normalize other tools against this |

> **Key risks already accepted by using CC:** full shell access by design; conversation context (incl. file contents) sent unredacted to Anthropic API; Statsig telemetry with persistent device ID; hooks receive full event JSON via shell; MCP servers share full process environment. These are design choices, not bugs.

#### Interop Candidates

| Repo | Crit | High | Med | Low | Power | Top 3 Features | Verdict |
|---|---|---|---|---|---|---|---|
| [PAL MCP](https://github.com/BeehiveInnovations/pal-mcp-server) | 0 | 1 | 3 | 1 | 4/5 | Multi-provider LLM routing (OpenAI/Gemini/Azure/OpenRouter/Ollama); cross-tool conversation threading via `continuation_id`; purpose-built tools (secaudit, codereview, consensus) | Safe with awareness. No positive path-scope on file reads |
| [tmux-team](https://github.com/wkh237/tmux-team) | 0 | 2 | 1 | 1 | 4/5 | Wait-mode with nonce-keyed sentinel for reliable response capture; preamble injection for persistent agent roles; broadcast-to-all with self-exclusion | Safe with awareness. Shell injection via unvalidated pane IDs in config |
| [NTM](https://github.com/Dicklesworthstone/ntm) | 0 | 1 | 2 | 1 | 4/5 | Multi-agent broadcast with per-agent submission protocol; REST+WebSocket API with RBAC and safety policy layer; session checkpointing with path-traversal-safe import/export | Safe with awareness. Hook `sh -c` expands unsanitized `$NTM_MESSAGE` |
| [Agent Deck](https://github.com/asheshgoplani/agent-deck) | 0 | 2 | 2 | 1 | 4/5 | Hook-based status detection via JSONL/fd parsing; session forking with `--fork-session` context inheritance; MCP pool with Unix socket proxy and dangerous-env filtering | Safe with awareness. `shellQuote` exists but not applied in fork commands |

#### Interop Capability Matrix

| Need | PAL MCP | tmux-team | NTM | Agent Deck | CC Teammates |
|---|---|---|---|---|---|
| Persistent context across turns | Yes (threading) | No (stateless) | No (stateless) | No | Yes |
| Codex's full agentic capabilities | No (API only) | Yes (real CLI) | Yes (real CLI) | Yes (real CLI) | No (CC-only) |
| Structured message passing | Yes (MCP) | Partial (pane I/O) | Yes (REST API) | No | Yes (subagent) |
| Codex reads your actual repo | No | Yes | Yes | Yes | N/A |
| Code review workflow | Yes (codereview tool) | Manual | Manual | Manual | Yes |
| Additive risk vs CC baseline | Low (API proxy) | Medium (shell injection) | Low (good sanitization) | Medium (quoting gaps) | None |

#### Recommendation

**For API-level review (GPT-4 reviews CC's code):** PAL MCP — lowest additive risk, conversation threading gives persistence, but reviewer can't explore your repo independently.

**For CLI-level coordination (Codex CLI as a peer agent):** NTM — best security posture of the tmux coordinators (literal-mode `send-keys`, session name validation, RBAC on REST API). tmux-team has the right architecture (wait-mode, preamble injection) but needs the pane ID injection patched first.

**The gap no tool fills:** A proper MCP server wrapping Codex CLI in a persistent tmux session — combining PAL MCP's structured protocol with tmux-team's wait-mode response capture.

### Tmux MCP Servers & Agent Bridges (Literature Review — 2026-04-11)

Tools discovered via literature review that directly address the CC ↔ Codex interop gap. Organized by how directly they solve bidirectional agent coordination.

#### Tier 1 — Direct CC ↔ Codex Solutions

> Normalized against **Claude Code baseline** (0C/2H/4M/3L, Power 5/5). "Additive risk" = risk beyond what you already accept by using CC.

| Tool | ★ | Crit | High | Med | Low | Power | Additive Risk | What it does | Bidirectional? | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| [AgentChattr](https://github.com/bcurts/agentchattr) | 1,244 | 0 | 1 | 2 | 1 | 4/5 | Low | Local chat relay where agents @-mention each other across terminals; browser UI; screen-buffer activity detection | Yes (true) | Safe w/ awareness. Unauthenticated MCP ports allow file read via `image_path` |
| [codex-mcp-server](https://github.com/tuannvm/codex-mcp-server) | 411 | 0 | 2 | 3 | 1 | 3/5 | Low (Unix) | Exposes Codex CLI as an MCP tool CC can call; session memory across turns; parallel agent dispatch | No (CC→Codex) | Safe w/ awareness. Windows shell injection; unvalidated `callbackUri` SSRF |
| [codex-as-mcp](https://github.com/kky42/codex-as-mcp) | 154 | 0 | 1 | 2 | 1 | 3/5 | Low | Lightweight Codex-as-MCP wrapper; Python; `asyncio.subprocess` with no shell; minimal codebase (~200 LOC) | No (CC→Codex) | Safe w/ awareness. Unnecessary manual prompt quoting |
| [codex-claude-bridge](https://github.com/abhishekgahlot2/codex-claude-bridge) | 31 | 0 | 2 | 3 | 2 | 3/5 | **Medium** | Bridges CC and Codex via Claude Channels (experimental API); localhost web UI for monitoring exchanges | Asymmetric | Safe w/ awareness. Unauthenticated `/api/from-codex` injects into Claude's context |

#### Tier 2 — Tmux MCP Servers (Plumbing Layer)

| Tool | ★ | Crit | High | Med | Low | Power | Additive Risk | Runtime | Differentiator | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| [nickgnd/tmux-mcp](https://github.com/nickgnd/tmux-mcp) | 256 | 0 | 2 | 3 | 1 | 3/5 | **Medium** | Node | General-purpose tmux MCP: create/list/kill sessions, send-keys, capture-pane; `npx -y tmux-mcp` | Safe w/ awareness. Shell injection via `exec()` — should use `execFile`; no permission gate |
| [MadAppGang/tmux-mcp](https://github.com/MadAppGang/tmux-mcp) | 20 | 0 | 1 | 2 | 1 | 4/5 | Low | Go | Agent-oriented: process-aware triggers detect when commands finish; sync execute returns exit codes; isolated headless socket | Safe w/ awareness. `wrapCommand` shell template injection; `/tmp` TOCTOU on shared hosts |
| [tmux-bridge-mcp](https://github.com/howardpen9/tmux-bridge-mcp) | 13 | — | — | — | — | — | — | Node | Purpose-built for cross-pane AI agent messaging; lets Claude/Codex/Gemini/Kimi CLI talk to each other via tmux | Not audited |
| [michael-abdo/tmux-claude-mcp-server](https://github.com/michael-abdo/tmux-claude-mcp-server) | 15 | — | — | — | — | — | — | Node | Hierarchical Claude orchestrator: spawn child Claude instances, send prompts, read responses, terminate | Not audited |
| [bnomei/tmux-mcp](https://github.com/bnomei/tmux-mcp) | 10 | — | — | — | — | — | — | Rust | Policy-enforced tmux MCP with allow/deny tool gating; structured I/O; stable IDs across restarts | Not audited |
| [PsychArch/tmux-mcp-tools](https://github.com/PsychArch/tmux-mcp-tools) | 7 | — | — | — | — | — | — | Python | Minimal tmux MCP toolset (create, capture, send-keys, write-file); supports HTTP transport mode | Not audited |
| [quink-black/tmux-mcp-agent](https://github.com/quink-black/tmux-mcp-agent) | 6 | — | — | — | — | — | — | Python | Controls remote servers through local tmux sessions via SSH jump-hosts; no remote install needed | Not audited |

#### Tier 3 — Orchestration (Manage Agents, Not Inter-Agent Chat)

| Tool | ★ | Crit | High | Med | Low | Power | Additive Risk | What it does | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| [claude-squad](https://github.com/smtg-ai/claude-squad) | 6,954 | 0 | 1 | 2 | 1 | 4/5 | Low | TUI managing multiple agents in parallel tmux sessions; each gets its own git worktree; daemon mode for unattended runs | Safe w/ awareness. AutoYes dismisses CC trust prompts; config 0644 on shared hosts |
| [AWS CLI Agent Orchestrator](https://github.com/awslabs/cli-agent-orchestrator) | 452 | 0 | 2 | 3 | 2 | 3/5 | Low | AWS Labs: isolated tmux sessions with MCP-based inbox messaging between agents; SQLite state; flow scheduler for multi-step tasks | Safe w/ awareness. `pipe-pane` shell injection; unvalidated `sender_id` in inbox |
| [maniple](https://github.com/Martian-Engineering/maniple) | 41 | — | — | — | — | — | — | Python orchestrator that launches and manages Claude/Codex sessions in iTerm2 or tmux with structured prompting | Not audited |
| [openclaw-tmux-claude-ops](https://github.com/Yaxuan42/openclaw-tmux-claude-ops) | 27 | — | — | — | — | — | — | Dispatches Claude Code tasks as background tmux sessions; task queue with status tracking and result collection | Not audited |

#### Key Protocol Notes

- **Codex CLI has native MCP support** (client + server modes) — a tmux MCP server can serve both CC and Codex natively
- **Google A2A protocol** complements MCP: MCP = agent-to-tool, A2A = agent-to-agent (no terminal implementations yet)
- **No Claude Code skill (SKILL.md) exists** for tmux coordination — confirmed gap across 400+ skills in major collections

---

## User Reception (GitHub Metrics — 2026-04-11)

> **Tier key:** Blockbuster 100K+ ★ · Mainstream 50K+ · Popular 10K+ · Established 1K+ · Growing 100+ · Niche 10+ · Minimal <10
> **Activity:** Active (≤7 d) · Recent (≤30 d) · Moderate (≤90 d) · Slow (≤180 d) · Dormant (>180 d)

### Tmux Agent Tools

| Repo | ★ Stars | Forks | Issues | Language | Last Push | Activity | Tier |
|---|---|---|---|---|---|---|---|
| [tmuxcc](https://github.com/nyanko3141592/tmuxcc) | 56 | 5 | 0 | Rust | 2026-01-19 | Moderate | Niche |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | 27,707 | 2,554 | 6 | TypeScript | 2026-04-11 | Active | Mainstream |
| [Codeman](https://github.com/Ark0N/Codeman) | 298 | 34 | 0 | TypeScript | 2026-04-11 | Active | Growing |
| [agent-tmux-monitor](https://github.com/damelLP/agent-tmux-monitor) | 5 | 1 | 5 | Rust | 2026-04-09 | Active | Minimal |
| [agent-view](https://github.com/Frayo44/agent-view) | 346 | 36 | 12 | TypeScript | 2026-03-27 | Recent | Growing |
| [tmux-orchestrator-ai-code](https://github.com/bufanoc/tmux-orchestrator-ai-code) | 2 | 3 | 0 | — | 2025-07-14 | Dormant | Minimal |

### Development Workflow Frameworks

| Repo | ★ Stars | Forks | Issues | Language | Last Push | Activity | Tier |
|---|---|---|---|---|---|---|---|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 151,215 | 23,426 | 64 | JavaScript | 2026-04-10 | Active | Blockbuster |
| [superpowers](https://github.com/obra/superpowers) | 147,023 | 12,619 | 274 | Shell | 2026-04-10 | Active | Blockbuster |
| [spec-kit](https://github.com/github/spec-kit) | 87,099 | 7,484 | 622 | Python | 2026-04-10 | Active | Mainstream |
| [gstack](https://github.com/garrytan/gstack) | 69,826 | 9,793 | 338 | TypeScript | 2026-04-11 | Active | Mainstream |
| [get-shit-done](https://github.com/gsd-build/get-shit-done) | 50,636 | 4,226 | 27 | JavaScript | 2026-04-11 | Active | Mainstream |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | 39,117 | 2,660 | 291 | TypeScript | 2026-04-11 | Active | Popular |
| [humanlayer](https://github.com/humanlayer/humanlayer) | 10,367 | 883 | 67 | TypeScript | 2026-03-07 | Recent | Popular |

### Session/Agent Managers (additional)

| Repo | ★ Stars | Forks | Issues | Language | Last Push | Activity | Tier |
|---|---|---|---|---|---|---|---|
| [Agent Deck](https://github.com/asheshgoplani/agent-deck) | 1,998 | 210 | 32 | Go | 2026-04-10 | Active | Established |
| [NTM](https://github.com/Dicklesworthstone/ntm) | 235 | 40 | 0 | Go | 2026-04-11 | Active | Growing |

### Orchestration / Team Coordination (additional)

| Repo | ★ Stars | Forks | Issues | Language | Last Push | Activity | Tier |
|---|---|---|---|---|---|---|---|
| [tmux-team](https://github.com/wkh237/tmux-team) | 3 | 0 | 2 | TypeScript | 2026-01-17 | Moderate | Minimal |

### Multi-Model MCP Servers

| Repo | ★ Stars | Forks | Issues | Language | Last Push | Activity | Tier |
|---|---|---|---|---|---|---|---|
| [PAL MCP](https://github.com/BeehiveInnovations/pal-mcp-server) | 11,406 | 978 | 122 | Python | 2025-12-15 | Moderate | Popular |
| [gemini-mcp](https://github.com/RLabs-Inc/gemini-mcp) | 181 | 38 | 5 | TypeScript | 2026-03-13 | Recent | Growing |
| [gemini-cli-mcp-server](https://github.com/centminmod/gemini-cli-mcp-server) | 136 | 15 | 4 | — | 2025-07-21 | Dormant | Growing |
| [claude-code-gemini-mcp](https://github.com/ShunL12324/claude-code-gemini-mcp) | 0 | 0 | 0 | JavaScript | 2025-12-09 | Dormant | Minimal |

### Resources

| Repo | ★ Stars | Forks | Issues | Language | Last Push | Activity | Tier |
|---|---|---|---|---|---|---|---|
| [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | 38,046 | 3,091 | 201 | Python | 2026-04-11 | Active | Popular |

---

## All Tools

### Session/Agent Managers

| Tool | ★ | Security | What it does |
|---|---|---|---|
| [Agent Deck](https://github.com/asheshgoplani/agent-deck) | 1,998 | Safe w/ awareness | TUI on top of tmux — smart status detection (thinking vs waiting), session forking with context inheritance, MCP management, global search across conversations |
| [NTM (Named Tmux Manager)](https://github.com/Dicklesworthstone/ntm) | 235 | Safe w/ awareness | Multi-agent command center — tiled panes, broadcast prompts to all agents, conflict tracking, animated dashboard |
| [tmuxcc](https://github.com/nyanko3141592/tmuxcc) | 56 | Safe | TUI dashboard for monitoring multiple AI agents (Claude, Codex, Gemini) from a single terminal |
| [agent-tmux-monitor](https://github.com/damelLP/agent-tmux-monitor) | 5 | Caution | Real-time dashboard for monitoring multiple Claude Code sessions |
| [agent-view](https://github.com/Frayo44/agent-view) | 346 | Caution | Tool-agnostic agent manager with persistent state and real-time status indicators |

### Orchestration / Team Coordination

| Tool | ★ | Security | What it does |
|---|---|---|---|
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | 27,707 | Safe w/ awareness | Claude Code plugin for teams-first multi-agent orchestration — installable via `/plugin marketplace` |
| [tmux-team](https://github.com/wkh237/tmux-team) | 3 | Safe w/ awareness | Coordinates AI agents across tmux panes — send messages, wait for responses, broadcast to all |
| [tmux-orchestrator-ai-code](https://github.com/bufanoc/tmux-orchestrator-ai-code) | 2 | Avoid | AI agents that oversee and direct your main coding agent |
| [ittybitty](https://adamwulf.me/2026/01/itty-bitty-ai-agent-orchestrator/) | — | Not audited | Spawns Claude in a virtual terminal in tmux, which can recursively spawn more Claude instances |

### Development Workflow Frameworks

| Tool | ★ | Security | What it does |
|---|---|---|---|
| [everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 151,215 | Safe | Comprehensive hook infrastructure, ~30 agents, ~40 commands, AgentShield security, instinct learning system |
| [superpowers](https://github.com/obra/superpowers) | 147,023 | Safe | TDD-first methodology, Iron Laws, structured plan→spec→subagent workflow with visual brainstorming |
| [spec-kit](https://github.com/github/spec-kit) | 87,099 | Safe (core) | GitHub's spec-driven development toolkit — constitution, 22+ tools, multi-agent command generation |
| [gstack](https://github.com/garrytan/gstack) | 69,826 | Safe | Role personas (CEO/Designer/QA/EngMgr), headless browser CLI, parallel sprints, safety hooks |
| [get-shit-done](https://github.com/gsd-build/get-shit-done) | 50,636 | Safe | Wave-based parallel execution, context-rot management, fresh 200K context windows per subagent |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | 39,117 | Safe | Artifact DAG workflow, delta specs, brownfield-first, supports 20+ AI tools |
| [humanlayer](https://github.com/humanlayer/humanlayer) | 10,367 | Caution | Human-in-the-loop approval MCP server, multi-agent research planning, git-backed thoughts system |

### Fancy UIs

| Tool | ★ | Security | What it does |
|---|---|---|---|
| [Codeman](https://github.com/Ark0N/Codeman) | 298 | Safe (config first) | Web UI for managing Claude/OpenCode tmux sessions — draggable floating windows with animated Matrix-style connection lines |

### Multi-Model MCP Servers (call other LLMs from within Claude Code)

| Tool | ★ | Security | What it does | Models |
|---|---|---|---|---|
| [PAL MCP](https://github.com/BeehiveInnovations/pal-mcp-server) | 11,406 | Safe w/ awareness | Multi-model proxy — conversation threading, second opinions, collaborative debates between models | OpenAI, Gemini, OpenRouter (400+), Azure, Grok, Ollama, custom |
| [gemini-mcp](https://github.com/RLabs-Inc/gemini-mcp) | 181 | Not audited | Claude Code ↔ Gemini collaboration | Gemini |
| [gemini-cli-mcp-server](https://github.com/centminmod/gemini-cli-mcp-server) | 136 | Not audited | Gemini CLI integration + OpenRouter for 400+ models | Gemini 2.5 + OpenRouter |
| [claude-code-gemini-mcp](https://github.com/ShunL12324/claude-code-gemini-mcp) | 0 | Not audited | Call Gemini via OpenAI-compatible API from Claude Code | Gemini via OpenAI API |
| [Composio Gemini](https://composio.dev/toolkits/gemini/framework/claude-code) | — | Not audited | Managed Gemini integration for Claude Code | Gemini |

### Resources

| Resource | ★ | Security | What it does |
|---|---|---|---|
| [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | 38,046 | N/A (list) | Curated list of skills, hooks, slash-commands, agent orchestrators, and plugins for Claude Code |

---

## Unified View Ranking ("I run lots of CC in tmux and want one dashboard")

Security scale: normalized against Claude Code itself = 5/10 as baseline. That baseline is middling because CC does have read-only defaults, permission prompts, and an optional sandbox, but it also sends prompts/outputs over the network and stores local session transcripts in plaintext under `~/.claude/projects/` by default.

| Rank | Tool | GitHub ★ | Best for | Existing-session discovery | Summary ability | Security vs CC baseline | Take |
|---|---|---|---|---|---|---|---|
| 1 | [claude-dashboard](https://github.com/anthropics/claude-dashboard) | 26 | TUI, passive visibility across lots of sessions | Excellent | Light | 6/10 | Best match if your main need is "find all my CC sessions, including tmux and non-tmux" |
| 2 | [Codeman](https://github.com/Ark0N/Codeman) | 298 | Browser UI, persistent multi-session management | Very good | Moderate | 4/10 | Most capable web front-end, but larger attack surface than terminal-only tools |
| 3 | [recon](https://github.com/anthropics/recon) | 196 | tmux-native management from one terminal | Good (inside tmux) | Light | 6/10 | Great if you want to stay in tmux and actively manage agents |
| 4 | [Eyes on Claude Code](https://github.com/anthropics/eyes-on-claude-code) | 23 | Hook-based monitoring across projects | Good, if hooks are installed | Light–moderate | 5/10 | Nice monitoring layer, but visibility depends on modifying CC hooks |
| 5 | [claude-tmux-dashboard](https://github.com/anthropics/claude-tmux-dashboard) | 1 | Single-session sidecar dashboard | Poor | Minimal | 5/10 | More of a dashboard pane than a true multi-session aggregator |

> Star counts from GitHub pages loaded 2026-04-11 and will drift over time.

### Why this ranking

**1) claude-dashboard — strongest fit for unified visibility**
Its README explicitly says it does unified session detection and finds Claude sessions in tmux, terminal tabs, and anywhere in the process tree. It also reads conversation history from `~/.claude/projects/` and says terminal sessions are read-only while tmux sessions can be attached. That is the clearest "discover existing sessions I did not launch here" story in the set.

Security: scored a bit above CC baseline because it appears primarily observational — session detection, log viewing, read-only terminal visibility for some sessions, and tmux attach for others. Still sensitive, but less inherently risky than a browser-based orchestrator with autonomous controls. This is an inference from stated features, not a formal audit.

**2) Codeman — best browser UI, but more risk**
Most feature-rich web option: every session runs inside tmux, it has ghost session discovery for orphaned tmux sessions, real-time terminals, notifications, token/cost tracking, and unattended respawn/context-management with auto `/compact` and `/clear`. Richest operator experience.

Security: rated below CC baseline because a web front-end + real-time terminals + unattended respawn/controller logic is a broader attack surface than plain CC in a terminal. No clearly documented privacy/security model found in the README — this lower score reflects architectural exposure, not evidence of wrongdoing.

**3) recon — best pure tmux operator console**
Explicitly a tmux-native dashboard for managing multiple Claude Code sessions in tmux. Shows what each agent is doing, which need attention, lets you switch/kill/spawn/resume sessions from one keybinding. Groups agents by git repo and shows context usage in the UI.

Security: slightly above CC baseline — stays terminal-native, no web layer, but more of an active controller than claude-dashboard. Ideal when sessions are already tmux-centric. Weaker than claude-dashboard specifically for "find sessions outside tmux/process tree everywhere."

**4) Eyes on Claude Code — good monitoring, hook-dependent**
Collects events from Claude Code global Hooks and presents session state across projects in a tray/dashboard with tmux interaction. Has a `SECURITY.md` (small positive signal of maturity). Model depends on installing generated hook config into `~/.claude/settings.json` — less "auto-discover everything already running" and more "instrument CC so future sessions emit events."

Security: about baseline — hooks are powerful, but also mean more execution points and more moving parts. Sits on top of CC's hooks rather than replacing CC's permission model; not clearly safer or clearly riskier without a deeper code review.

**5) claude-tmux-dashboard — neat, but limited**
Split-pane tmux dashboard. Starts a tmux session with Claude on the left and a live dashboard on the right, dashboard updates by reading `~/.claude/dashboard.json`. Useful, but not a tool for discovering and summarizing arbitrary pre-existing tmux windows across the machine.

Security: roughly baseline — pretty simple, but also not especially protective beyond whatever CC and your shell environment already do. One-line curl installer warrants caution.

### Blunt recommendation

For "I have lots of CC sessions in tmux windows; which tool best finds and unifies them?":

1. **claude-dashboard** — best unified discovery
2. **recon** — if you want to stay fully terminal-native
3. **Codeman** — if you want the nicest browser control plane and accept a bigger security surface

### Security quick read

If you care about not making CC's security posture worse:
- **Safest-ish:** claude-dashboard, recon
- **Middle:** Eyes on Claude Code
- **Riskiest by surface area:** Codeman
- **Low-complexity but limited:** claude-tmux-dashboard

Not a vulnerability statement — just the usual rule: browser UI + session control + unattended automation = more ways for things to go sideways.

### Detailed comparison dimensions (TODO)

If needed: discovers pre-existing tmux sessions, supports non-tmux sessions, read-only vs control, local-only operation, whether they appear to phone home.
