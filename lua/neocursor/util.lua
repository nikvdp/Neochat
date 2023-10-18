local util = {}

function util.SendToReplTerm(repl_term_chan_id, options)
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

function util.GetVisualSelection()
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

-- Function to convert text to a lua table of lines
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

function util.vimecho(text)
    vim.cmd([[echom "]] .. text .. [["]])
end

return util
