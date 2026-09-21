#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")" || exit
source common_utils.sh

if [[ $(get_tmux_option "@session-manager-disable-fzf-warning" "off") != "on" && ! $(command -v fzf) ]]; then
	tmux display-message "Warning: fzf was not found in PATH. Recommended for tmux-session-manager. If that is intentional, you can disable this message."
	exit
fi

declare key
declare bindings

# Save
bindings=$(get_tmux_option "@session-manager-save-key" "C-s")
for key in $bindings; do
	tmux bind-key "$key" run-shell "$(pwd)/save_session.sh"
done
bindings=$(get_tmux_option "@session-manager-save-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "$(pwd)/save_session.sh"
done

# Save all (every live session in one keystroke)
bindings=$(get_tmux_option "@session-manager-save-all-key" "M-s")
for key in $bindings; do
	tmux bind-key "$key" run-shell "$(pwd)/save_session.sh --all"
done
bindings=$(get_tmux_option "@session-manager-save-all-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "$(pwd)/save_session.sh --all"
done

# Restore
bindings=$(get_tmux_option "@session-manager-restore-key" "C-r")
for key in $bindings; do
	tmux bind-key "$key" run-shell "tmux display-popup -E '$(pwd)/restore_session.sh'"
done
bindings=$(get_tmux_option "@session-manager-restore-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "tmux display-popup -E '$(pwd)/restore_session.sh'"
done

# Archive
bindings=$(get_tmux_option "@session-manager-archive-key" "")
for key in $bindings; do
	tmux bind-key "$key" run-shell "tmux display-popup -E '$(pwd)/archive_session.sh'"
done
bindings=$(get_tmux_option "@session-manager-archive-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "tmux display-popup -E '$(pwd)/archive_session.sh'"
done

# Unarchive
bindings=$(get_tmux_option "@session-manager-unarchive-key" "")
for key in $bindings; do
	tmux bind-key "$key" run-shell "tmux display-popup -E '$(pwd)/restore_session.sh --archived'"
done
bindings=$(get_tmux_option "@session-manager-unarchive-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "tmux display-popup -E '$(pwd)/restore_session.sh --archived'"
done

# Delete
bindings=$(get_tmux_option "@session-manager-delete-key" "")
for key in $bindings; do
	tmux bind-key "$key" run-shell "tmux display-popup -E '$(pwd)/delete_session.sh'"
done
bindings=$(get_tmux_option "@session-manager-delete-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "tmux display-popup -E '$(pwd)/delete_session.sh'"
done

# View (read-only browse with live preview)
bindings=$(get_tmux_option "@session-manager-view-key" "")
for key in $bindings; do
	tmux bind-key "$key" run-shell "tmux display-popup -E '$(pwd)/view_session.sh'"
done
bindings=$(get_tmux_option "@session-manager-view-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "tmux display-popup -E '$(pwd)/view_session.sh'"
done

# Rename
bindings=$(get_tmux_option "@session-manager-rename-key" "")
for key in $bindings; do
	tmux bind-key "$key" run-shell "tmux display-popup -E '$(pwd)/rename_session.sh'"
done
bindings=$(get_tmux_option "@session-manager-rename-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "tmux display-popup -E '$(pwd)/rename_session.sh'"
done

# Move Window (to running or saved session)
bindings=$(get_tmux_option "@session-manager-move-window-key" "C-w")
for key in $bindings; do
	tmux bind-key "$key" run-shell "tmux display-popup -E '$(pwd)/move_window.sh'"
done
bindings=$(get_tmux_option "@session-manager-move-window-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "tmux display-popup -E '$(pwd)/move_window.sh'"
done

# Load Window (from saved session, move semantics)
bindings=$(get_tmux_option "@session-manager-load-window-key" "C-y")
for key in $bindings; do
	tmux bind-key "$key" run-shell "tmux display-popup -E '$(pwd)/load_window.sh'"
done
bindings=$(get_tmux_option "@session-manager-load-window-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "tmux display-popup -E '$(pwd)/load_window.sh'"
done

# Load Window Copy (from saved session, copy semantics)
bindings=$(get_tmux_option "@session-manager-load-window-copy-key" "")
for key in $bindings; do
	tmux bind-key "$key" run-shell "tmux display-popup -E '$(pwd)/load_window.sh --copy'"
done
bindings=$(get_tmux_option "@session-manager-load-window-copy-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "tmux display-popup -E '$(pwd)/load_window.sh --copy'"
done

# Scratchpad (persistent per-window / per-pane notes in $EDITOR)
# C-q inside the popup detaches it; the editor keeps running for instant
# re-open. Unbound keys in the "scratchpad" table fall through to the pane.
tmux bind-key -T scratchpad C-q detach-client
bindings=$(get_tmux_option "@session-manager-scratchpad-key" "a")
for key in $bindings; do
	tmux bind-key "$key" run-shell "$(pwd)/scratchpad.sh window"
done
bindings=$(get_tmux_option "@session-manager-scratchpad-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "$(pwd)/scratchpad.sh window"
done

# Scratchpad, pane scope (uppercase variant of the window key)
bindings=$(get_tmux_option "@session-manager-scratchpad-pane-key" "A")
for key in $bindings; do
	tmux bind-key "$key" run-shell "$(pwd)/scratchpad.sh pane"
done
bindings=$(get_tmux_option "@session-manager-scratchpad-pane-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "$(pwd)/scratchpad.sh pane"
done

# Pull Window (from any session - running or saved)
bindings=$(get_tmux_option "@session-manager-pull-window-key" "C-p")
for key in $bindings; do
	tmux bind-key "$key" run-shell "tmux display-popup -E '$(pwd)/pull_window.sh'"
done
bindings=$(get_tmux_option "@session-manager-pull-window-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" run-shell "tmux display-popup -E '$(pwd)/pull_window.sh'"
done

# Inherit current pane's cwd on split / new-window.
# Off by default: each option is unset, so nothing is rebound until you name
# a key. tmux's own splits open in the server's start dir (its global
# default-path was removed in 1.9); adding -c "#{pane_current_path}" keeps the
# cwd. Point an option at tmux's stock key (" / % / c) to override the
# built-in, or at your own split key if you've remapped it.

# Split vertical (top/bottom)
bindings=$(get_tmux_option "@session-manager-split-v-key" "")
for key in $bindings; do
	tmux bind-key "$key" split-window -v -c "#{pane_current_path}"
done
bindings=$(get_tmux_option "@session-manager-split-v-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" split-window -v -c "#{pane_current_path}"
done

# Split horizontal (left/right)
bindings=$(get_tmux_option "@session-manager-split-h-key" "")
for key in $bindings; do
	tmux bind-key "$key" split-window -h -c "#{pane_current_path}"
done
bindings=$(get_tmux_option "@session-manager-split-h-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" split-window -h -c "#{pane_current_path}"
done

# New window
bindings=$(get_tmux_option "@session-manager-new-window-key" "")
for key in $bindings; do
	tmux bind-key "$key" new-window -c "#{pane_current_path}"
done
bindings=$(get_tmux_option "@session-manager-new-window-key-root" "")
for key in $bindings; do
	tmux bind-key -n "$key" new-window -c "#{pane_current_path}"
done
