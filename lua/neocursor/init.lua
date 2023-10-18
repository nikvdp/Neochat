local M = {}
-- Module-level variables
M.side = "L" -- wincmd sides: H, J, K, or L
M.bufname = "neocursor"

local Job = require "plenary.job"
local async = require("plenary.async")
local await = async.await
local async_void = async.void
local GetVisualSelection = require("neocursor.util").GetVisualSelection


function M.aichat_wrapper(args)
    if args == "" then
        Aichat(GetVisualSelection())
    else
        Aichat(args)
    end
end

vim.cmd([[
  command! -nargs=* Aichat lua require'neocursor'.aichat_wrapper(<q-args>)
]])

return M
