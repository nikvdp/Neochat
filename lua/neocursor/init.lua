local M = {}
-- Module-level variables
M.side = "L"
M.bufname = "neocursor"

local Job = require "plenary.job"
local async = require("plenary.async")
local await = async.await
local async_void = async.void
local GetVisualSelection = require("neocursor.util").GetVisualSelection

function Aichat(input, options)
    local output = ""
    local stderr_output = ""

    options = options or {}
    options.sync = options.sync or true
    options = {
        args = options.args or {},
        timeout = options.timeout or 30000,
        on_stdout = options.on_stdout or function(err, data)
                print("OUTPUT! " .. data)
                output = output .. data
            end,
        on_stderr = options.on_stderr or function(err, data)
                stderr_output = stderr_output .. data
            end
    }

    local job =
        Job:new {
        command = "aichat",
        args = options.args,
        writer = input,
        on_stdout = options.on_stdout,
        on_stderr = options.on_stderr
    }

    job:start()
    if options.sync then
        job:wait(options.timeout)
    end

    return output
end

function AichatSelectedText(prompt)
    local selected_text = GetVisualSelection()
    local output = Aichat(prompt, selected_text)

    vim.cmd("normal! gv" .. "d")
    vim.cmd("normal! i" .. output)
end

-- Function to convert text to lines
local function text_to_lines(text)
    local lines
    if type(text) == "string" then
        lines = vim.split(text, "\n", true)
    elseif type(text) == "table" then
        for i, v in ipairs(text) do
            if type(v) ~= "string" then
                error("Invalid line type at index " .. i .. ": expected string, got " .. type(v))
            end
        end
        lines = text
    else
        error("Invalid argument type: " .. type(text))
    end
    return lines
end

-- Function to create or get an existing buffer
function M.get_buffer()
    local bufnr = vim.fn.bufnr(M.bufname)
    if bufnr == -1 then
        vim.cmd("vnew " .. M.bufname)
        bufnr = vim.api.nvim_get_current_buf()
    end
    return bufnr
end

-- Function to display a buffer in a window
function M.display_buffer()
    local winnr = vim.fn.bufwinnr(M.bufname)
    if winnr == -1 then
        vim.cmd("vsplit " .. M.bufname)
    else
        vim.cmd(winnr .. "wincmd w") -- focus window
    end
    vim.cmd("wincmd " .. M.side) -- Move the window to the side
end

-- Function to set the width of a window
function M.set_window_width(percentage)
    local width = math.floor(vim.o.columns * percentage)
    vim.api.nvim_win_set_width(0, width)
end

-- Function to append text to a buffer
function M.append_to_buffer(bufnr, text)
    local lines = text_to_lines(text)
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, true, lines)
end

-- Function to replace the contents of a buffer
function M.replace_buffer_contents(bufnr, text)
    local lines = text_to_lines(text)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

-- High-level function to append text to a buffer
function M.open_buffer_with_text(text)
    local bufnr = M.get_buffer()
    M.display_buffer()
    M.set_window_width(0.2)
    if M.buf_empty() then
        -- text = "empty " .. tostring(#vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
        M.replace_buffer_with_text(text)
    else
        -- text = "not empty " .. tostring(#vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
        M.append_to_buffer(bufnr, text)
    end
end

function M.buf_empty()
    local bufnr = M.get_buffer()
    return #table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) == 0
end

function M.clear_buffer()
    local bufnr = M.get_buffer()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
end

-- High-level function to replace the contents of a buffer
function M.replace_buffer_with_text(text)
    local bufnr = M.get_buffer()
    M.display_buffer()
    M.set_window_width(0.2)
    M.replace_buffer_contents(bufnr, text)
end


local append_to_buffer_async = -- TODO: delete?
    async_void(
    function(bufnr, text)
        local lines = text_to_lines(text)
        vim.schedule(
            function()
                vim.api.nvim_buf_set_lines(bufnr, -1, -1, true, lines)
                vim.cmd.redraw()
            end
        )
    end
)

local AichatToBuffer = -- TODO: delete?
    async_void(
    function(input, options)
        local accumulated_output = {}
        local bufnr = M.get_buffer()
        M.clear_buffer()
        -- M.replace_buffer_with_text("")
        options = options or {sync = false}
        options.on_stdout = function(err, data)
            if data and data:match("%S") then
                table.insert(accumulated_output, data)
                vim.schedule(
                    function()
                        M.open_buffer_with_text(data)
                    end
                )
                print("::: " .. data)
            end
        end
        Aichat(input, options)
    end
)

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
