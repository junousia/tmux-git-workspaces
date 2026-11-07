#!/usr/bin/env bash
# TPM entry point. Load after the theme plugin so its window formats get wrapped.
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

opt() { local v; v=$(tmux show-option -gqv "$1"); echo "${v:-$2}"; }

tmux bind-key "$(opt @workspaces-key W)" display-popup -E -w 85% -h 70% -b rounded -T ' workspaces ' "$dir/scripts/picker.sh"
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

tmux bind-key "$(opt @workspaces-toggle-key F)" run-shell "$dir/scripts/toggle.sh"

# Wrap the theme's window formats once: other workspaces' windows render empty.
# (The original format is kept in an option and expanded with #{E:...}, which
# avoids comma-escaping problems inside the conditional.)
# The separator is saved once: we blank the real one, so a reload would read ''.
sep=$(tmux show-option -gqv @workspaces-orig-sep)
if [[ -z $sep && -z $(tmux show-option -gqv @workspaces-orig-fmt) ]]; then
  sep=$(tmux show-option -gv window-status-separator)
  tmux set-option -g @workspaces-orig-sep "$sep"
fi
fmt=$(tmux show-option -gv window-status-format)
if [[ $fmt != *@workspaces-orig-fmt* ]]; then
  cur=$(tmux show-option -gv window-status-current-format)
  tmux set-option -g @workspaces-orig-fmt "$fmt"
  tmux set-option -g @workspaces-orig-current-fmt "$cur"
  tmux set-option -g window-status-separator ''
  tmux set-option -g window-status-format \
    "#{?#{||:#{==:#{@workspaces-filter},off},#{==:#{@workspace},#{W:,#{@workspace}}}},#{E:@workspaces-orig-fmt}$sep,}"
  # The empty #() also re-syncs workspaces every status-interval (catches cd).
  tmux set-option -g window-status-current-format \
    "#('$dir/scripts/sync.sh' '#{session_name}')#{E:@workspaces-orig-current-fmt}$sep"
fi

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
tmux run-shell -b "$dir/scripts/sync.sh"
