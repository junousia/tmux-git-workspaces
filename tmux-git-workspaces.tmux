#!/usr/bin/env bash
# TPM entry point. Load after the theme plugin so its window formats get wrapped.
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

opt() { local v; v=$(tmux show-option -gqv "$1"); echo "${v:-$2}"; }

# bindk <key> <command...>: bind in the prefix table, or without the prefix when
# the key is written root:<key> (for example root:M-w).
bindk() {
  local k=$1; shift
  if [[ $k == root:* ]]; then tmux bind-key -n "${k#root:}" "$@"; else tmux bind-key "$k" "$@"; fi
}

# Workspace picker (default prefix + w) and jump back to the previous workspace
# (default prefix + Tab). Unset a key with an empty value.
picker_key=$(tmux show-option -gqv @workspaces-key); [[ -z $picker_key ]] && picker_key=w
[[ $picker_key == off ]] || bindk "$picker_key" display-popup -E -w 85% -h 70% -b rounded -T ' workspaces ' "$dir/scripts/picker.sh"
last_key=$(tmux show-option -gqv @workspaces-last-key); [[ -z $last_key ]] && last_key=Tab
[[ $last_key == off ]] || bindk "$last_key" run-shell "$dir/scripts/last.sh"
# Optional: step through windows in workspace-tree order (no prefix), e.g.
#   set -g @workspaces-next-key S-Right
#   set -g @workspaces-prev-key S-Left
# and to jump between workspaces: @workspaces-next-ws-key / @workspaces-prev-ws-key
next_key=$(opt @workspaces-next-key '')
prev_key=$(opt @workspaces-prev-key '')
[[ -n $next_key ]] && tmux bind-key -n "$next_key" run-shell "$dir/scripts/step.sh next"
[[ -n $prev_key ]] && tmux bind-key -n "$prev_key" run-shell "$dir/scripts/step.sh prev"
# Optional: jump to the next/previous workspace (repo), e.g. S-Down / S-Up
next_ws_key=$(opt @workspaces-next-ws-key '')
prev_ws_key=$(opt @workspaces-prev-ws-key '')
[[ -n $next_ws_key ]] && tmux bind-key -n "$next_ws_key" run-shell "$dir/scripts/step.sh next-ws"
[[ -n $prev_ws_key ]] && tmux bind-key -n "$prev_ws_key" run-shell "$dir/scripts/step.sh prev-ws"

bindk "$(opt @workspaces-toggle-key F)" run-shell "$dir/scripts/toggle.sh"

# Wrap the theme's window formats once: other workspaces' windows render empty.
# (The original format is kept in an option and expanded with #{E:...}, which
# avoids comma-escaping problems inside the conditional.)
# The separator is saved once: we blank the real one, so a reload would read ''.
sep=$(tmux show-option -gqv @workspaces-orig-sep)
if [[ -z $sep && -z $(tmux show-option -gqv @workspaces-orig-fmt) ]]; then
  sep=$(tmux show-option -gv window-status-separator)
  tmux set-option -g @workspaces-orig-sep "$sep"
fi
# Filter scope: a repo's worktrees share one workspace (default), or each worktree
# filters on its own (@workspaces-scope worktree).
scope=@workspace; [[ $(opt @workspaces-scope repo) == worktree ]] && scope=@worktree
fmt=$(tmux show-option -gv window-status-format)
if [[ $fmt != *@workspaces-orig-fmt* ]]; then
  cur=$(tmux show-option -gv window-status-current-format)
  tmux set-option -g @workspaces-orig-fmt "$fmt"
  tmux set-option -g @workspaces-orig-current-fmt "$cur"
  tmux set-option -g window-status-separator ''
  # The empty #() also re-syncs workspaces every status-interval (catches cd).
  tmux set-option -g window-status-current-format \
    "#('$dir/scripts/sync.sh' '#{session_name}')#{E:@workspaces-orig-current-fmt}$sep"
fi
# (Re)write the filter wrapper on every load so a changed @workspaces-scope applies.
tmux set-option -g window-status-format \
  "#{?#{||:#{==:#{@workspaces-filter},off},#{==:#{$scope},#{W:,#{$scope}}}},#{E:@workspaces-orig-fmt}$sep,}"

# Keep hook indexes stable across plugin reloads, and remove the old selection
# sync hooks so upgrading an existing server actually takes the fast path.
sync="run-shell -b '$dir/scripts/sync.sh'"
tmux set-hook -g 'after-new-window[40]' "run-shell '$dir/scripts/sync.sh'"
tmux set-hook -g 'after-split-window[41]' "$sync"
tmux set-hook -g 'window-linked[42]' "$sync"
tmux set-hook -g 'pane-focus-in[43]' "$sync"
tmux set-hook -gu 'session-window-changed[44]'
tmux set-hook -gu 'client-session-changed[45]'
# Tab positions are cached for every workspace. Selection needs no layout hook.
tmux set-hook -gu 'session-window-changed[50]'
tmux set-hook -gu 'client-session-changed[51]'
layout="run-shell -b '$dir/scripts/layout.sh'"
tmux set-hook -g 'window-linked[52]' "$layout"
tmux set-hook -g 'window-unlinked[53]' "$layout"
# Recent use: a counter ticks on every window change and each window remembers
# the tick it was last selected at (@workspaces-seen). Plain tmux commands, no
# process is started, so switching stays instant. The picker, the workspace jump
# keys and prefix + Tab read it.
tmux set-hook -g 'session-window-changed[60]' \
  "set-option -gF @workspaces-clock '#{e|+:#{@workspaces-clock},1}' ; set-option -wF @workspaces-seen '#{@workspaces-clock}'"
if [[ -z $(tmux display-message -p '#{@workspaces-seen}') ]]; then
  tmux set-option -gF @workspaces-clock '#{e|+:#{@workspaces-clock},1}' \; set-option -wF @workspaces-seen '#{@workspaces-clock}'
fi
tmux run-shell -b "$dir/scripts/sync.sh '' --refresh"
