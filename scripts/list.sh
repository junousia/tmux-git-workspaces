#!/usr/bin/env bash
# Rows for the workspace picker (fzf), tab-separated:
#   <window id>\t<display text>\t<workspace root>\t<repo name, for filtering>
#
#   list.sh                  one row per workspace (default view)
#   list.sh --windows <root> the windows of one workspace
#   list.sh --tree           every workspace with all its windows (old view)
#
# Workspaces are ordered by recent use (@workspaces-order mru, default; or
# 'created'): the first row is where you are, the second where you were.
# A workspace row points at the window you last used there.
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[[ $1 == --tree ]] && exec "$dir/list-tree.sh"

order=$(tmux show-option -gqv @workspaces-order); order=${order:-mru}
dim=$'\e[2m'; bold=$'\e[1m'; reset=$'\e[0m'
green=$'\e[32m'; yellow=$'\e[33m'; magenta=$'\e[35m'

branch_of() {  # branch_of <root>: "  ⎇ name" (or empty)
  local b; [[ $1 == "(no repo)" ]] && return
  b=$(git -C "$1" branch --show-current 2>/dev/null)
  [[ -z $b ]] && b=$(git -C "$1" rev-parse --short HEAD 2>/dev/null)
  [[ -n $b ]] && printf '  %s⎇ %s%s' "$magenta" "$b" "$reset"
}
short_of() { if [[ $1 == "(no repo)" ]]; then echo "windows outside a git repo"; else echo "${1/#$HOME/\~}"; fi; }

# seen is 0 for windows never visited; ws goes last (tab-separated read collapses empties)
fmt=$'#{window_id}\t#{window_active}\t#{window_index}\t#{?#{@workspaces-seen},#{@workspaces-seen},0}\t#{window_name}\t#{@workspace}'

if [[ $1 == --windows ]]; then
  root=$2; rows=()
  while IFS=$'\t' read -r id active idx seen name ws; do
    [[ $ws == "$root" ]] && rows+=("$id"$'\t'"$active"$'\t'"$idx"$'\t'"$name")
  done < <(tmux list-windows -F "$fmt")
  n=${#rows[@]}; i=0
  printf '%s\t%s%s%s%s  %s%s%s\t%s\t\n' "${rows[0]%%$'\t'*}" "$bold$yellow" "${root##*/}" "$reset" "$(branch_of "$root")" "$dim" "$(short_of "$root")" "$reset" "$root"
  for row in "${rows[@]}"; do
    i=$((i + 1))
    IFS=$'\t' read -r id active idx name <<<"$row"
    glyph="├─"; (( i == n )) && glyph="└─"
    if [[ $active == 1 ]]; then
      printf '%s\t  %s%s%s %s●%s %s%s %s%s\t%s\t%s%s%s\n' "$id" "$dim" "$glyph" "$reset" "$green" "$reset" "$green$bold" "$idx" "$name" "$reset" "$root" "$dim" "${root##*/}" "$reset"
    else
      printf '%s\t  %s%s%s %s·%s %s %s\t%s\t%s%s%s\n' "$id" "$dim" "$glyph" "$reset" "$dim" "$reset" "$idx" "$name" "$root" "$dim" "${root##*/}" "$reset"
    fi
  done
  exit 0
fi

# one pass: per workspace its window count, names, most recently used window
declare -A count names best bestseen cur
roots=()
while IFS=$'\t' read -r id active idx seen name ws; do
  if [[ -z ${count[$ws]+x} ]]; then
    roots+=("$ws"); count+=(["$ws"]=0); names+=(["$ws"]=''); best+=(["$ws"]="$id"); bestseen+=(["$ws"]=-1); cur+=(["$ws"]=0)
  fi
  count[$ws]=$(( count[$ws] + 1 ))
  names[$ws]+="$name "
  # most recently used window; ties (never visited) go to the lowest index
  if (( seen > bestseen[$ws] )); then best[$ws]=$id; bestseen[$ws]=$seen; fi
  [[ $active == 1 ]] && cur[$ws]=1
done < <(tmux list-windows -F "$fmt")

sorted=()
if [[ $order == created ]]; then
  sorted=("${roots[@]}")
else
  i=0
  while IFS=$'\t' read -r _ _ r; do sorted+=("$r"); done < <(
    for r in "${roots[@]}"; do
      # the workspace you are in is always first
      printf '%s\t%s\t%s\n' "$(( cur[$r] == 1 ? 999999999 : bestseen[$r] ))" "$((i++))" "$r"
    done | sort -t$'\t' -k1,1nr -k2,2n)
fi

for r in "${sorted[@]}"; do
  n=${count[$r]}; noun=windows; (( n == 1 )) && noun=window
  mark="  "; (( cur[$r] == 1 )) && mark="${green}●${reset} "
  wn=${names[$r]% }; (( ${#wn} > 48 )) && wn="${wn:0:47}…"
  printf '%s\t%s%s%s%s%s  %s(%d)%s  %s%s%s\t%s\t%s\n' "${best[$r]}" \
    "$mark" "$bold$yellow" "${r##*/}" "$reset" "$(branch_of "$r")" \
    "$dim" "$n" "$reset" "$dim" "$wn" "$reset" "$r" "${r##*/}"
done
