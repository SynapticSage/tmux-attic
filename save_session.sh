#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")" || exit
source common_utils.sh

# Separator for tmux format strings
declare S=$SEPARATOR

# Tmux format string for windows
WINDOW_FORMAT="window$S#{window_index}$S#{window_name}$S#{window_layout}$S#{window_active}"

# Tmux format string for panes
PANE_FORMAT="pane$S#{pane_index}$S#{pane_current_path}$S#{pane_active}$S#{window_index}$S#{pane_pid}"

# Save one named session to its own timestamped file, refreshing the
# `<name>_last` symlink only when the content actually changed. Session
# identity is a parameter (not the ambient "current session"), so the
# same code path serves `save one` and the `--all` loop below — and is
# the seam ROADMAP §2 (auto-save on detach) will hook, since a detached
# session is never the current one.
save_one() {
	local session_name="$1"
	local new_file="${SAVE_DIR}/${session_name}_$(date +"%Y-%m-%dT%H:%M:%S")"
	local last_file="${SAVE_DIR}/${session_name}_last"

	# Saving a session whose only store is archived un-archives it, so the
	# fresh save reappears in the normal restore picker.
	if [[ -e "${last_file}_archived" ]]; then
		mv "${last_file}_archived" "$last_file"
	fi

	# Honest per-session cwd: the active pane's path. (The former global
	# `tmux -c pwd` returned the server's cwd — one value shared by every
	# session, which stamps every save in an --all run identically.)
	local session_cwd
	session_cwd="$(tmux display-message -t "$session_name" -p "#{pane_current_path}")"

	echo "version$S$VERSION" > "$new_file"
	echo "$session_cwd" >> "$new_file"
	tmux list-windows -t "$session_name" -F "$WINDOW_FORMAT" >> "$new_file"
	tmux list-panes -s -t "$session_name" -F "$PANE_FORMAT" | while IFS="$SEPARATOR" read -r line; do
		pane_pid=$(cut -f6 <<< "$line")
		# Immediate children of the pane's shell. Using awk for exact
		# PPID match avoids the false positives that `grep "^$pid"`
		# picked up (e.g. PPID 1234 matching pid=123).
		pids=$(ps -ao "ppid,pid" | awk -v p="$pane_pid" 'NR>1 && $1==p {print $2}')

		command=""
		for pid in $pids; do
			proc_cmd=""
			# NixOS' nvim wrapper hides its real args behind extra argv
			# entries that need to be stripped via /proc/$pid/cmdline.
			# Keep this special case Linux-only; every other platform
			# (including macOS, which has no /proc) falls through to the
			# portable `ps -p` path below.
			if [[ -r "/proc/$pid/cmdline" \
				&& "$(grep ^ID= /etc/os-release 2>/dev/null | cut -d'=' -f2)" == "nixos" \
				&& "$(get_tmux_option "@session-manager-diable-nixos-nvim-check" "off")" != "on" \
				&& "$(cut -d' ' -f1 <<< "$(ps -p $pid -o cmd)" | tail +2 | xargs basename)" == "nvim" ]]; then
				proc_cmd="nvim"
				while read -r arg; do
					if [ -n "$arg" ]; then
						proc_cmd+=" '$arg'"
					fi
				done <<< "$(xargs -0L1 < /proc/$pid/cmdline | tail +8)"
			else
				# Portable: `ps -p <pid> -o args=` prints the full command
				# line (program + args, space-joined) on both macOS BSD
				# and Linux. Arg boundaries are lossy for args with
				# embedded spaces — a known limitation, acceptable because
				# shell re-parses on restore and typical agent invocations
				# don't use space-bearing args.
				proc_cmd=$(ps -p "$pid" -o args= 2>/dev/null | sed 's/^ *//; s/ *$//')
			fi
			[[ -n "$proc_cmd" ]] && command="${command:+$command; }$proc_cmd"
		done

		awk -v command="$command" \
			'BEGIN {FS=OFS="\t"} {$6=command; print}'\
			<<< "$line" >> "$new_file"
	done
	if ! cmp -s "$new_file" "$last_file"; then
		ln -sf "$new_file" "$last_file"
	else
		rm "$new_file"
	fi
}

if [[ "${1:-}" == "--all" ]]; then
	start_spinner "Saving all sessions"
	declare -i count=0
	while IFS= read -r session_name; do
		[[ -z "$session_name" ]] && continue
		save_one "$session_name"
		count+=1
	done < <(tmux list-sessions -F "#{session_name}")
	stop_spinner "Saved $count session(s)"
else
	start_spinner "Saving current session"
	save_one "$CURRENT_SESSION"
	stop_spinner "Session saved"
fi
