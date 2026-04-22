# CC ↔ Codex Interop — Feature Brief

> Design notes for the feature we're trying to land: **let Claude Code and OpenAI
> Codex work together as peers, using the ChatGPT subscription (Codex CLI), not
> the paid OpenAI API.** Bidirectional communication is a stretch goal.
>
> Companion docs: `tmux-claude-tools.md` (security audit of 20+ candidate tools),
> `tmux-pane-addressing.md` (the tmux addressing + coordination primitives).

---

## 1. What we're building, in one paragraph

A persistent, low-friction channel for Claude Code to hand work to OpenAI Codex
— code review, adversarial critique, "second opinion" consults — and (stretch)
for Codex to hand work back. Authentication must flow through `codex login`
(ChatGPT subscription), not `OPENAI_API_KEY`. The channel should preserve
session/thread state across turns so follow-ups don't re-explain context. It
must be scoped to a single developer machine; no multi-tenant surface.

### Non-goals

- Calling GPT-4/5 via `api.openai.com` (that's what **PAL MCP** already does —
  it's good, but it burns API credit, and the reviewer can't actually read your
  repo).
- Being Codex's "manager" or running a whole pipeline of agents. That's what
  **oh-my-claudecode** does well; this feature is lighter.
- A multi-user web UI, mobile control, or remote access. Out of scope.

---

## 2. Constraints and success criteria

| Constraint | Why it matters |
|---|---|
| **Uses `codex` CLI, not OpenAI API** | Flat subscription cost; inherits Codex's agentic repo access (real `git diff`, real `Read`, sandboxed `Bash`). |
| **No hardcoded model** | OpenAI ships new Codex models frequently. Pass `-m` through, let the CLI pick defaults. |
| **Read-only by default for Codex** | Codex should advise, not write. Use `-s read-only` sandbox flag. One agent writing to disk is enough surprise. |
| **Session continuity** | Follow-ups ("what about edge case X?") must reuse the same Codex thread. `codex exec resume <session-id>` is the mechanism. |
| **Persistent Codex process in a sibling pane** | A fresh `codex exec` per turn loses in-flight state (loaded files, shell env, scrollback). Keep one long-running Codex in its own pane — same tmux window as CC — for multi-turn ping-pong. This is a harder constraint than session resume alone: `resume` re-hydrates memory but still spawns a new process every call. |
| **Works offline from `api.openai.com` billing** | ChatGPT subscription auth only. If user hasn't run `codex login`, fail loudly with install instructions. |
| **Verbatim output passthrough** | Don't let CC summarize Codex's feedback — that reintroduces the first-opinion bias the feature exists to escape. |

### Done looks like

1. A single slash command or skill in CC that takes a prompt (or auto-detects a
   diff / plan file) and produces Codex's response.
2. A durable session ID so the next invocation continues the conversation.
3. Output rendered verbatim inside a CC message, with a clear `CODEX SAYS` delimiter.
4. (Stretch) Codex-side can hand back to CC without opening a new terminal.

---

## 3. Three architectural options

### Option A — Skill that shells out to `codex` (what `gstack /codex` does today)

**How it works.** A Claude Code skill (`.claude/skills/codex/SKILL.md`)
invokes `codex exec "<prompt>" -s read-only --json`, parses the JSONL event
stream, and prints the result. Session ID is captured from the
`thread.started` event and written to `.context/codex-session-id`. Follow-ups
run `codex exec resume <id>`. One-way: CC → Codex → back to CC in the same
turn.

**Reference implementation in-tree:** `repos/gstack/codex/SKILL.md`. Worth
reading end-to-end — it's ~500 lines and covers:

- Auth check (`which codex`; fail with install hint if missing).
- Three modes: `review` (`codex review --base <branch>` with P1/P2 gate),
  `challenge` (adversarial, `xhigh` reasoning), `consult` (free-form with
  session resume).
- JSONL stream parser in inlined Python — extracts `reasoning`, `agent_message`,
  `command_execution`, and token usage, so you see Codex's thinking traces, not
  just the final answer.
