#!/usr/bin/env bash
# TPM entry point. Load after the theme plugin so its window formats get wrapped.
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

opt() { local v; v=$(tmux show-option -gqv "$1"); echo "${v:-$2}"; }

tmux bind-key "$(opt @workspaces-key W)" display-popup -E -w 85% -h 70% -b rounded -T ' workspaces ' "$dir/scripts/picker.sh"
tmux bind-key "$(opt @workspaces-toggle-key F)" if-shell -F '#{==:#{@workspaces-filter},off}' \
  'set -g @workspaces-filter on' 'set -g @workspaces-filter off'

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
    "#{?#{||:#{==:#{@workspaces-filter},off},#{==:#{@workspace},#{@workspace-active}}},#{E:@workspaces-orig-fmt}$sep,}"
  # The empty #() also re-syncs workspaces every status-interval (catches cd).
  tmux set-option -g window-status-current-format \
    "#('$dir/scripts/sync.sh' '#{session_name}')#{E:@workspaces-orig-current-fmt}$sep"
fi

sync="run-shell -b '$dir/scripts/sync.sh'"
i=0
for h in after-new-window after-split-window window-linked pane-focus-in session-window-changed client-session-changed; do
  tmux set-hook -g "$h[4$i]" "$sync"
  i=$((i + 1))
done
tmux run-shell -b "$dir/scripts/sync.sh"
