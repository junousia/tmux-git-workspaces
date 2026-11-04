#!/usr/bin/env bash
# Tag every window with its git workspace (@workspace) and record the current
# window's workspace as the status bar filter (@workspace-active).
# Optional $1: session whose windows to scan (needed when run from a status #() job).
# The filter is global, which assumes a single session.

sess=(); [[ -n $1 ]] && sess=(-t "$1")
# @workspace goes last: read collapses empty tab-separated fields.
fmt=$'#{window_id}\t#{window_active}\t#{pane_current_path}\t#{@workspace}'
current=

while IFS=$'\t' read -r id active path ws; do
  [[ -d $path ]] || path=$HOME
  root=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null) || root="(no repo)"
  [[ $root == "$ws" ]] || tmux set-option -wq -t "$id" @workspace "$root"
  [[ $active == 1 ]] && current=$root
done < <(tmux list-windows "${sess[@]}" -F "$fmt")

[[ -n $current && $(tmux show-option -gqv @workspace-active) != "$current" ]] && tmux set-option -gq @workspace-active "$current"

exec "$(dirname "${BASH_SOURCE[0]}")/layout.sh" "$@"
