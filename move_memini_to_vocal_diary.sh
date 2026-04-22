#!/usr/bin/env bash
# One-off: consolidate four Memini/Mem-related tmux windows into a new
# "Vocal Diary" session, then rename them so Memini/Mem becomes VC.
#
# Window IDs were captured BEFORE any moves — they are stable across
# session membership changes and renumbering, so this script is robust
# regardless of what happens to window indices mid-run.
#
#   @20  background:2  memini-shutdown                                     -> VC-shutdown
#   @4   main:2        memini - automated testing                          -> VC - automated testing
#   @7   main:5        memini-modernization                                -> VC-modernization
#   @9   main:7        graphical-dbase look at Mem library (see messages)  -> graphical-dbase look at VC library (see messages)

set -euo pipefail

TMUX_BIN=/opt/homebrew/bin/tmux
# Note: variable is TMUX_BIN (not TMUX) on purpose — tmux reads $TMUX from
# the environment to locate its server socket, so reusing that name can
# cause "error connecting to <path> (Socket operation on non-socket)".
SESSION="Vocal Diary"

# 1) Create the target session if it doesn't already exist.
#    `=NAME` forces exact-match so we don't collide with a prefix.
if ! "$TMUX_BIN" has-session -t "=$SESSION" 2>/dev/null; then
  "$TMUX_BIN" new-session -d -s "$SESSION" -n "__placeholder"
  created_placeholder=1
else
  created_placeholder=0
fi

# 2) Move each window by its stable ID. Trailing colon on the target means
#    "append to this session's window list" — tmux picks the next index.
"$TMUX_BIN" move-window -s '@20' -t "$SESSION":
"$TMUX_BIN" move-window -s '@4'  -t "$SESSION":
"$TMUX_BIN" move-window -s '@7'  -t "$SESSION":
"$TMUX_BIN" move-window -s '@9'  -t "$SESSION":

# 3) Drop the placeholder only if this script created it — never touch a
#    pre-existing session's first window.
if [[ $created_placeholder -eq 1 ]]; then
  "$TMUX_BIN" kill-window -t "$SESSION:__placeholder"
fi

# 4) Rename by window ID — explicit mapping, no regex surprises.
"$TMUX_BIN" rename-window -t '@20' 'VC-shutdown'
"$TMUX_BIN" rename-window -t '@4'  'VC - automated testing'
"$TMUX_BIN" rename-window -t '@7'  'VC-modernization'
"$TMUX_BIN" rename-window -t '@9'  'graphical-dbase look at VC library (see messages)'

# 5) Report final state.
echo "Final state of '$SESSION':"
"$TMUX_BIN" list-windows -t "=$SESSION" -F '  #{window_index}: #{window_name}  (#{window_id})'
