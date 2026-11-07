#!/usr/bin/env bash
# Cache tab positions for every workspace. Selection never changes this layout;
# tmux reads the active window directly while drawing the bar.
sess=(); [[ -n $1 ]] && sess=(-t "$1")
filter=$(tmux show-option -gqv @workspaces-filter)
ids=(); old=(); wss=()
while IFS=$'\t' read -r id state ws; do
  ids+=("$id"); old+=("$state"); wss+=("$ws")
done < <(tmux list-windows "${sess[@]}" -F $'#{window_id}\t#{@workspace-pos}/#{@workspace-slot}\t#{@workspace}')

# An unfiltered bar is one run. Otherwise each workspace is its own run, even
# when it is not selected, so switching workspaces needs no shell work.
declare -A groups
keys=()
for i in "${!ids[@]}"; do
  key=all
  [[ $filter == off ]] || key="ws:${wss[$i]}"
  [[ -n ${groups[$key]+x} ]] || { keys+=("$key"); groups+=(["$key"]=''); }
  groups+=(["$key"]="${groups[$key]}$i ")
done

cmd=(); changed=0
for key in "${keys[@]}"; do
  indices=( ${groups[$key]} )
  n=${#indices[@]}
  for slot in "${!indices[@]}"; do
    i=${indices[$slot]}
    pos=mid
    (( slot == 0 )) && pos=first
    (( slot == n - 1 )) && pos=last
    (( n == 1 )) && pos=only
    [[ ${old[$i]} == "$pos/$slot" ]] && continue
    cmd+=(set-option -wq -t "${ids[$i]}" @workspace-pos "$pos" \; set-option -wq -t "${ids[$i]}" @workspace-slot "$slot" \;)
    changed=1
  done
done
(( changed )) || exit 0
tmux "${cmd[@]}" refresh-client -S 2>/dev/null
exit 0
