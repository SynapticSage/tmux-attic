# tmux-manage — CLAUDE.md

Repository-level notes for Claude Code. This file documents the project's
concrete conventions and the active design work.

---

## What this repo is

A collection of bash scripts and tmux hooks that augment tmux for running
many concurrent Claude Code sessions. Two overlapping layers:

- **Session manager** (`save_session.sh`, `restore_session.sh`,
  `move_window.sh`, `load_window.sh`, `pull_window.sh`,
  `delete_session.sh`) — persist, restore, and shuffle whole tmux
  sessions and individual windows between them.
- **Recon wrappers** (`recon_cycle.sh`, `recon_ignore_toggle.sh`,
  `recon_ignore_picker.sh`) — thin UX layer over the external `recon`
  CLI (Rust, in `~/.cargo/bin/recon`) that inventories live Claude
  sessions across the tmux server.

Top-level entry point for tmux is `session_manager.tmux`, which binds
keys by reading `@session-manager-*` user options. Key reference:
`KEYBINDINGS.md`.

---

## External tools this repo assumes

| Tool | Purpose | How it's used |
|------|---------|---------------|
| `recon` (cargo bin) | JSON inventory of Claude sessions | `recon json` emits all sessions with `status` ∈ {`Idle`, `Working`, `New`, …}, `pane_target`, `token_ratio`, etc. Consumed by `recon_cycle.sh`. |
| `tmux-agent-indicator` (TPM plugin) | Per-pane Claude Code state via hooks | `~/.claude/settings.json` hooks call `agent-state.sh` on `UserPromptSubmit` / `PermissionRequest` / `Stop`. State lives in tmux global env vars `TMUX_AGENT_PANE_<pane_id>_STATE`. |
| `fzf` | Interactive pickers | Required by restore/delete/move/load popups and `recon_ignore_picker.sh`. |

---

## Conventions

- All scripts are `set -euo pipefail` (except the `delete_session.sh`
  exception noted in commit `3b16f92` — strict mode crashed popups in
  some cases; verify before re-adding).
- Scripts locate tmux via an absolute path (`TMUX_BIN=/opt/homebrew/bin/tmux`)
  because some are invoked from Claude hooks where `PATH` is minimal.
- User options: pane/window/session scope uses the `@recon-ignore`
  namespace; session-manager configuration uses `@session-manager-*`.
  Inheritance follows tmux's pane → window → session → global chain.
- New features should be keyboard-reachable via a documented binding in
  `KEYBINDINGS.md` and, where applicable, configurable via a
  `@<feature>-*-key` user option, matching the existing pattern.

---

## Per-window agent status badges → split to its own repo

Extracted to
[SynapticSage/tmux-agent-tracker](https://github.com/SynapticSage/tmux-agent-tracker)
(see that repo's `CLAUDE.md` for architecture notes: provider contract,
hook chain, merge rules, rendering). The two repos coordinate through
the tmux option `@recon-ignore`: this repo owns the toggles
(`recon_ignore_toggle.sh`, `recon_ignore_picker.sh`) that flip it;
tmux-agent-tracker's `30-tmux-ignore.sh` provider reads it. Nothing
else is shared — they can be used independently.

---

## Testing

Any change to a script's contract (flags, output format) must be
exercised end-to-end in a live tmux session — unit-testing bash wrappers
against tmux is low-value. Minimum smoke path for any session-manager
change:

1. Save a session with multiple windows and mixed panes. Restore it
   in a fresh tmux server; confirm all panes come up with correct
   cwds and programs.
2. `prefix + C-v` should preview the saved session without mutating
   anything. `prefix + C-d` should show the full file list before
   confirming delete.
3. `prefix + C-w` should offer running + saved destinations; confirm
   move works to both types.
4. For agent-aware restore: save a session with a live Claude pane,
   restore it; confirm the pane resumes the correct session (either
   via `--continue` or `--resume <uuid>` depending on recon
   availability).
