#!/usr/bin/env bash
# Jump to the workspace you were in before this one, landing on the window you
# last used there. Press again to come back (like alt-tab).
fmt=$'#{window_id}\t#{window_active}\t#{?#{@workspaces-seen},#{@workspaces-seen},0}\t#{@workspace}'
declare -A seen ws
ids=(); current=
while IFS=$'\t' read -r id active seen_at root; do
  ids+=("$id"); seen+=(["$id"]="$seen_at"); ws+=(["$id"]="$root")
  [[ $active == 1 ]] && current=$root
done < <(tmux list-windows -F "$fmt")

target=; ts=0
for id in "${ids[@]}"; do
  [[ ${ws[$id]} == "$current" ]] && continue
  (( seen[$id] > ts )) && { target=$id; ts=${seen[$id]}; }
done
[[ -n $target ]] && tmux select-window -t "$target"
exit 0
