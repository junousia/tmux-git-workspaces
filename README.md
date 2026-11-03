# tmux-git-workspaces

Group your tmux windows by git repository.

- A keyboard-driven **workspace tree** (`prefix + W`): git repos with their windows nested underneath, filterable, with a preview of the repo (branch, changes, recent commits, what each window is running).
- The **status bar window list is filtered** to the current workspace, so you only see the windows of the repo you're working in.

Windows outside any git repo are grouped together under a single `(no repo)` workspace.

## Requirements

- tmux 3.3+ (popup borders)
- [fzf](https://github.com/junegunn/fzf) and git
- bash

## Install

With [TPM](https://github.com/tmux-plugins/tpm), add this to your `~/.tmux.conf`:

```tmux
set -g @plugin 'junousia/tmux-git-workspaces'
```

Then press `prefix + I` to install.

**Plugin order matters.** The plugin wraps your theme's `window-status-format`, and how the theme sets it decides which order works. If the status bar isn't filtered, move the `@plugin` line to the other side of your theme plugin (with tmux2k, placing it *before* the theme worked).

## Usage

| Key | Action |
| --- | --- |
| `prefix + W` | Open the workspace tree. Type to filter by window or repo name, `enter` to jump. |
| `prefix + F` | Toggle the status bar filter (show all windows / only the current workspace). |

A short toast (`▸ homelab ⎇ main (3 windows)`) pops up in the top-right corner when you step into another workspace, and when you toggle the filter. It's a small popup, so any key dismisses it early (the key is swallowed).

Selecting a repo header jumps to that repo's first window. Switching windows any other way also switches the status bar to the workspace you land in.

## Stepping through windows

`next-window` / `previous-window` walk the windows by index, which also visits windows hidden by the filter and jumps between repos in an arbitrary order. The plugin can bind keys that step in **tree order** instead (each repo's windows together, repos in the order the tree shows them), wrapping around and crossing into the next workspace naturally. Crossing into another workspace shows a short toast with its name and branch.

```tmux
set -g @workspaces-next-key 'S-Right'   # bound without prefix
set -g @workspaces-prev-key 'S-Left'
```

## Options

```tmux
set -g @workspaces-key 'W'          # key for the workspace tree
set -g @workspaces-toggle-key 'F'   # key to toggle the status bar filter
set -g @workspaces-filter 'off'     # start with the filter disabled
set -g @workspaces-toast 'popup'    # popup (default) | message (status line) | off
```

## How it works

- Each window is tagged (`@workspace`) with the git root of its active pane. Tags refresh on window and focus hooks and every `status-interval`, so a window moves to another workspace shortly after you `cd` into a different repo.
- The plugin wraps your theme's `window-status-format` so windows from other workspaces render empty. The original format is kept in `@workspaces-orig-fmt`.

## Tips

New windows start in the session's start directory by default. To open them in the directory you're in, so they land in the same workspace:

```tmux
bind c new-window -c "#{pane_current_path}"
bind '"' split-window -v -c "#{pane_current_path}"
bind % split-window -h -c "#{pane_current_path}"
```

## Limitations

- Built for a single tmux session; the active workspace is stored globally.
- The built-in `next-window` / `previous-window` still cycle through hidden windows; use the stepping keys above for tree order.

## License

MIT
