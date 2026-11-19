#!/usr/bin/env bash
# Rows for the workspace picker (fzf), tab-separated:
#   <window id>\t<display text>\t<workspace root>\t<repo name, for filtering>
#
#   list.sh                  one row per workspace (default view)
#   list.sh --windows <root> the windows of one workspace, grouped by worktree
#   list.sh --tree           every workspace with all its windows (old view)
#
# A workspace is a git repository: its worktrees share one row. Workspaces are
# ordered by recent use (@workspaces-order mru, default; or 'created'): the first
# row is where you are, the second where you were. A workspace row points at the
# window you last used there.
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[[ $1 == --tree ]] && exec "$dir/list-tree.sh"

order=$(tmux show-option -gqv @workspaces-order); order=${order:-mru}
dim=$'\e[2m'; bold=$'\e[1m'; reset=$'\e[0m'
green=$'\e[32m'; yellow=$'\e[33m'; magenta=$'\e[35m'

branch_of() {  # branch_of <checkout>: "  ⎇ name" (or empty)
  local b; [[ -z $1 || $1 == "(no repo)" ]] && return
  b=$(git -C "$1" branch --show-current 2>/dev/null)
  [[ -z $b ]] && b=$(git -C "$1" rev-parse --short HEAD 2>/dev/null)
  [[ -n $b ]] && printf '  %s⎇ %s%s' "$magenta" "$b" "$reset"
}
short_of() { if [[ $1 == "(no repo)" ]]; then echo "windows outside a git repo"; else echo "${1/#$HOME/\~}"; fi; }
name_of() { local b=${1##*/}; echo "${b%.git}"; }

# Fields are unit-separated so empty ones survive read. seen is 0 for windows
# never visited.
US=$'\x1f'
fmt="#{window_id}${US}#{window_active}${US}#{window_index}${US}#{?#{@workspaces-seen},#{@workspaces-seen},0}${US}#{window_name}${US}#{@worktree}${US}#{@workspace-label}${US}#{@workspace}"

if [[ $1 == --windows ]]; then
  root=$2; rows=(); declare -A wt_order wt_first; wts=(); label=
  while IFS=$US read -r id active idx seen name wt lbl ws; do
    [[ $ws == "$root" ]] || continue
    label=${lbl:-$(name_of "$root")}; wt=${wt:-$root}
    if [[ -z ${wt_first[$wt]+x} ]]; then wts+=("$wt"); wt_first+=(["$wt"]="$id"); fi
    rows+=("$wt"$'\t'"$id"$'\t'"$active"$'\t'"$idx"$'\t'"$name")
  done < <(tmux list-windows -F "$fmt")
  first_id=$(cut -f2 <<<"${rows[0]}")
  printf '%s\t%s%s%s  %s%s%s\t%s\t\n' "$first_id" "$bold$yellow" "$label" "$reset" "$dim" "$(short_of "$root")" "$reset" "$root"
  for wt in "${wts[@]}"; do
    # several worktrees: a sub-header per checkout, with its branch
    if (( ${#wts[@]} > 1 )); then
      if [[ $wt == "$root" ]]; then rel="main checkout"; elif [[ $wt == "$root"/* ]]; then rel=${wt#"$root"/}; else rel=${wt##*/}; fi
      printf '%s\t  %s⌥%s %s%s%s%s\t%s\t%s%s%s\n' "${wt_first[$wt]}" "$dim" "$reset" "$bold" "${rel}" "$reset" "$(branch_of "$wt")" "$root" "$dim" "$label" "$reset"
    fi
    mapfile -t mine < <(printf '%s\n' "${rows[@]}" | awk -F'\t' -v w="$wt" '$1 == w')
    n=${#mine[@]}; i=0
    for row in "${mine[@]}"; do
      i=$((i + 1))
      IFS=$'\t' read -r _ id active idx name <<<"$row"
      glyph="├─"; (( i == n )) && glyph="└─"
      if [[ $active == 1 ]]; then
        printf '%s\t    %s%s%s %s●%s %s%s %s%s\t%s\t%s%s%s\n' "$id" "$dim" "$glyph" "$reset" "$green" "$reset" "$green$bold" "$idx" "$name" "$reset" "$root" "$dim" "$label" "$reset"
      else
        printf '%s\t    %s%s%s %s·%s %s %s\t%s\t%s%s%s\n' "$id" "$dim" "$glyph" "$reset" "$dim" "$reset" "$idx" "$name" "$root" "$dim" "$label" "$reset"
      fi
    done
  done
  exit 0
fi

# one pass: per workspace its window count, names, worktrees, most recently used window
declare -A count names best bestseen cur lab bestwt wtset wtcount
roots=()
while IFS=$US read -r id active idx seen name wt lbl ws; do
  if [[ -z ${count[$ws]+x} ]]; then
    roots+=("$ws"); count+=(["$ws"]=0); names+=(["$ws"]=''); best+=(["$ws"]="$id"); bestseen+=(["$ws"]=-1)
    cur+=(["$ws"]=0); lab+=(["$ws"]="${lbl:-$(name_of "$ws")}"); bestwt+=(["$ws"]="$wt"); wtcount+=(["$ws"]=0)
  fi
  count[$ws]=$(( count[$ws] + 1 ))
  names[$ws]+="$name "
  [[ -n $wt && -z ${wtset["$ws|$wt"]+x} ]] && { wtset+=(["$ws|$wt"]=1); wtcount[$ws]=$(( wtcount[$ws] + 1 )); }
  # most recently used window; ties (never visited) go to the lowest index
  if (( seen > bestseen[$ws] )); then best[$ws]=$id; bestseen[$ws]=$seen; bestwt[$ws]=$wt; fi
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
  n=${count[$r]}
  mark="  "; (( cur[$r] == 1 )) && mark="${green}●${reset} "
  wn=${names[$r]% }; (( ${#wn} > 48 )) && wn="${wn:0:47}…"
  extra=; (( wtcount[$r] > 1 )) && extra="  ${dim}⌥ ${wtcount[$r]}${reset}"
  printf '%s\t%s%s%s%s%s%s%s  %s(%d)%s  %s%s%s\t%s\t%s\n' "${best[$r]}" \
    "$mark" "$bold$yellow" "${lab[$r]}" "$reset" "$(branch_of "${bestwt[$r]:-$r}")" "$extra" "" \
    "$dim" "$n" "$reset" "$dim" "$wn" "$reset" "$r" "${lab[$r]}"
done
