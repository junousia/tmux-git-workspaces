#!/usr/bin/env bash
# Toggle the status bar workspace filter and say what it is now.
if [[ $(tmux show-option -gqv @workspaces-filter) == off ]]; then
  tmux set-option -g @workspaces-filter on
  "$(dirname "${BASH_SOURCE[0]}")/toast.sh" msg "workspace filter: on (current workspace only)"
else
  tmux set-option -g @workspaces-filter off
  "$(dirname "${BASH_SOURCE[0]}")/toast.sh" msg "workspace filter: off (all windows)"
fi
