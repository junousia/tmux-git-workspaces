#!/usr/bin/env bash
# Show a short toast: in tmux-axolotl's status bar (default when it is present; it
# is not modal, so your keys keep going to the pane and it clears itself), or as a
# small popup in the top-right corner (tmux popups are modal).
#   toast.sh ws <workspace root>   e.g. "▸ homelab  ⎇ main  (3 windows)"
#   toast.sh msg <text>
# Any key dismisses it early; S-Left/S-Right also keep stepping (see toast-body.sh).
# Options: @workspaces-toast bar | popup | message (status line) | off
#            (default: bar with tmux-axolotl, else popup)
#          @workspaces-toast-duration seconds (default 2.5)
#          @workspaces-toast-border border colour (default: the palette's muted colour)
# Colours follow tmux-axolotl's palette when present, else the terminal's ANSI colours.

mode=$1; shift
style=$(tmux show-option -gqv @workspaces-toast)
if [[ -z $style ]]; then
  [[ -n $(tmux show-option -gqv @axolotl-pal-rgb-accent) ]] && style=bar || style=popup
fi
[[ $style == off ]] && exit 0

opt() { local v; v=$(tmux show-option -gqv "$1"); echo "${v:-$2}"; }
duration=$(opt @workspaces-toast-duration 2.5)
# shellcheck source=palette.sh
source "$(dirname "${BASH_SOURCE[0]}")/palette.sh"
border=$(opt @workspaces-toast-border "$P_MUTED")

reset='\033[0m'; bold='\033[1m'; dimmed='\033[2m'
accent="\033[$(sgr_fg "$P_ACCENT")m"; cream="\033[$(sgr_fg "$P_TEXT")m"
grey="\033[$(sgr_fg "$P_MUTED")m"; dark="${dimmed}\033[$(sgr_fg "$P_MUTED")m"

if [[ $mode == ws ]]; then
  root=$1; name=${root##*/}; branch=
  if [[ -d $root ]]; then branch=$(git -C "$root" branch --show-current 2>/dev/null); fi
  count=$(tmux list-windows -F '#{@workspace}' | grep -cxF -- "$root")
  noun=windows; (( count == 1 )) && noun=window
  plain="▸ ${name}${branch:+  ⎇ $branch}  ($count $noun)"
  colored="${accent}▸${reset} ${bold}${cream}${name}${reset}${branch:+  ${grey}⎇ ${branch}${reset}}  ${dark}(${count} ${noun})${reset}"
else
  plain=$1; colored=$1
fi

if [[ $style == bar ]]; then
  # shown by tmux-axolotl's 'toast' segment; a newer toast supersedes an older timer
  id=$RANDOM$RANDOM
  tmux set-option -g @workspaces-toast-text "$plain" ';' set-option -g @workspaces-toast-id "$id" ';' refresh-client -S 2>/dev/null
  (
    sleep "$duration"
    if [[ $(tmux show-option -gqv @workspaces-toast-id) == "$id" ]]; then
      tmux set-option -g @workspaces-toast-text "" ';' refresh-client -S 2>/dev/null
    fi
  ) >/dev/null 2>&1 &
  disown
  exit 0
fi

if [[ $style == message ]]; then
  tmux display-message -d 1500 "$plain"
  exit 0
fi

tmux display-popup -E -x R -y 0 -w $(( ${#plain} + 4 )) -h 3 -b rounded -S "fg=$border" \
  -e "TOAST=$colored" -e "TOAST_DURATION=$duration" -e "TOAST_DIR=$(dirname "${BASH_SOURCE[0]}")" \
  "bash '$(dirname "${BASH_SOURCE[0]}")/toast-body.sh'"
