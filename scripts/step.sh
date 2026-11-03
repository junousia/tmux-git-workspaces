#!/usr/bin/env bash
# Select the next/previous window in workspace-tree order (workspaces by their
# first window, windows by index), wrapping around. Crossing into another
# workspace shows a toast. $1: next|prev
dir=${1:-next}

fmt=$'#{window_id}\t#{window_active}\t#{@workspace}'
declare -A members first
roots=(); current=

while IFS=$'\t' read -r id active ws; do
  if [[ -z ${first[$ws]+x} ]]; then first[$ws]=1; roots+=("$ws"); fi
  members[$ws]+="$id "
  [[ $active == 1 ]] && { current=$id; current_root=$ws; }
done < <(tmux list-windows -F "$fmt")

ids=(); of=()
for r in "${roots[@]}"; do
  for id in ${members[$r]}; do ids+=("$id"); of+=("$r"); done
done

n=${#ids[@]}; (( n > 1 )) || exit 0
for i in "${!ids[@]}"; do [[ ${ids[$i]} == "$current" ]] && cur=$i; done
if [[ $dir == prev ]]; then t=$(( (cur - 1 + n) % n )); else t=$(( (cur + 1) % n )); fi

tmux select-window -t "${ids[$t]}"

[[ ${of[$t]} != "$current_root" ]] && "$(dirname "${BASH_SOURCE[0]}")/toast.sh" ws "${of[$t]}"
exit 0
