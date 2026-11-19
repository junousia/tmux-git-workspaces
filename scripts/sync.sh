#!/usr/bin/env bash
# Tag every window with its workspace and record the current window's workspace
# as the status bar filter (@workspace-active).
#
# A workspace is a git *repository*: the main checkout and all of its worktrees
# share one workspace (identified by the common git directory). Per window:
#   @workspace        the repository root (the main checkout, or the bare repo)
#   @worktree         the checkout the window is in (== @workspace for the main one)
#   @workspace-label  display name: the repo folder name, or parent/name when two
#                     workspaces would otherwise look the same
#   @workspace-path   the directory the tags were computed for (a cache key)
# Windows outside any git repo share the workspace "(no repo)".
#
# Optional $1: session whose windows to scan (needed when run from a status #() job).
# $2: --refresh recomputes every window; --layout also recomputes tab positions.
# The filter is global, which assumes a single session.

sess=(); [[ -n $1 ]] && sess=(-t "$1")
# The status job can run on every redraw, including each tab switch. Recheck
# unchanged directories only occasionally; normal path changes are immediate.
last_refresh=$(tmux show-option -gqv @workspace-last-refresh)
if [[ $2 == --refresh || -z $last_refresh || $(( EPOCHSECONDS - last_refresh )) -ge 30 ]]; then
  refresh=1
  tmux set-option -gq @workspace-last-refresh "$EPOCHSECONDS"
fi

US=$'\x1f'   # empty fields must survive read, so not a whitespace separator
fmt="#{window_id}${US}#{window_active}${US}#{pane_current_path}${US}#{@workspace}${US}#{@workspace-path}${US}#{@worktree}${US}#{@workspace-label}"
ids=(); roots=(); worktrees=(); labels=(); cached=()
current=; tag_changed=0

while IFS=$US read -r id active path ws cached_path wt label; do
  [[ -d $path ]] || path=$HOME
  if [[ -z $refresh && $path == "$cached_path" && -n $ws && -n $wt ]]; then
    root=$ws top=$wt
  else
    root="(no repo)" top="(no repo)"
    if out=$(git -C "$path" rev-parse --show-toplevel --git-common-dir 2>/dev/null); then
      top=${out%%$'\n'*}; common=${out#*$'\n'}
      # --git-common-dir is relative to the directory we asked from
      [[ $common == /* ]] || common=$(cd "$path" && cd "$common" && pwd -P)
      if [[ ${common##*/} == .git ]]; then root=${common%/.git}; else root=$common; fi
    fi
    tag_changed=1
  fi
  ids+=("$id"); roots+=("$root"); worktrees+=("$top"); labels+=("$label"); cached+=("$path")
  [[ $active == 1 ]] && current=$root
done < <(tmux list-windows "${sess[@]}" -F "$fmt")

# Labels: the folder name, qualified with its parent when two workspaces collide.
declare -A distinct bases
name_of() { local b=${1##*/}; echo "${b%.git}"; }
for r in "${roots[@]}"; do
  [[ $r == "(no repo)" || -n ${distinct[$r]+x} ]] && continue
  distinct+=(["$r"]=1)
  b=$(name_of "$r")
  bases+=(["$b"]=$(( ${bases[$b]:-0} + 1 )))
done
label_of() {
  local r=$1 b parent
  [[ $r == "(no repo)" ]] && { echo "(no repo)"; return; }
  b=$(name_of "$r")
  if (( ${bases[$b]} > 1 )); then parent=${r%/*}; echo "${parent##*/}/$b"; else echo "$b"; fi
}

cmd=()
for i in "${!ids[@]}"; do
  want=$(label_of "${roots[$i]}")
  # tags are rewritten when the directory changed or the label did
  if [[ $tag_changed == 1 || ${labels[$i]} != "$want" ]]; then
    cmd+=(set-option -wq -t "${ids[$i]}" @workspace "${roots[$i]}" ';'
          set-option -wq -t "${ids[$i]}" @worktree "${worktrees[$i]}" ';'
          set-option -wq -t "${ids[$i]}" @workspace-label "$want" ';'
          set-option -wq -t "${ids[$i]}" @workspace-path "${cached[$i]}" ';')
  fi
done
(( ${#cmd[@]} )) && { tmux "${cmd[@]}"; tag_changed=1; }

[[ -n $current && $(tmux show-option -gqv @workspace-active) != "$current" ]] && tmux set-option -gq @workspace-active "$current"

[[ $tag_changed == 1 || $2 == --layout ]] && exec "$(dirname "${BASH_SOURCE[0]}")/layout.sh" "$1"
exit 0
