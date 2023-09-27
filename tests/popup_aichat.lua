local popcorn = require'popcorn'
local borders = require'popcorn.borders'

function SendToReplTerm(repl_term_chan_id, options)
    if type(options) == 'string' then
        options = { text_to_send = options }
    end
    options = options or {}
    local text_to_send = options.text_to_send or ''
    local use_bracketed_paste = options.use_bracketed_paste
    if use_bracketed_paste == nil then use_bracketed_paste = true end
    local add_extra_newline_to_bracketed_paste = options.add_extra_newline_to_bracketed_paste
    if add_extra_newline_to_bracketed_paste == nil then add_extra_newline_to_bracketed_paste = true end
    local use_rails_console_extra_newlines = options.use_rails_console_extra_newlines or false

    local to_send = text_to_send
    if to_send == '' then
        to_send = _G.GetVisualSelection()
    end

    if #vim.split(to_send, "\n") == 1 or not use_bracketed_paste then
        vim.fn.chansend(repl_term_chan_id, to_send .. "\r")
    else
        local bracketed_paste_start = "\27[200~"
        local bracketed_paste_end = "\27[201~\r"
        local join_chr = use_rails_console_extra_newlines and "\r" or ""
        to_send = { bracketed_paste_start, to_send, bracketed_paste_end }
        if add_extra_newline_to_bracketed_paste and not string.match(to_send[2], "[\n\r]$") then
            to_send[2] = to_send[2] .. "\r"
        end
        vim.fn.chansend(repl_term_chan_id, table.concat(to_send, join_chr))
    end
end

function AichatSelectedText(prompt)
    -- Get the current visual selection
    local selected_text = GetVisualSelection()

    -- Run the selected text through the tac command with the prompt argument
    local cmd = 'echo ' .. vim.fn.shellescape(selected_text) .. ' | aichat ' .. vim.fn.shellescape(prompt)
    local output = vim.fn.system(cmd)

    -- Replace the selected text with the output of the command
    vim.cmd("normal! gv" .. "d")
    vim.cmd("normal! i" .. output)
end

function GetVisualSelection()
    -- from https://stackoverflow.com/a/47051271
    local line_start, column_start, line_end, column_end
    if vim.fn.mode()=="v" then
        line_start, column_start = unpack(vim.fn.getpos("v"), 2)
        line_end, column_end = unpack(vim.fn.getpos("."), 2)
    else
        line_start, column_start = unpack(vim.fn.getpos("'<"), 2)
        line_end, column_end = unpack(vim.fn.getpos("'>"), 2)
    end
    if (vim.fn.line2byte(line_start)+column_start) > (vim.fn.line2byte(line_end)+column_end) then
        line_start, column_start, line_end, column_end = line_end, column_end, line_start, column_start
    end
    local lines = vim.fn.getline(line_start, line_end)
    if #lines == 0 then
        return ''
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

function open_buffer_with_text(text)
    -- Check if the buffer already exists
    local bufname = "mybuffer"
    local bufnr = vim.fn.bufnr(bufname)

    -- If the buffer does not exist, create it
    if bufnr == -1 then
        vim.cmd("vnew " .. bufname)
        bufnr = vim.api.nvim_get_current_buf()
    else
        -- If the buffer exists, make sure it's displayed in a window
        local winnr = vim.fn.bufwinnr(bufname)
        if winnr == -1 then
            vim.cmd("vsplit " .. bufname)
        else
            vim.cmd(winnr .. "wincmd w")
        end
    end

    -- Add the text to the buffer
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {text})
end

open_buffer_with_text("testing")
-- vim.api.nvim_command('command! -range=% -nargs=1 Aichat lua entry(<q-args>)')
-- vim.api.nvim_command('command! -range=% -nargs=1 Aichat lua AichatSelectedText(<q-args>)')
-- print(GetVisualSelection())

-- local opts = {
--     width = 100,
--     height = 70,
--     border = borders.rounded_corners_border,
--     title = { "aichat" },
--     content = GetVisualSelection()
--     -- content = function()
--     --     -- TODO: so in order to get what i want (have aichat stream the output) i think i need to:
--     --     --   1. write a wrapper script that will run aichat and pipe in the output
--     --     --   2. then i can run that script in a terminal
--     --     --   3. then i can use the wrapper script to prompt user if they want to send input back to neovim
--     --     vim.cmd("term aichat")
--     --     local bufnr = vim.api.nvim_get_current_buf()
--     --     -- vim.wait(5000, function()
--     --     --     return #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) >= 2
--     --     -- end)
--     --     vim.wait(5000, function()
--     --         local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
--     --         for _, line in ipairs(lines) do
--     --             if line:find("Welcome to aichat") then
--     --                 return true
--     --             end
--     --         end
--     --         return false
--     --     end)
--     --
--     --     -- vim.wait(1000)
--     --
--     --     SendToReplTerm(vim.b.terminal_job_id, "hello there")
--     --     -- vim.g.repl_term_id = vim.b.terminal_job_id
--     --     -- vim.fn.chansend(vim.b.terminal_job_id, "hello\n")
--     --     -- vim.wait(500)
--     --     -- vim.fn.chansend(vim.b.terminal_job_id, "\n")
--     --     -- vim.fn.SendToReplTerm(vim.b.terminal_job_id, "heyo!!")
--     -- end
-- }
--
-- popcorn:new(opts):pop()
--
--