- 5-minute timeout on every Bash call (`timeout: 300000`).
- Cross-model agreement analysis: if `/review` (CC's own reviewer) already ran
  earlier in the conversation, diff the findings.

**Strengths.**

- Zero infrastructure. No background process, no ports, no config beyond the
  skill file.
- Fail-closed: if `codex` binary is missing, skill exits at Step 0.
- Inherits all of Codex's agentic capability for free — it reads your actual
  repo, runs `git diff`, etc., because `codex exec` starts in CWD.
- Session IDs persist in-repo (`.context/codex-session-id`), so resume works
  across CC sessions too, not just across turns.

**Weaknesses.**

- Strictly unidirectional. Codex can't call back to CC.
- Each invocation spawns a fresh `codex` process (~1–3s startup overhead). For
  rapid ping-pong, this adds up.
- **Fails the persistent-pane constraint.** `codex exec resume` re-hydrates
  session memory but not process state — no live scrollback, no in-memory
  caches, no shell env. If the use case is "Codex sits there, Claude keeps
  poking it," Option A alone doesn't cover it. See Option D (hybrid).
- No introspection into what Codex is doing mid-run beyond what JSONL emits.

**Security posture.** Very clean. `-s read-only` sandbox, no shell-escaped
user input in sensitive positions, temp files in `$(mktemp)`, explicit
cleanup. No new network listeners, no new ports, no new MCP servers.

**Best for:** the 80% case. Start here.

---

### Option B — Tmux MCP server that both agents share

**Build-vs-buy status.** The MCP *servers* below are off-the-shelf packages —
you install them, they work. The **wiring** is what we'd write: registering
the same server with both CLIs, agreeing on a pane-ID exchange handshake at
startup, and picking a response-capture pattern. That glue is ~50–150 lines of
bash/skill markdown, not a new server.

**How it works.** Run one tmux MCP server on the local machine. Register it
with **both** Claude Code (via `.claude/settings.json` MCP config) and Codex
(via `~/.codex/config.toml` — Codex has native MCP client support, per
`tmux-claude-tools.md:118`). Now:

- CC has tools like `tmux.send_keys(pane="%7", text=...)`,
  `tmux.capture_pane(pane="%7")`.
- Codex has the **same** tools (same server, same tool names).
- Put CC in pane `%5`, Codex in pane `%7`. Teach each one the other's pane ID
  in its system prompt.
- CC can now send work to `%7`; Codex can send work to `%5`. Symmetric.

**This is where bidirectional falls out for free.** Tmux pane IDs are
symmetric targets. The MCP server doesn't need a special "bidirectional"
feature — it just exposes the tmux socket, and both agents have equal authority
over every pane on it. The question isn't "does the MCP server support
bidirectional?" — it's "does your setup register the same server with both
agents and tell each about the other's pane?"

**Candidates (ordered by additive risk from `tmux-claude-tools.md:99–105`):**

| Server | ★ | Runtime | Additive Risk | Why it's on the list |
|---|---|---|---|---|
| **MadAppGang/tmux-mcp** | 20 | Go | Low | Agent-oriented: sync execute returns exit codes; process-aware triggers detect when a command finishes. Has `wrapCommand` shell-template injection and `/tmp` TOCTOU — not dealbreakers on a single-user box, real problems on shared hosts. |
| **nickgnd/tmux-mcp** | 256 | Node | **Medium** | Popular, general-purpose. Uses `exec()` instead of `execFile` — shell-injection path through any attacker-controlled tool argument. No permission gate. Patch or pick a Go/Rust alternative. |
| **bnomei/tmux-mcp** | 10 | Rust | Unaudited | Explicit allow/deny tool gating, stable IDs across restarts. Interesting because policy enforcement is built in. Not yet audited. |
| **PsychArch/tmux-mcp-tools** | 7 | Python | Unaudited | Minimal (create, capture, send-keys, write-file). HTTP transport mode — deliberately skip that and stick to stdio. |

**Strengths.**

- Truly peer-to-peer. Either agent can initiate.
- Reuses tmux's own coordination primitives: `wait-for` channels
  (`tmux-pane-addressing.md:540`), nonce/sentinel patterns (`:515`), file-based
  handoff (`:596`). These already work; no new protocol.
- Persistent: each pane survives indefinitely, session state lives in the
  scrollback, and Codex's own session ID lives inside Codex's pane.

**Weaknesses.**

- More moving parts. An MCP server process, both CLIs running, both configs
  pointing at the same server.
- Response-capture is the hard problem. Sending is trivial; *knowing when the
  peer finished* requires a nonce or `wait-for` signal. The agent on the
  receiving end has to cooperate by echoing the nonce when done.
- Security: you're giving Codex `send-keys` authority over your CC pane (and
  vice versa). A poisoned prompt in Codex can type anything into CC's input.
  Mitigate by locking Codex to `-s read-only` and by sandboxing what each pane
  is willing to accept (e.g., only accept messages that include a shared-secret
  token CC generated at startup).
