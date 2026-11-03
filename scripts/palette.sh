#!/usr/bin/env bash
# Source this. Sets P_ACCENT P_TEXT P_MUTED P_DARK P_SURFACE P_ACTIVE (tmux colour
# syntax) for the current client's colour tier. Inherits the palette published by
# tmux-axolotl (@axolotl-pal-<tier>-<name>) when present, otherwise falls back to
# the terminal's own ANSI colours.

_features=$(tmux display-message -p '#{client_termfeatures}|#{client_termname}' 2>/dev/null)
case $_features in
  *RGB*) P_TIER=rgb ;;
  *256*) P_TIER=256 ;;
  *)     P_TIER=ansi ;;
esac

_pal() { local v; v=$(tmux show-option -gqv "@axolotl-pal-$P_TIER-$1"); echo "${v:-$2}"; }
P_ACCENT=$(_pal accent yellow)
P_TEXT=$(_pal fg white)
P_MUTED=$(_pal muted brightblack)
P_DARK=$(_pal dark black)
P_SURFACE=$(_pal surface brightblack)
P_ACTIVE=$(_pal active brightblack)

# ANSI colour name -> 0-15
_ansi_num() {
  case $1 in
    black) echo 0;; red) echo 1;; green) echo 2;; yellow) echo 3;; blue) echo 4;;
    magenta) echo 5;; cyan) echo 6;; white) echo 7;;
    brightblack) echo 8;; brightred) echo 9;; brightgreen) echo 10;; brightyellow) echo 11;;
    brightblue) echo 12;; brightmagenta) echo 13;; brightcyan) echo 14;; brightwhite) echo 15;;
    *) return 1;;
  esac
}

# sgr_fg <tmux colour>: SGR parameters for a foreground colour
sgr_fg() {
  local c=$1 n h
  if [[ $c == default ]]; then echo 39
  elif [[ $c == \#* ]]; then h=${c#\#}; echo "38;2;$((16#${h:0:2}));$((16#${h:2:2}));$((16#${h:4:2}))"
  elif [[ $c == colour* || $c == color* ]]; then echo "38;5;${c//[!0-9]/}"
  elif n=$(_ansi_num "$c"); then (( n < 8 )) && echo "$((30 + n))" || echo "$((90 + n - 8))"
  else echo 39; fi
}

# fzf_color <tmux colour>: the colour in fzf's syntax
fzf_color() {
  local c=$1 n
  if [[ $c == default ]]; then echo -1
  elif [[ $c == \#* ]]; then echo "$c"
  elif [[ $c == colour* || $c == color* ]]; then echo "${c//[!0-9]/}"
  elif n=$(_ansi_num "$c"); then echo "$n"
  else echo -1; fi
}
