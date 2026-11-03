#!/usr/bin/env bash
# Toggle the status bar workspace filter and say what it is now.
if [[ $(tmux show-option -gqv @workspaces-filter) == off ]]; then
  tmux set-option -g @workspaces-filter on
  tmux display-message -d 1200 "workspace filter: on (current workspace only)"
else
  tmux set-option -g @workspaces-filter off
  tmux display-message -d 1200 "workspace filter: off (all windows)"
fi
