---
name: codex
description: |
  OpenAI Codex CLI teammate running in a persistent sibling tmux pane. Hands
  prompts to Codex and captures responses verbatim, preserving session memory
  across turns. Uses ChatGPT subscription (via `codex login`), not OpenAI API.
  Use when the user asks to "ask codex", "consult codex", "get a second
  opinion from codex", "codex review", or "show me what codex thinks".
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# /codex — Persistent Codex teammate in a sibling pane

Keeps a long-running `codex` CLI alive in a tmux pane next to Claude Code.
Each invocation routes a prompt to that pane and captures the response by
polling the pane's scrollback for a pair of unique sentinel tokens. Pane ID
and Codex session ID persist in `.context/` so they survive across skill
invocations and CC restarts.

**Phase 1 transport:** raw `tmux send-keys` + `capture-pane`. No MCP server.
**Phase 5 transport:** `tmux-bridge-mcp` tool calls. Swap-in only; the rest of
the skill is unchanged.

---

## Step 0: Preflight

Run this block first. Stop and tell the user what's missing if any check fails.

```bash
set -u

# Codex CLI must be on PATH
CODEX_BIN=$(command -v codex 2>/dev/null || true)
if [ -z "$CODEX_BIN" ]; then
  echo "MISSING: codex-binary"
  echo "Install: npm install -g @openai/codex"
  echo "Auth: codex login (uses your ChatGPT subscription)"
  exit 0
fi

# Must be inside tmux — the whole skill depends on panes
if [ -z "${TMUX:-}" ]; then
  echo "MISSING: tmux-session"
  echo "This skill requires Claude Code to be running inside a tmux pane."
  exit 0
fi

# State dir (pane ID, session ID, prompt/response scratch)
mkdir -p .context

# Add to .gitignore if not already there — .context/ holds scratch,
# session IDs, and other per-checkout state that should never be committed
if [ -f .gitignore ] && ! grep -qE '^\.context/?$' .gitignore; then
  echo "" >> .gitignore
  echo "# Codex skill state (pane ID, session ID, transient prompts)" >> .gitignore
  echo ".context/" >> .gitignore
fi

echo "OK: codex=$CODEX_BIN tmux=$TMUX"
```

If output starts with `MISSING:`, stop and relay the message to the user.
Do not proceed to Step 1.

---

## Step 1: Attach to or spawn the Codex pane

The Codex pane is the long-running resource. We cache its pane ID in
`.context/codex-pane-id`. On each invocation:

1. If the cache file exists, verify the pane is still alive.
2. If alive, reuse it (this is the common path).
3. If dead or missing, spawn a new sibling pane running `codex`.

```bash
set -u
PANE_FILE=".context/codex-pane-id"
CC_PANE="$TMUX_PANE"   # the pane CC is running in — needed for split-window target

CODEX_PANE=""

if [ -f "$PANE_FILE" ]; then
  SAVED=$(cat "$PANE_FILE")
  if tmux list-panes -a -F '#{pane_id}' | grep -qFx "$SAVED"; then
    CODEX_PANE="$SAVED"
    echo "REUSING: $CODEX_PANE"
  else
    echo "STALE: $SAVED (pane gone — respawning)"
    rm -f "$PANE_FILE"
  fi
fi

if [ -z "$CODEX_PANE" ]; then
  # Split the CC pane horizontally. -d keeps CC focused. -P prints the new
  # pane ID. -F formats it. Launches `codex` as the pane's initial command.
  CODEX_PANE=$(tmux split-window -h -d -P -F '#{pane_id}' -t "$CC_PANE" 'codex')
  echo "$CODEX_PANE" > "$PANE_FILE"
  echo "SPAWNED: $CODEX_PANE"
  # Codex takes a few seconds to boot its TUI. Give it time before sending.
  sleep 4
fi

echo "CODEX_PANE=$CODEX_PANE"
```

Remember whether this turn used `REUSING` or `SPAWNED` — include it in the
final status line so the user knows whether Codex is fresh or continuing.

---

## Step 2: Gather the user's prompt

For Phase 1 the skill supports one mode: **consult**. Everything after
`/codex` is the prompt. If the user said just `/codex` with no args, ask
them what they want to ask Codex.

If the prompt is empty, use AskUserQuestion:

```
What would you like to ask Codex?
A) Review the current diff against the base branch
B) Ask a free-form question (I'll provide the prompt)
C) Cancel
```

For A, construct the prompt: `"Review the changes on this branch against the
base branch. Run git diff to see them. Flag bugs, edge cases, and anything
that looks wrong."`

For B, ask what the question is.

---

## Step 3: Send the prompt + capture the response

The hard part. Codex's pane is an interactive TUI — output interleaves the
user's typed prompt, Codex's thinking, tool-use display, the agent message,
and the idle prompt glyph. We can't parse that reliably. Two sentinels
bracket the response so extraction is unambiguous:

- **START sentinel** — embedded in the prompt. Codex will echo it when it
  reads our message.
- **END sentinel** — we ask Codex to emit it on its own line at the end of
  its response.

Both sentinels contain a UUID so old ones in scrollback don't collide.

