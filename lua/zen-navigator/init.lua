-- zen-navigator.nvim — seamless Ctrl-hjkl navigation across nvim splits and ZenTerm panes.
--
-- Detection and hand-off both ride ZenTerm's nav socket (`$ZEN_SOCK`), addressing this pane
-- by its `$ZEN_PANE` token. When neither is set (not running under ZenTerm) every mapping
-- degrades to a plain `wincmd`, so the plugin is inert outside ZenTerm.
--
-- Protocol: docs/nvim-navigator-protocol.md in the zen-term repo.

local M = {}

local sock = vim.env.ZEN_SOCK
local pane = vim.env.ZEN_PANE

-- h/j/k/l → the direction names ZenTerm's socket expects.
local DIRECTIONS = { h = "left", j = "down", k = "up", l = "right" }

-- Running inside ZenTerm with a reachable nav socket?
local function under_zenterm()
  return sock ~= nil and sock ~= "" and pane ~= nil and pane ~= ""
end

-- Fire-and-forget one JSON command over the nav socket. Best-effort: any failure (socket
-- gone, ZenTerm not running) is swallowed so editing never breaks on a bad hand-off.
local function send(payload)
  if not under_zenterm() then
    return
  end
  -- No opts table: an empty Lua `{}` marshals to an empty *list*, and sockconnect
  -- rejects it with "E475: expected dictionary". Omitting it opens a raw byte channel.
  local ok, chan = pcall(vim.fn.sockconnect, "pipe", sock)
  if not ok or chan == 0 then
    return
  end
  pcall(vim.fn.chansend, chan, vim.fn.json_encode(payload) .. "\n")
  pcall(vim.fn.chanclose, chan)
end

-- Move within nvim; if already at the edge in that direction, hand off to ZenTerm so it
-- moves pane focus. The edge test is `vim-tmux-navigator`'s: the window number is unchanged
-- after `wincmd` exactly when there was nowhere to go.
function M.navigate(key)
  local from = vim.fn.winnr()
  vim.cmd("wincmd " .. key)
  if from == vim.fn.winnr() then
    send({ cmd = "focus", dir = DIRECTIONS[key], pane = tonumber(pane) })
  end
end

-- Advertise (or clear) nvim presence so ZenTerm's guard won't steal Ctrl-hjkl from this pane.
local function set_vim(on)
  send({ cmd = "setvim", pane = tonumber(pane), vim = on })
end

-- opts.default_mappings = false to bind Ctrl-hjkl yourself via require("zen-navigator").navigate.
function M.setup(opts)
  opts = opts or {}

  local group = vim.api.nvim_create_augroup("ZenNavigator", { clear = true })
  vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
    group = group,
    callback = function()
      set_vim(true)
    end,
  })
  vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
    group = group,
    callback = function()
      set_vim(false)
    end,
  })
  -- Lazy-loaded after VimEnter already fired: flag immediately so the guard is armed now.
  if vim.v.vim_did_enter == 1 then
    set_vim(true)
  end

  if opts.default_mappings ~= false then
    for key, dir in pairs(DIRECTIONS) do
      vim.keymap.set("n", "<C-" .. key .. ">", function()
        M.navigate(key)
      end, { silent = true, desc = "ZenNavigator: move " .. dir })
    end
  end
end

return M
