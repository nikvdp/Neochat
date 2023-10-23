local util = {}

function util.SendToTerm(repl_term_chan_id, options)
    if type(options) == "string" then
        options = {text_to_send = options}
    end
    options = options or {}
    local text_to_send = options.text_to_send or ""
    local use_bracketed_paste = options.use_bracketed_paste
    local curly_wrap = options.curly_wrap or false
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
        if curly_wrap then 
            to_send = table.concat({"{", to_send, "}"}, "\n")
        end
        to_send = {bracketed_paste_start, to_send, bracketed_paste_end}
        if add_extra_newline_to_bracketed_paste and not string.match(to_send[2], "[\n\r]$") then
            to_send[2] = to_send[2] .. "\r"
        end
        vim.fn.chansend(repl_term_chan_id, table.concat(to_send, join_chr))
    end
end

function util.GetVisualSelectionLineNos()
    local line_start, line_end
    if vim.fn.mode() == "v" then
        line_start, line_end = vim.fn.getpos("v")[2], vim.fn.getpos(".")[2]
    else
        line_start, line_end = vim.fn.getpos("'<")[2], vim.fn.getpos("'>")[2]
    end
    return line_start, line_end
end

function util.GetVisualSelection()
    local line_start, line_end = util.GetVisualSelectionLineNos()
    local column_start, column_end

    if vim.fn.mode() == "v" then
        column_start, column_end = vim.fn.getpos("v")[3], vim.fn.getpos(".")[3]
    else
        column_start, column_end = vim.fn.getpos("'<")[3], vim.fn.getpos("'>")[3]
    end

    if (vim.fn.line2byte(line_start) + column_start) > (vim.fn.line2byte(line_end) + column_end) then
        column_start, column_end = column_end, column_start
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

-- dedent function similar to python's dedent. from [1], see license in [2]
-- [1]: https://dev.fandom.com/wiki/Module:Unindent
-- [2]: see LICENSES.txt in this folder
function util.dedent(str)
    str = str:gsub(" +$", ""):gsub("^ +", "") -- remove spaces at start and end
    local level = math.huge
    local minPrefix = ""
    local len
    for prefix in str:gmatch("\n( +)") do
        len = #prefix
        if len < level then
            level = len
            minPrefix = prefix
        end
    end
    return (str:gsub("\n" .. minPrefix, "\n"):gsub("\n$", ""))
end

--- Joins the given path segments into a single path.
-- The directory separator is determined based on the current system.
-- @param ... The path segments to join.
-- @return The joined path.
-- @usage
-- local path = path_join("/home", "user", "file.txt")
-- print(path)  -- Outputs: "/home/user/file.txt"
function util.join_path(...)
    return table.concat({...}, package.config:sub(1, 1))
end

function util.reverse_array(arr)
    local reversed = {}
    for i = #arr, 1, -1 do
        table.insert(reversed, arr[i])
    end
    return reversed
end

function util.rmdir(path)
    local handle, err = vim.loop.fs_scandir(path)
    if err then
        print("Cannot open directory: " .. err)
        return
    end
    if handle then
        for name, t in vim.loop.fs_scandir_next, handle do
            local file = path .. "/" .. name
            if t == "directory" then
                local ok, err = pcall(util.rmdir, file)
                if not ok then
                    print("Error removing directory '" .. file .. "': " .. err)
                end
            else
                local ok, err = pcall(vim.loop.fs_unlink, file)
                if not ok then
                    print("Error removing file '" .. file .. "': " .. err)
                end
            end
        end
        local ok, err = pcall(vim.loop.fs_rmdir, path)
        if not ok then
            print("Error removing directory '" .. path .. "': " .. err)
        end
    end
end

return util
