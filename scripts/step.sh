#!/usr/bin/env bash
# Select the next/previous window in workspace-tree order (workspaces by their
# first window, windows by index), wrapping around. $1: next|prev, or next-ws|prev-ws to jump to the
# next/previous workspace (landing on the window you last used there).
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

if [[ $dir == *-ws ]]; then
  nr=${#roots[@]}; (( nr > 1 )) || exit 0
  for i in "${!roots[@]}"; do [[ ${roots[$i]} == "$current_root" ]] && ci=$i; done
  if [[ $dir == prev-ws ]]; then ti=$(( (ci - 1 + nr) % nr )); else ti=$(( (ci + 1) % nr )); fi
  root=${roots[$ti]}
  key=@wslast-$(cksum <<<"$root" | cut -d' ' -f1)
  want=$(tmux show-option -gqv "$key")
  target=; for id in ${members[$root]}; do [[ -z $target ]] && target=$id; [[ $id == "$want" ]] && { target=$id; break; }; done
  tmux select-window -t "$target"
  exit 0
fi

n=${#ids[@]}; (( n > 1 )) || exit 0
for i in "${!ids[@]}"; do [[ ${ids[$i]} == "$current" ]] && cur=$i; done
if [[ $dir == prev ]]; then t=$(( (cur - 1 + n) % n )); else t=$(( (cur + 1) % n )); fi

tmux select-window -t "${ids[$t]}"

exit 0
