#!/usr/bin/env bash
# Runs inside the toast popup. Env: TOAST (colored text), TOAST_DURATION, TOAST_DIR.
# Any key closes the toast. S-Left / S-Right (xterm sequences) are handed off to
# step.sh so rapid presses keep stepping instead of being swallowed.
printf ' %b\n' "$TOAST"

IFS= read -rsn1 -t "$TOAST_DURATION" k || exit 0
if [[ $k == $'\e' ]]; then
  IFS= read -rsn5 -t 0.05 rest
  k+=$rest
fi

# Run after the popup has closed (a popup can't open from inside a popup).
case $k in
  $'\e[1;2C') tmux run-shell -b "sleep 0.1; '$TOAST_DIR/step.sh' next" ;;
  $'\e[1;2D') tmux run-shell -b "sleep 0.1; '$TOAST_DIR/step.sh' prev" ;;
esac
