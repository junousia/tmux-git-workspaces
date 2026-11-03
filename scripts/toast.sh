#!/usr/bin/env bash
# Show a short toast, as a small popup in the top-right corner.
#   toast.sh ws <workspace root>   e.g. "▸ homelab  ⎇ main  (3 windows)"
#   toast.sh msg <text>
# Any key dismisses it early (and is swallowed: popups are modal).
# @workspaces-toast: popup (default) | message (status line) | off

mode=$1; shift
style=$(tmux show-option -gqv @workspaces-toast); style=${style:-popup}
[[ $style == off ]] && exit 0

dim='\033[2m'; bold='\033[1m'; yellow='\033[33m'; magenta='\033[35m'; reset='\033[0m'

if [[ $mode == ws ]]; then
  root=$1; name=${root##*/}; branch=
  if [[ -d $root ]]; then branch=$(git -C "$root" branch --show-current 2>/dev/null); fi
  count=$(tmux list-windows -F '#{@workspace}' | grep -cxF -- "$root")
  noun=windows; (( count == 1 )) && noun=window
  plain="▸ ${name}${branch:+  ⎇ $branch}  ($count $noun)"
  colored="${bold}${yellow}▸ ${name}${reset}${branch:+  ${magenta}⎇ ${branch}${reset}}  ${dim}(${count} ${noun})${reset}"
else
  plain=$1; colored=$1
fi

if [[ $style == message ]]; then
  tmux display-message -d 1500 "$plain"
  exit 0
fi

tmux display-popup -E -x R -y 0 -w $(( ${#plain} + 4 )) -h 3 -b rounded -S 'fg=#fabd2f' \
  -e "TOAST=$colored" \
  "bash -c 'printf \" %b\\n\" \"\$TOAST\"; read -rsn1 -t 1.2'"
