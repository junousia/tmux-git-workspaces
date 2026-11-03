#!/usr/bin/env bash
# Show the workspace tree in fzf and jump to the chosen window.
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

choice=$("$dir/list.sh" | fzf --ansi --no-sort --layout=reverse --no-border --info=inline-right \
  --delimiter=$'\t' --with-nth=2,4 \
  --prompt='  ' --pointer='▌' --marker='▌' \
  --header=$'enter jump · esc cancel · type to filter windows or repos\n' \
  --preview="'$dir/preview.sh' {1} {3}" --preview-window='right,45%,border-left,wrap' \
  --color='bg+:#3c3836,fg+:#ebdbb2,hl:#fabd2f,hl+:#fabd2f,pointer:#fe8019,prompt:#fe8019,header:#928374,info:#928374,border:#504945,gutter:-1') || exit 0

tmux select-window -t "${choice%%$'\t'*}"
