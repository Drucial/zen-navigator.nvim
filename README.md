# zen-navigator.nvim

Seamless `Ctrl-h/j/k/l` navigation that walks across **Neovim splits** and
**[ZenTerm](https://github.com/Drucial/zen-term) panes** as one motion — like
`vim-tmux-navigator`, but for ZenTerm and backend-agnostic (works on ZenTerm's
default Ghostty backend, no process-probing).

Press `Ctrl-h` at the left edge of your Neovim splits and focus crosses into the
ZenTerm pane on the left. From a shell pane, `Ctrl-h` walks back into Neovim and
continues through its splits.

## How it works

Both detection and hand-off ride ZenTerm's nav socket (`$ZEN_SOCK`), which ZenTerm
injects into every pane along with a per-pane token (`$ZEN_PANE`):

- On `VimEnter`/`VimResume` the plugin tells ZenTerm this pane is running Neovim
  (and clears it on `VimLeave`/`VimSuspend`), so ZenTerm's key guard lets
  `Ctrl-hjkl` reach Neovim instead of moving pane focus.
- When Neovim is at its edge split and can't move further, it asks ZenTerm to
  move pane focus in that direction.

Outside ZenTerm (`$ZEN_SOCK`/`$ZEN_PANE` unset) every mapping degrades to a plain
`wincmd`, so the plugin is inert and harmless anywhere else.

## Requirements

- ZenTerm with the nvim navigator (ZEN-30) support.
- Neovim 0.7+ (uses `vim.keymap`, `vim.api.nvim_create_autocmd`).

## Install

Both sides opt in. **This is not a default rebind** — ZenTerm's default `⌘-hjkl`
pane nav is untouched.

### 1. The plugin

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Drucial/zen-navigator.nvim",
  event = "VeryLazy",
  opts = {},
}
```

Or with [packer](https://github.com/wbthomason/packer.nvim):

```lua
use({ "Drucial/zen-navigator.nvim", config = function() require("zen-navigator").setup() end })
```

### 2. ZenTerm keybinds

Bind `ctrl+hjkl` to pane nav in your ZenTerm keybind config so ZenTerm has
something to hand off — the plugin's guard only diverts a chord ZenTerm would
otherwise treat as nav:

```
ctrl+h = nav_left
ctrl+j = nav_down
ctrl+k = nav_up
ctrl+l = nav_right
```

## Configuration

```lua
require("zen-navigator").setup({
  -- Set false to bind Ctrl-hjkl yourself, calling require("zen-navigator").navigate("h").
  default_mappings = true,
})
```

## Caveats

- **Ctrl-hjkl is claimed when you opt in.** Non-Neovim TUIs (htop, less) in a
  shell pane lose those keys to pane nav, same tradeoff as tmux/kitty. ZenTerm's
  default `⌘-hjkl` never has this problem.
- **Stale flag on a hard Neovim crash.** The nvim flag clears on
  `VimLeave`/`VimSuspend`; a hard crash can leave it set, so `Ctrl-h` reaches the
  recovered shell (doing nothing) until it's reset. ZenTerm's `⌘-hjkl` fallback
  always works.

## Protocol

The socket contract lives in the ZenTerm repo at `docs/nvim-navigator-protocol.md`.