```bash
set -u
UUID=$(uuidgen | tr -d '\n' | tr '[:upper:]' '[:lower:]')
START="<<<CX_START:${UUID}>>>"
END="<<<CX_END:${UUID}>>>"

# The prompt CC types into the Codex pane. PROMPT_TEXT is the user's
# actual question (set by Step 2).
WRAPPED=$(cat <<EOF
${START}
${PROMPT_TEXT}

When your response is complete, output this exact line (and nothing after it):
${END}
EOF
)

# Literal-mode send — control chars and escape sequences in the prompt
# cannot be interpreted as tmux keybindings.
# We send the whole text as one atomic send-keys -l call, then a separate
# Enter to submit.
tmux send-keys -t "$CODEX_PANE" -l -- "$WRAPPED"
tmux send-keys -t "$CODEX_PANE" Enter

echo "SENT: UUID=$UUID"
```

Then poll the pane for the END sentinel. Ceiling: 5 minutes. Long enough
for complex prompts; short enough to fail fast on a wedged Codex.

```bash
set -u
DEADLINE=$(( $(date +%s) + 300 ))

while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  if tmux capture-pane -t "$CODEX_PANE" -p -J -S -5000 2>/dev/null | grep -qF "$END"; then
    break
  fi
  sleep 2
done

# Capture the full scrollback after the sentinel appeared
CAPTURE=$(tmux capture-pane -t "$CODEX_PANE" -p -J -S -5000)

if ! echo "$CAPTURE" | grep -qF "$END"; then
  echo "TIMEOUT: no END sentinel after 5min"
  exit 0
fi

# Extract everything between START and END — both must be on their own lines.
# awk picks lines strictly between the first match of each sentinel.
RESPONSE=$(echo "$CAPTURE" | awk -v s="$START" -v e="$END" '
  index($0, s) { in_block=1; next }
  index($0, e) { if (in_block) exit }
  in_block { print }
')

echo "RESPONSE_LENGTH=${#RESPONSE}"
# Print the response so CC can include it in its turn output
printf '%s\n' "$RESPONSE"
```

---

## Step 4: Persist the Codex session ID (for cold-start resume)

Codex prints a session ID when a new thread starts. Capture it from the
pane scrollback after the first exchange and cache it in
`.context/codex-session-id`. On a future run, if the pane is dead, we can
`codex exec resume <id>` to rehydrate memory even though the pane is new.

```bash
SESSION_FILE=".context/codex-session-id"
if [ ! -f "$SESSION_FILE" ]; then
  # Codex prints "session: <uuid>" or similar in its TUI header. Exact
  # format depends on Codex version — read scrollback from the top.
  SID=$(tmux capture-pane -t "$CODEX_PANE" -p -J -S -2000 \
        | grep -oE 'session[: ]+[a-f0-9-]{16,}' \
        | head -1 | grep -oE '[a-f0-9-]{16,}' || true)
  if [ -n "$SID" ]; then
    echo "$SID" > "$SESSION_FILE"
    echo "SESSION_CAPTURED: $SID"
  fi
fi
```

Do not fail the skill if the session ID can't be parsed — that's a
nice-to-have, not a must-have for Phase 1.

---

## Step 5: Present the response to the user

Display the captured `$RESPONSE` verbatim, wrapped in a clearly-delimited
block. Do not summarize or editorialize inside the block.

```
CODEX SAYS:
════════════════════════════════════════════════════════════
<RESPONSE>
════════════════════════════════════════════════════════════
Pane: <CODEX_PANE> (<REUSING|SPAWNED>)
Session: <SID or "uncaptured">
```

After the block, CC may add its own synthesis as a separate paragraph —
e.g. "I agree with Codex on X but disagree on Y because Z." Never edit
Codex's words inside the block.

---

## Error handling

- **`MISSING: codex-binary`** — Codex not installed. Tell user to run
  `npm install -g @openai/codex` and `codex login`.
- **`MISSING: tmux-session`** — CC is not running in tmux. Tell user the
  skill requires tmux.
- **`STALE: <pane>`** — the saved pane is dead. The skill already handled
  it by respawning; just note "Codex pane was gone; started fresh."
- **`TIMEOUT: no END sentinel`** — Codex didn't finish in 5 minutes, or
  didn't echo the sentinel. Possible causes: Codex is wedged,
  non-cooperative with the sentinel instruction, or waiting for
  permission approval. Tell the user: "Codex didn't respond within 5
  minutes. Check pane <CODEX_PANE> for its current state."
- **Codex auth error** — if Codex prints "auth required" in its pane,
  surface that and tell user to run `codex login`.

---

## Important invariants

1. **Never modify `.context/codex-pane-id` or `codex-session-id` outside
   this skill.** Those are the single source of truth for lifecycle state.
2. **Never kill the Codex pane from the skill.** Only the user (via `q` or
   `exit` in Codex, or tmux pane-close) should close it. Respawn handles
   the case where it's already gone.
3. **Always use `send-keys -l --`** when typing the prompt. The `-l`
   (literal) flag prevents control sequences in user input from being
   interpreted as tmux keybindings. The `--` prevents a leading `-` in
   the prompt from being parsed as a flag.
4. **5-minute ceiling** on the capture loop. Never poll forever; a wedged
   Codex should fail the skill cleanly, not hang CC's turn.

---

## What this skill does NOT do (yet)

- Review / challenge modes (Phase 2 — add as alternate prompts in Step 2)
- Codex-initiated callbacks to CC (Phase 5 — needs `tmux-bridge-mcp`)
- One-shot mode via `codex exec` (Phase 2 — add as `--one-shot` flag)
- Cross-model agreement analysis with CC's `/review` (Phase 2)
- Automatic pane-close on CC shutdown (pane persists across CC restarts
  by design; user closes it manually when done)
