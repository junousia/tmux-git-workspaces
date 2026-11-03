#!/usr/bin/env bash
# Show a short toast about workspace $1 (its git root, or "(no repo)").
root=$1
name=${root##*/}; extra=
if [[ -d $root ]] && branch=$(git -C "$root" branch --show-current 2>/dev/null) && [[ -n $branch ]]; then
  extra="  ⎇ $branch"
fi
count=$(tmux list-windows -F '#{@workspace}' | grep -cxF -- "$root")
noun=windows; (( count == 1 )) && noun=window
tmux display-message -d 1200 "▸ ${name}${extra}  (${count} ${noun})"
