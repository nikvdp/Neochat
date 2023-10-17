local M = {}

function SendToReplTerm(repl_term_chan_id, options)
    if type(options) == "string" then
        options = {text_to_send = options}
    end
    options = options or {}
    local text_to_send = options.text_to_send or ""
    local use_bracketed_paste = options.use_bracketed_paste
    if use_bracketed_paste == nil then
        use_bracketed_paste = true
    end
    local add_extra_newline_to_bracketed_paste = options.add_extra_newline_to_bracketed_paste
    if add_extra_newline_to_bracketed_paste == nil then
        add_extra_newline_to_bracketed_paste = true
    end
    local use_rails_console_extra_newlines = options.use_rails_console_extra_newlines or false

    local to_send = text_to_send
    if to_send == "" then
        to_send = GetVisualSelection()
    end

    if #vim.split(to_send, "\n") == 1 or not use_bracketed_paste then
        vim.fn.chansend(repl_term_chan_id, to_send .. "\r")
    else
        local bracketed_paste_start = "\27[200~"
        local bracketed_paste_end = "\27[201~\r"
        local join_chr = use_rails_console_extra_newlines and "\r" or ""
        to_send = {bracketed_paste_start, to_send, bracketed_paste_end}
        if add_extra_newline_to_bracketed_paste and not string.match(to_send[2], "[\n\r]$") then
            to_send[2] = to_send[2] .. "\r"
        end
        vim.fn.chansend(repl_term_chan_id, table.concat(to_send, join_chr))
    end
end

local Job = require "plenary.job"

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

function GetVisualSelection()
    -- from https://stackoverflow.com/a/47051271
    local line_start, column_start, line_end, column_end
    if vim.fn.mode() == "v" then
        line_start, column_start = unpack(vim.fn.getpos("v"), 2)
        line_end, column_end = unpack(vim.fn.getpos("."), 2)
    else
        line_start, column_start = unpack(vim.fn.getpos("'<"), 2)
        line_end, column_end = unpack(vim.fn.getpos("'>"), 2)
    end
    if (vim.fn.line2byte(line_start) + column_start) > (vim.fn.line2byte(line_end) + column_end) then
        line_start, column_start, line_end, column_end = line_end, column_end, line_start, column_start
    end
    local lines = vim.fn.getline(line_start, line_end)
    if #lines == 0 then
        return ""
    end
    lines[#lines] = lines[#lines]:sub(1, column_end)
    lines[1] = lines[1]:sub(column_start)
    return table.concat(lines, "\n")
end

function entry(prompt)
    local msg = "prompt was: " .. prompt .. "\n"
    msg = msg .. "selection was: " .. GetVisualSelection() .. "\n"
    open_buffer_with_text(msg)
end


-- Module-level variables
M.side = "L"
M.bufname = "cursed.nvim"

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

local async = require("plenary.async")
local await = async.await
local async_void = async.void

local append_to_buffer_async =
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

local AichatToBuffer =
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

return M
