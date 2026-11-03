#!/usr/bin/env bash
# fzf preview: details of the workspace that row $2 belongs to.
# $1: window id of the row, $2: workspace root.
id=$1 root=$2
dim=$'\e[2m'; bold=$'\e[1m'; reset=$'\e[0m'; yellow=$'\e[33m'; green=$'\e[32m'; magenta=$'\e[35m'

echo "${bold}${yellow}${root##*/}${reset}"
if [[ $root == "(no repo)" ]]; then echo "${dim}windows outside a git repo${reset}"; else echo "${dim}${root/#$HOME/\~}${reset}"; fi
echo

if [[ $root != "(no repo)" ]] && git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$root" branch --show-current)
  [[ -z $branch ]] && branch="(detached) $(git -C "$root" rev-parse --short HEAD)"
  changed=$(git -C "$root" status --porcelain 2>/dev/null | wc -l)
  echo "${magenta}⎇ ${branch}${reset}  ${dim}$([[ $changed -eq 0 ]] && echo clean || echo "$changed changed")${reset}"
  git -C "$root" log -3 --format="${dim}%h${reset} %s ${dim}(%cr)${reset}" 2>/dev/null
  echo
fi

echo "${bold}windows${reset}"
tmux list-panes -a -F $'#{window_id}\t#{window_index}\t#{window_name}\t#{pane_active}\t#{pane_current_command}\t#{pane_current_path}' |
while IFS=$'\t' read -r wid idx name pactive cmd path; do
  [[ $pactive == 1 ]] || continue
  [[ -d $path ]] || continue
  r=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null) || r="(no repo)"
  [[ $r == "$root" ]] || continue
  mark=" "; [[ $wid == "$id" ]] && mark="${green}▸${reset}"
  if [[ $root == "(no repo)" ]]; then rel=${path/#$HOME/\~}; else rel=${path#"$root"}; rel=${rel:-/}; fi
  printf ' %s %s %s  %s%s · %s%s\n' "$mark" "$idx" "$name" "$dim" "$cmd" "$rel" "$reset"
done
