#!/usr/bin/env bash
# Toggle the status bar workspace filter.
if [[ $(tmux show-option -gqv @workspaces-filter) == off ]]; then
  tmux set-option -g @workspaces-filter on
  "$(dirname "${BASH_SOURCE[0]}")/sync.sh"
else
  tmux set-option -g @workspaces-filter off
  "$(dirname "${BASH_SOURCE[0]}")/sync.sh"
fi
