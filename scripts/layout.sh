#!/usr/bin/env bash
# Fast, git-free part of the sync: from the cached @workspace tags, record the
# current workspace (@workspace-active), where the visible window run starts and
# ends (@workspace-pos: first, last, only or mid), each visible window's slot in
# that run (@workspace-slot: 0, 1, 2, ... static, independent of the selection)
# and whether its right neighbour is the active window (@workspace-nextact: 1/0),
# so themes can draw end caps, shade tabs and round the joins between them.
# Hooks run it synchronously on window changes so the bar never lags a frame.
# Optional $1: session whose windows to scan.

sess=(); [[ -n $1 ]] && sess=(-t "$1")
# Idempotent on purpose: it only writes (and redraws) when a value changed, since
# the status bar's #() job runs it and a redraw re-runs that job.
ids=(); act=(); wss=(); old=()
while IFS=$'\t' read -r id active cur_state ws; do
  ids+=("$id"); act+=("$active"); old+=("$cur_state"); wss+=("$ws")
done < <(tmux list-windows "${sess[@]}" -F $'#{window_id}\t#{window_active}\t#{@workspace-pos}/#{@workspace-slot}/#{@workspace-nextact}\t#{@workspace}')

current=
for i in "${!ids[@]}"; do [[ ${act[$i]} == 1 ]] && current=${wss[$i]}; done
[[ -z $current ]] && exit 0

filter=$(tmux show-option -gqv @workspaces-filter)
vis=(); cur=0
for i in "${!ids[@]}"; do
  if [[ $filter == off || ${wss[$i]} == "$current" ]]; then
    [[ ${act[$i]} == 1 ]] && cur=${#vis[@]}
    vis+=("${ids[$i]}")
  fi
done
n=${#vis[@]}
cmd=(); changed=0
# remember the last window used in each workspace (for workspace jumps)
for i in "${!ids[@]}"; do
  [[ ${act[$i]} == 1 ]] || continue
  lk=@wslast-$(cksum <<<"$current" | cut -d' ' -f1)
  [[ $(tmux show-option -gqv "$lk") == "${ids[$i]}" ]] || tmux set-option -gq "$lk" "${ids[$i]}"
done
[[ $(tmux show-option -gqv @workspace-active) == "$current" ]] || { cmd+=(set-option -gq @workspace-active "$current" \;); changed=1; }
declare -A want
for i in "${!vis[@]}"; do
  p=mid; (( i == 0 )) && p=first; (( i == n - 1 )) && p=last; (( n == 1 )) && p=only
  na=0; (( i + 1 == cur )) && na=1
  want[${vis[$i]}]="$p/$i/$na"
done
for i in "${!ids[@]}"; do
  id=${ids[$i]}; w=${want[$id]-//}
  [[ $w == "${old[$i]}" ]] && continue
  IFS=/ read -r p sl na <<<"$w"
  cmd+=(set-option -wq -t "$id" @workspace-pos "$p" \; set-option -wq -t "$id" @workspace-slot "$sl" \; set-option -wq -t "$id" @workspace-nextact "$na" \;)
  changed=1
done
(( changed )) || exit 0
tmux "${cmd[@]}" refresh-client -S 2>/dev/null
exit 0
