#!/usr/bin/env bash
# Tag every window with its git workspace (@workspace) and record the current
# window's workspace as the status bar filter (@workspace-active).
# Optional $1: session whose windows to scan (needed when run from a status #() job).
# The filter is global, which assumes a single session.

sess=(); [[ -n $1 ]] && sess=(-t "$1")
# The status job can run on every redraw, including each tab switch. Recheck
# unchanged directories only occasionally; normal path changes are immediate.
last_refresh=$(tmux show-option -gqv @workspace-last-refresh)
if [[ $2 == --refresh || -z $last_refresh || $(( EPOCHSECONDS - last_refresh )) -ge 30 ]]; then
  refresh=1
  tmux set-option -gq @workspace-last-refresh "$EPOCHSECONDS"
fi
# @workspace goes last: read collapses empty tab-separated fields.
fmt=$'#{window_id}\t#{window_active}\t#{pane_current_path}\t#{@workspace}\t#{@workspace-path}'
current=

while IFS=$'\t' read -r id active path ws cached_path; do
  [[ -d $path ]] || path=$HOME
  if [[ -z $refresh && $path == "$cached_path" && -n $ws ]]; then
    root=$ws
  else
    root=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null) || root="(no repo)"
    tmux set-option -wq -t "$id" @workspace "$root" ';' \
      set-option -wq -t "$id" @workspace-path "$path"
  fi
  [[ $active == 1 ]] && current=$root
done < <(tmux list-windows "${sess[@]}" -F "$fmt")

[[ -n $current && $(tmux show-option -gqv @workspace-active) != "$current" ]] && tmux set-option -gq @workspace-active "$current"

exec "$(dirname "${BASH_SOURCE[0]}")/layout.sh" "$@"
