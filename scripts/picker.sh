#!/usr/bin/env bash
# Show the workspace tree in fzf and jump to the chosen window.
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=palette.sh
source "$dir/palette.sh"

# Ignore the user's global fzf options (height, margin, border...): they break the popup layout.
choice=$("$dir/list.sh" | FZF_DEFAULT_OPTS= fzf --ansi --no-sort --layout=reverse --no-border --info=inline-right \
  --delimiter=$'\t' --with-nth=2,4 \
  --prompt='  ' --pointer='▌' --marker='▌' \
  --header=$'enter jump · esc cancel · type to filter windows or repos\n' \
  --preview="'$dir/preview.sh' {1} {3}" --preview-window='right,45%,border-left,wrap' \
  --color="bg+:$(fzf_color "$P_SURFACE"),fg+:$(fzf_color "$P_TEXT"),hl:$(fzf_color "$P_ACCENT"),hl+:$(fzf_color "$P_ACCENT"),pointer:$(fzf_color "$P_ACCENT"),prompt:$(fzf_color "$P_ACCENT"),header:$(fzf_color "$P_MUTED"),info:$(fzf_color "$P_MUTED"),border:$(fzf_color "$P_MUTED"),gutter:-1") || exit 0

tmux select-window -t "${choice%%$'\t'*}"