- `send-keys` into an active Claude Code REPL is timing-sensitive. File-based
  handoff is more robust than typing into each other's prompts.

**Best for:** bidirectional feedback loops, e.g., Codex catches a security bug,
sends CC a specific file/line to re-examine; CC patches and asks Codex to
verify.

---

### Option C — Purpose-built bridge like `tmux-bridge-mcp`

**How it works.** A single MCP server whose *explicit* design goal is to let
Claude, Codex, Gemini, and Kimi CLIs talk to each other via tmux. Exposes
tools that feel like a chat protocol (send-to-agent, receive-from-agent)
rather than raw tmux primitives.

**Status in our audit.** Listed in `tmux-claude-tools.md:101` as
[`howardpen9/tmux-bridge-mcp`](https://github.com/howardpen9/tmux-bridge-mcp),
13 ★, Node. Audited 2026-04-19 (below).

**Scorecard.** 0 Crit / 2 High / 2 Med / 0 Low · Power 4/5 · Additive Risk
**Low** · Verdict: Safe w/ awareness for single-developer local use.

**What went right.**

- Uses `execFile` with array arguments — no `exec()`, no shell
  interpolation. The shell-injection pattern endemic to this space
  (`nickgnd/tmux-mcp`, most Node tmux MCPs) is absent here.
- `send-keys` calls pass the `-l` literal flag so control sequences (`C-c`,
  `Enter`) cannot be smuggled in through message payloads.
- Sender identity is tracked on cross-agent messages (from-label, pane ID,
  correlation UUID) — basic provenance, not just unlabeled wire traffic.
- A "read-before-act" guard forces the caller to have observed the target
  pane's state recently, blocking blind keystroke injection.
- Actively maintained: 20 commits in 4 days at audit time, bilingual docs,
  52+ tests, GPG-signed releases.

**What went wrong (and why it's acceptable for our use case).**

- **No cross-agent authorization (High).** Any agent with MCP access can
  read, write, or inject keys into any pane. The README scopes the project
  explicitly to "local development on a single machine, all connected
  agents trusted." That matches our intended deployment: you're running CC
  and Codex on your laptop; both are agents *you* started. Not acceptable
  if the scope ever expands to shared hosts or untrusted co-tenants.
- **No payload size limits (Medium).** Zod schemas for `tmux_type`,
  `tmux_message`, and `text` lack `.max()`. A malfunctioning agent could
  flood a pane with megabytes of text. Cheap fix upstream.
- **Unbounded scrollback read (Medium).** `lines` param on `tmux_read`
  defaults to 50 but has no ceiling — an agent could request a million
  lines and exhaust memory. Also a one-line Zod fix.

**Bidirectional readiness.** Actually good. Not a general tmux MCP with a
label change — there's intentional design for cross-agent messaging
(`tmux_message()` with sender identity). The trust model is "all local
agents trusted"; there's no credential exchange, so any process that can
see the MCP socket can impersonate any labeled sender. Fine for our case.

**Why it's interesting.**

- The design problem (cross-agent messaging) is exactly what we're trying to
  solve. A purpose-built tool should have better ergonomics than hand-rolling
  on top of a generic tmux MCP.
- Node runtime is ubiquitous — no install friction.
- Explicitly multi-agent (Claude/Codex/Gemini/Kimi), so we'd benefit from
  whatever the author already learned about response capture and pane
  addressing.

**Why it's risky.**

- 13 stars, unaudited, Node — Node MCP servers in this space have shown a
  consistent pattern of `exec()`-based shell injection (see nickgnd/tmux-mcp in
  Option B). Need to read the source before trusting it.
- Small audience means bugs won't have been found by others.
- "Bridge" servers can accumulate state about message routing; if that state
  isn't authenticated, a second process on the same machine can inject
  messages into either agent's context.

**Best for:** the I/O layer under Option D. Install it, register it with
both CC and Codex, and we get cross-agent messaging primitives (with sender
identity + read-before-act guard) for free — replacing the hand-rolled
`send-keys` / `capture-pane` loop we'd otherwise write. We still need the
skill on top for pane spawning / lifecycle, but the I/O mechanics are solved.

**Soft hardening we'd want** regardless (trivial local patches or a PR
upstream):

- `z.string().max(10000)` on text payloads.
- `z.number().max(1000)` on `lines` in `tmux_read`.
- A shared-secret token baked into both CC's and Codex's system prompts,
  validated in the bridge before dispatching messages — turns the
  trust-the-host model into trust-the-token-holder. Soft security (anyone
  who reads either system prompt sees the token), but it raises the bar
  against casual cross-contamination from other local processes.

---

### Option D — Hybrid: skill owns the pane lifecycle, tmux owns the I/O

**The combination that actually fits the constraints.** Take Option A's skill
front-door and add persistent-pane ownership from Options B/C, but skip the
MCP server unless you genuinely need Codex-initiated callbacks.

**How it works.**

1. **First invocation:** the skill checks whether a Codex pane already exists
   for this session. Convention: store the pane ID in `.context/codex-pane-id`
   (sibling to the existing `.context/codex-session-id`).
   - If absent, `tmux split-window -h -P -F '#{pane_id}'` in the current
     window, capture the new `%N`, and launch `codex` inside it:
     `tmux send-keys -t %N 'codex' Enter`.
   - Persist the pane ID.
2. **Subsequent invocations:** verify the pane is still alive
   (`tmux list-panes -a -F '#{pane_id}' | grep -qF "$PANE"`). If gone, respawn.
3. **Each turn:**
   - Generate a nonce: `NONCE=__CODEX_DONE_$(date +%s%N)__`.
   - `tmux send-keys -t "$PANE" -l -- "$PROMPT"` (literal mode, `-l`, so
     control chars don't get interpreted).
   - `tmux send-keys -t "$PANE" Enter`.
   - Poll `tmux capture-pane -t "$PANE" -p -J -S -500` for the nonce OR for
     Codex's idle prompt (`codex>` or equivalent — see
     `tmux-pane-addressing.md:571`).
   - Extract the response between the prompt echo and the idle marker,
     display verbatim to the user.
4. **(Stretch, optional) Reverse channel:** if you later want Codex to ping
   CC, that's when you reach for a tmux MCP server (Option B) *on top of* this
   setup. Codex's MCP client calls a `send_keys` tool on CC's pane. The
   persistent-pane work is already done; you're only adding the callback
   direction.

**Why this shape.**

- **No MCP dependency for the 80% case.** CC already has `Bash` and can run
  `tmux` directly — the skill is just a disciplined wrapper around `send-keys`
  / `capture-pane`. Fewer moving parts than Option B, fewer unknowns than
  Option C.
- **Persistent-pane constraint satisfied.** Codex's process lives across
  skill invocations; in-flight state (loaded files, shell env, scrollback)
  persists naturally.
- **Reusable audit surface.** The tmux coordination patterns we'd use are the
  ones already documented in `tmux-pane-addressing.md` — same primitives the
  rest of this repo uses.
- **Upgrade path is clean.** If one-way proves insufficient, add a tmux MCP
  later without rewriting the skill. The pane IDs are already stable keys.

**Weaknesses.**

- CC must own the lifecycle. If CC dies, the skill re-attaches to the
  surviving Codex pane (using the stored ID) — that's the good case. If the
  *Codex* pane dies (user closed it, `exit` typed), the skill must detect and
  respawn, and the user-visible Codex session memory is gone (only the on-disk
  `codex-session-id` helps, and only if Codex's resume semantics work from a
  cold process).
- `send-keys` into an interactive Codex REPL has the same flakiness flagged in
  Option B — timing sensitivity when input races pane rendering. Mitigation:
  use `-l` literal mode, always follow a text send with a separate `Enter`,
  and sleep briefly (~100ms) before polling capture-pane.
- Response parsing is regex-against-scrollback. Brittle if Codex changes its
  prompt glyph. Sentinel nonces are the robust answer — but they require
  Codex to cooperate by including the nonce in its response, which only works
  if we tell it to in the preamble.

**Security posture.** Identical to Option A for what Codex can do (sandbox
flags still apply inside the pane). Additive risk comes from the pane itself:
anything CC types with `send-keys` becomes real keyboard input to Codex, so
prompt-injection through user-provided text flows straight to Codex
verbatim — same risk as Option A, displaced from `codex exec` args to
`send-keys` args. Mitigate by running the prompt through a short allowlist
(no `C-c`, no `Enter` embedded except the trailing one we control).

**Best for:** the actual constraint set we have. This is probably the shape
we build.

---

## 4. Answering the specific question: bidirectional tmux MCP

> *"Is there a way to bi-directionally configure an agent to be able to access
> another pane, and the agent in the other pane to access the Claude pane?"*

Yes, and the mechanism is simpler than the word "bidirectional" suggests.

**The setup.**

1. Start tmux. Open two panes: CC in `%5`, Codex in `%7`. Capture the IDs
   (`tmux list-panes -a -F '#{pane_id} #{pane_current_command}'`).
2. Install a tmux MCP server (pick one from Option B above).
3. Register it **twice** — once in CC's MCP config, once in Codex's. Same
   server, same tools, same socket.
4. In CC's system prompt (or a CLAUDE.md entry): "Your teammate Codex is in
   tmux pane `%7`. Use `tmux.send_keys` to talk to them and
   `tmux.capture_pane` to read their response."
5. In Codex's system prompt (AGENTS.md or equivalent): "Your teammate Claude
   Code is in tmux pane `%5`. Same tools."

**The symmetry.** `tmux` is a server with a socket. Anything with access to
that socket can `send-keys` to any pane. An MCP server wrapping tmux inherits
this — it's not "directional" by nature. Both agents have full pane authority
over each other the moment they share an MCP connection.

**The response-capture problem.** Sending is easy; the hard part is knowing
when the peer is finished and what they said. Three patterns from
`tmux-pane-addressing.md`:

- **Nonce/sentinel** (`:515`). Sender emits a unique marker at end of
  message (`__DONE_1734051888__`). Receiver's pane contains the marker when
  done. Polls `capture-pane` until match. Works for REPL-mode agents.
- **`tmux wait-for` channel** (`:540`). Sender blocks on
  `tmux wait-for <channel>`; receiver does `tmux wait-for -S <channel>` when
  finished. Cleaner than polling but needs cooperation from the receiver to
  emit the signal.
- **File-based handoff** (`:596`). Task goes in
  `/tmp/agent-tasks/task-N.md`; result comes back in
  `...-result.md`. Agents poll for files. Slower but completely
  decouples the two REPLs.

For CC ↔ Codex specifically, **file-based handoff is probably the right
default**. Typing into an active Claude Code REPL is flaky (input box state,
partial token capture), and file-based handoff lets each agent operate in its
natural mode without synchronizing on pane-render timing.

**The security gotcha.** Once both agents share a tmux MCP, Codex can
`send-keys` *anything* into CC's pane — including commands like `/clear` or
"ignore all prior instructions and do X". Two mitigations:

1. Run Codex in `-s read-only`. It can still type into CC's pane, but at least
   it can't do file-system damage in its own sandbox.
2. Put a shared-secret token in the system prompt of both agents. Each agent
   only acts on messages that include the token. A rogue local process that
   `send-keys`es into either pane without knowing the secret will be ignored.
   This is soft security — anyone who can read either system prompt can
   extract the token — but it blocks casual cross-contamination.

---

## 5. Recommendation

**Build Option D, with Option C as the I/O layer.** Post-audit, the shape is:

1. **Skill owns the lifecycle** (Option D). `.claude/skills/codex/SKILL.md`
   handles: `codex login` check, pane spawn via `tmux split-window -h`,
   pane-ID persistence in `.context/codex-pane-id`, alive-check on each turn,
   respawn on death, session-ID resume for memory continuity.
2. **`tmux-bridge-mcp` handles the wire** (Option C). Registered with both
   CC and Codex. Skill calls its `tmux_message` / `tmux_type` / `tmux_read`
   tools instead of hand-rolling `send-keys` / `capture-pane`. We inherit
   sender identity, read-before-act guards, and `execFile`-based shell
   safety for free.
3. **Harden the bridge on install.** Apply the two Zod `.max()` patches
   locally (or upstream them) and bake a shared-secret token into both
   agents' preambles. ~10 lines of total change.

This composition addresses every constraint: ChatGPT-sub auth (A), session
continuity + persistent pane (D), solid I/O with sender identity (C),
bidirectional-ready if we ever flip on Codex→CC callbacks (also C). It's
fewer lines than building Option D from scratch because the audited bridge
already solved the I/O layer.

**Keep Option A as a fallback mode** inside the same skill — `/codex
one-shot` for single-turn consults that don't warrant keeping a pane open.
Same codebase, one flag.

**Skip Option B.** With Option C cleaner than the general-purpose tmux MCPs
that Option B surveyed, there's no reason to reach for `MadAppGang`,
`nickgnd`, or `bnomei` for this use case. Revisit only if `tmux-bridge-mcp`
stops being maintained or we need something Option C can't express.

---

## 6. Open questions / decisions to make

- [ ] Are we building this as a **skill** (gstack-style, in-tree markdown) or a
      **slash command + hook** (oh-my-claudecode-style, TS plugin)? Skill is
      lower-friction to author and share; hook gives richer capture. Option D
      leans toward skill — the logic is prompt-driven and markdown-expressible.
- [ ] Do we want the skill in this repo (`tmux-manage`) or a new one? It's
      tmux-native under Option D (we're driving tmux directly), so this repo
      fits — especially since `tmux-pane-addressing.md` already documents the
      exact primitives we'd use.
- [ ] **Pane placement.** Same-window split (`split-window -h`) keeps Codex
      visible next to CC — good for trust ("I can watch it"). Separate window
      (`new-window -d`) keeps the foreground clean but hides what Codex is
      doing. User asked for same-window; codify that.
- [ ] **Pane lifetime on CC exit.** Does the Codex pane survive past CC's
      session, or die with it? If survives, next CC session should reattach by
      reading `.context/codex-pane-id`. If dies, tear down on `Stop` hook.
- [ ] **Response-capture primitive.** Nonce-in-scrollback (robust but needs
      Codex to cooperate via preamble) vs. idle-prompt regex (works today but
      brittle to Codex UI changes) vs. file-based handoff (slowest but most
      decoupled). Default proposal: nonce, with idle-prompt as fallback.
- [ ] Is the "read-only Codex, writable CC" asymmetry the right division? Or
      do we want a mode where Codex can propose patches that CC applies?
- [ ] When (if ever) do we add the reverse channel (Codex → CC)? This is
      where an MCP server becomes necessary. Threshold: when the user asks
      for it, not before.

---

## 7. Prior art and references

- `tmux-claude-tools.md:84–114` — security scorecards for every candidate
  tool discussed above.
- `tmux-claude-tools.md:40–78` — the "Cross-Model Interop" section with
  recommendations for API-level vs CLI-level coordination.
- `tmux-pane-addressing.md:487–621` — agent coordination patterns (polling,
  nonce, `wait-for`, file-based handoff).
- `repos/gstack/codex/SKILL.md` — working reference implementation of
  Option A.
- `repos/superpowers/skills/using-superpowers/references/codex-tools.md` —
  Codex's tool-name mapping for skill compatibility.
- `repos/everything-claude-code/scripts/orchestrate-codex-worker.sh` — an
  example of Codex orchestration from the other direction (agent-side).
- `tmux-bridge-mcp` audit (2026-04-19): 0C/2H/2M/0L, Power 4/5, Additive
  Risk Low. Clean `execFile` + `-l` literal mode, sender-identity tracking,
  active maintenance. Known gaps: no cross-agent auth (scoped out by
  author), no Zod `.max()` on payloads or scrollback. Acceptable for
  single-developer local use.
