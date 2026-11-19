#!/usr/bin/env bash
# fzf preview: details of the workspace that row $2 belongs to.
# $1: window id of the row, $2: workspace root. Git details are those of the
# highlighted window's checkout, so a worktree shows its own branch and changes.
id=$1 root=$2
dim=$'\e[2m'; bold=$'\e[1m'; reset=$'\e[0m'; yellow=$'\e[33m'; green=$'\e[32m'; magenta=$'\e[35m'

US=$'\x1f'
IFS=$US read -r wt label < <(tmux display-message -p -t "$id" "#{@worktree}${US}#{@workspace-label}" 2>/dev/null)
[[ -n $label ]] || { label=${root##*/}; label=${label%.git}; }
[[ -n $wt && $wt != "(no repo)" ]] || wt=$root

echo "${bold}${yellow}${label}${reset}"
if [[ $root == "(no repo)" ]]; then echo "${dim}windows outside a git repo${reset}"; else echo "${dim}${root/#$HOME/\~}${reset}"; fi
echo

if [[ $root != "(no repo)" ]] && git -C "$wt" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$wt" branch --show-current)
  [[ -z $branch ]] && branch="(detached) $(git -C "$wt" rev-parse --short HEAD)"
  changed=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l)
  echo "${magenta}⎇ ${branch}${reset}  ${dim}$([[ $changed -eq 0 ]] && echo clean || echo "$changed changed")${reset}"
  [[ $wt != "$root" ]] && echo "${dim}worktree ${wt#"$root"/}${reset}"
  git -C "$wt" log -3 --format="${dim}%h${reset} %s ${dim}(%cr)${reset}" 2>/dev/null
  echo
fi

echo "${bold}windows${reset}"
tmux list-panes -a -F "#{window_id}${US}#{window_index}${US}#{window_name}${US}#{pane_active}${US}#{pane_current_command}${US}#{pane_current_path}${US}#{@workspace}${US}#{@worktree}" |
while IFS=$US read -r wid idx name pactive cmd path ws wtree; do
  [[ $pactive == 1 ]] || continue
  [[ $ws == "$root" || ( -z $ws && $root == "(no repo)" ) ]] || continue
  mark=" "; [[ $wid == "$id" ]] && mark="${green}▸${reset}"
  base=$root; [[ -n $wtree && $wtree != "(no repo)" ]] && base=$wtree
  if [[ $root == "(no repo)" ]]; then rel=${path/#$HOME/\~}; else rel=${path#"$base"}; rel=${rel:-/}; fi
  tag=; [[ -n $wtree && $wtree != "$root" && $wtree != "(no repo)" ]] && tag=" ⌥ ${wtree##*/}"
  printf ' %s %s %s  %s%s · %s%s%s\n' "$mark" "$idx" "$name" "$dim" "$cmd" "$rel" "$tag" "$reset"
done
