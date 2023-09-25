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

local opts = {
    width = 100,
    height = 70,
    border = borders.rounded_corners_border,
    title = { "aichat" },
    content = function()
        -- vim.cmd("start | term cat")
        -- vim.cmd("start | term aichat")
        vim.cmd("term aichat")
              -- 1116
        local bufnr = vim.api.nvim_get_current_buf()
        -- vim.wait(5000, function()
        --     return #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) >= 2
        -- end)
        vim.wait(5000, function()
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            for _, line in ipairs(lines) do
                if line:find("Welcome to aichat") then
                    return true
                end
            end
            return false
        end)

        -- vim.wait(1000)

        SendToReplTerm(vim.b.terminal_job_id, "hello there")
        -- vim.g.repl_term_id = vim.b.terminal_job_id
        -- vim.fn.chansend(vim.b.terminal_job_id, "hello\n")
        -- vim.wait(500)
        -- vim.fn.chansend(vim.b.terminal_job_id, "\n")
        -- vim.fn.SendToReplTerm(vim.b.terminal_job_id, "heyo!!")
    end
}

popcorn:new(opts):pop()
