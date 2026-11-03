#!/usr/bin/env bash
# Print the window tree grouped by git workspace, one fzf row per line.
# Row format: <window_id>\t<display text>\t<workspace root>\t<repo name, for filtering>
# Workspace header rows carry the id of the workspace's first window.

fmt=$'#{window_id}\t#{window_active}\t#{window_index}\t#{window_name}\t#{pane_current_path}'

declare -A members first
workspaces=()

while IFS=$'\t' read -r id active idx name path; do
  [[ -d $path ]] || path=$HOME
  root=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null) || root="(no repo)"
  if [[ -z ${first[$root]} ]]; then
    first[$root]=$id
    workspaces+=("$root")
  fi
  members[$root]+="$id"$'\t'"$active"$'\t'"$idx"$'\t'"$name"$'\n'
done < <(tmux list-windows -F "$fmt")

dim=$'\e[2m'; bold=$'\e[1m'; reset=$'\e[0m'
green=$'\e[32m'; yellow=$'\e[33m'; magenta=$'\e[35m'

for root in "${workspaces[@]}"; do
  mapfile -t rows < <(printf '%s' "${members[$root]}")
  branch=; short=${root/#$HOME/\~}
  if [[ $root == "(no repo)" ]]; then
    short="windows outside a git repo"
  else
    branch=$(git -C "$root" branch --show-current 2>/dev/null)
    [[ -z $branch ]] && branch=$(git -C "$root" rev-parse --short HEAD 2>/dev/null)
    [[ -n $branch ]] && branch="  ${magenta}⎇ ${branch}${reset}"
  fi

  printf '%s\t%s▾ %s%s%s  %s(%d)%s  %s%s%s\t%s\t\n' "${first[$root]}" \
    "$bold$yellow" "${root##*/}" "$reset" "$branch" "$dim" "${#rows[@]}" "$reset" "$dim" "$short" "$reset" "$root"

  n=${#rows[@]}; i=0
  for row in "${rows[@]}"; do
    i=$((i + 1))
    IFS=$'\t' read -r id active idx name <<< "$row"
    branchchar="├─"; [[ $i -eq $n ]] && branchchar="└─"
    if [[ $active == 1 ]]; then
      printf '%s\t  %s%s%s %s●%s %s%s %s%s\t%s\t%s%s%s\n' "$id" "$dim" "$branchchar" "$reset" "$green" "$reset" "$green$bold" "$idx" "$name" "$reset" "$root" "$dim" "${root##*/}" "$reset"
    else
      printf '%s\t  %s%s%s %s·%s %s %s\t%s\t%s%s%s\n' "$id" "$dim" "$branchchar" "$reset" "$dim" "$reset" "$idx" "$name" "$root" "$dim" "${root##*/}" "$reset"
    fi
  done
done
