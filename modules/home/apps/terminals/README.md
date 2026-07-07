# terminals

Home Manager modules for terminal emulators.

| File | Description |
|---------|-----------|
| [`tmux.nix`](tmux.nix) | Terminal multiplexer with neovim integration |
| [`ghostty.nix`](ghostty.nix) | Ghostty terminal emulator |

---

## tmux — Keybindings

Configuration based on [Omarchy](https://github.com/basecamp/omarchy)'s defaults,
with neovim integration via `vim-tmux-navigator`.

**Prefix:** `Ctrl+Space` (alternate: `Ctrl+b`)
**Key mode:** vi
**Plugins:** `vim-tmux-navigator`, `yank`

### Navigation between panes / neovim splits

> Integration with neovim via `vim-tmux-navigator` — the same keybindings work
> inside neovim and between tmux panes with no distinction.

| Shortcut | Action |
|--------|------|
| `Ctrl+h` | Pane/split to the left |
| `Ctrl+j` | Pane/split below |
| `Ctrl+k` | Pane/split above |
| `Ctrl+l` | Pane/split to the right |
| `Ctrl+\` | Previous pane/split |

### Panes — create and close

| Shortcut | Action |
|--------|------|
| `Alt+Enter` | Split vertically (current directory) |
| `Alt+Shift+Enter` | Split horizontally (current directory) |
| `Alt+Escape` | Close current pane |
| `<prefix> h` | Split vertically (current directory) |
| `<prefix> v` | Split horizontally (current directory) |
| `<prefix> x` | Close current pane |

### Panes — navigate and resize

| Shortcut | Action |
|--------|------|
| `Ctrl+Alt+←` | Focus pane to the left |
| `Ctrl+Alt+→` | Focus pane to the right |
| `Ctrl+Alt+↑` | Focus pane above |
| `Ctrl+Alt+↓` | Focus pane below |
| `Ctrl+Alt+Shift+←` | Resize pane (−5 columns) |
| `Ctrl+Alt+Shift+→` | Resize pane (+5 columns) |
| `Ctrl+Alt+Shift+↑` | Resize pane (+5 rows) |
| `Ctrl+Alt+Shift+↓` | Resize pane (−5 rows) |

### Windows

| Shortcut | Action |
|--------|------|
| `<prefix> c` | New window (current directory) |
| `<prefix> r` | Rename current window |
| `<prefix> k` | Close current window |
| `Alt+1` … `Alt+9` | Jump directly to window N |
| `Alt+←` | Previous window |
| `Alt+→` | Next window |
| `Alt+Shift+←` | Move window to the left |
| `Alt+Shift+→` | Move window to the right |

### Sessions

| Shortcut | Action |
|--------|------|
| `<prefix> C` | New session (current directory) |
| `<prefix> R` | Rename current session |
| `<prefix> K` | Close current session |
| `<prefix> P` | Previous session |
| `<prefix> N` | Next session |
| `Alt+↑` | Previous session |
| `Alt+↓` | Next session |

### Copy mode (vi)

Enter copy mode: `<prefix> [`

| Shortcut | Action |
|--------|------|
| `v` | Start selection |
| `Ctrl+v` | Toggle rectangle selection |
| `y` | Copy selection to the system clipboard and exit |

### Configuration

| Shortcut | Action |
|--------|------|
| `<prefix> q` | Reload tmux configuration |
