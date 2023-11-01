local M = {}
-- Module-level variables
M.plugin_name = "neochat"

local util = require "neochat.util"
local GetVisualSelection = util.GetVisualSelection
local GetVisualSelectionLineNos = util.GetVisualSelectionLineNos
local vimecho = util.vimecho -- for debugging

-- initialize and set config for neocursor
function M.init(cfg)
    local default_cfg = {
        side = "L",
        openai_key = M.get_openai_api_key(),
        cmd_name = "Neochat",
        buf_name = string.format("%s_buf", M.plugin_name)
    }
    cfg = cfg or default_cfg
    for key, value in pairs(default_cfg) do
        if cfg[key] ~= nil then
            M[key] = cfg[key]
        else
            M[key] = value
        end
    end
    M.set_vim_cmds(M.cmd_name)
    M.ensure_aichat_bin_installed()
end

function M.gen_aichat_wrapper_script(input_file, options)
    local message = options.message or "Keep"
    return util.dedent(
        string.format(
            [==[
                #!/bin/bash
                aichat < "%s"
                cols="$(tput cols)"
                msg="%s"
                y_color=$(tput setaf 2)
                n_color=$(tput setaf 1)
                reset_color=$(tput sgr0)
                msg_colorized="${msg} ${y_color}Y${reset_color}/${n_color}N${reset_color}? "
                padding=$((($cols - ${#msg}) / 2))
                printf "%%${padding}s" ""
                echo
                echo -n -e "$msg_colorized"
                while true; do
                    read -r -n 1 key
                    if test "$key" == "Y" || test "$key" == "y"; then
                        exit 0
                    elif test "$key" == "N" || test "$key" == "n"; then
                        exit 1
                    fi
                done
                ]==],
            input_file,
            message
        )
    )
end

function M.get_openai_api_key()
    local key = vim.fn.getenv("OPENAI_API_KEY")
    if not key or key == vim.NIL then
        return nil
    end
    return key
end

function M.create_tmp_aichat_dir(options)
    options = options or {}
    local tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")
    local openai_key = options.openai_key or M.get_openai_api_key()
    local model = options.model or "gpt-4"
    local config_yml =
        string.format(
        util.dedent(
            [==[
                api_key: "%s"
                model: "%s"
                save: true
                highlight: true 
                temperature: 0
                light_theme: true
                conversation_first: true
            ]==]
        ),
        openai_key,
        model
    )
    local cfg_file = io.open(util.join_path(tmp_dir, "config.yaml"), "w")
    cfg_file:write(config_yml)
    cfg_file:close()
    return tmp_dir
end

function M.write_to_file(filename, content)
    local file = io.open(filename, "w")
    file:write(content)
    file:close()
end

function M.is_aichat_active()
    if M.aichat_buf and M.aichat_term_id then
        return true
    end
end

function M.Aichat(input)
    if not M.get_openai_api_key() then
        vimecho("Please set $OPENAI_API_KEY first!")
        return nil
    end

    local start_line, end_line = GetVisualSelectionLineNos()
    local bufnr = vim.api.nvim_get_current_buf()
    local script, script_file, input_file, output_file

    local aichat_cfg_dir = M.create_tmp_aichat_dir()
    vim.fn.setenv("AICHAT_CONFIG_DIR", aichat_cfg_dir)
    script_file = "/tmp/aichat_script.sh"

    if input then
        input_file = "/tmp/aichat_input"
        output_file = util.join_path(aichat_cfg_dir, "messages.md")
        script = M.gen_aichat_wrapper_script(input_file, {message = "Replace original selection with above"})
        M.write_to_file(input_file, input)
    else
        script = [[
#!/bin/bash
exec aichat]]
    end

    M.write_to_file(script_file, script)
    vim.cmd("wincmd n")
    M.aichat_buf = vim.api.nvim_get_current_buf()
    vim.cmd(string.format("wincmd %s", M.side))

    local term_id =
        vim.fn.termopen(
        "bash " .. script_file,
        {
            on_exit = function(job_id, exit_code, event)
                M.aichat_buf = nil
                M.aichat_term_id = nil
                if input and exit_code == 0 then
                    local output = M.extract_last_backtick_value(M.get_last_aichat_response(output_file))
                    M.replace_lines(start_line, end_line, output, bufnr)
                    local orig_win = M.get_visible_window_number(bufnr)
                    M.indent_lines(start_line, end_line, orig_win)
                end

                -- clean up temporary files
                os.remove(input_file)
                os.remove(script_file)
                util.rmdir(aichat_cfg_dir)

                vim.api.nvim_buf_delete(aichat_buf, {force = true})
            end,
            stdout_buffered = true,
            stderr_buffered = true
        }
    )

    if not M.aichat_buf then
        vim.api.nvim_buf_set_name(M.aichat_buf, M.buf_name)
    end
    M.aichat_term_id = term_id
    return term_id
end

--- Indents lines in a specified window.
--
-- @param start_line The line to start indenting from.
-- @param end_line The line to end indenting at.
-- @param win_num The window number to perform the indentation in.
-- @param options A table of options. Can contain one optional value 'focus_win'. If 'focus_win' is true (which is the default), the function will focus on the specified window. If 'focus_win' is false, the function will return to the originating window after the indentation is complete.
-- @return nil
function M.indent_lines(start_line, end_line, win_num, options)
    options = options or {focus_win = true}
    local win_id = M.get_window_id(win_num)
    vim.cmd(string.format("%swincmd w", win_num))

    -- indent the lines by visually selecting them, (using <num>G)
    -- and then hitting =
    vim.cmd(string.format("normal! %sGV%sG=", start_line, end_line))

    if not options.focus_win then
        vim.cmd("wincmd p")
    end
end

function M.get_window_id(win_number)
    -- Get the list of windows
    local windows = vim.api.nvim_tabpage_list_wins(0)

    -- Iterate over each window
    for _, win in ipairs(windows) do
        -- If the window number matches the given window number, return the window id
        if vim.api.nvim_win_get_number(win) == win_number then
            return win
        end
    end

    -- If no matching window number was found, return nil
    return nil
end

function M.get_visible_window_number(buffer_id)
    -- Get the list of windows in the current tab
    local windows = vim.api.nvim_tabpage_list_wins(0)

    -- Iterate over each window
    for _, win in ipairs(windows) do
        -- Get the buffer id for the current window
        local buf = vim.api.nvim_win_get_buf(win)

        -- If the buffer id matches the given buffer id, return the window number
        if buf == buffer_id then
            return vim.api.nvim_win_get_number(win)
        end
    end

    -- If no matching buffer id was found, return nil
    return nil
end

function M.replace_lines(start_line, end_line, new_lines, bufnr)
    bufnr = bufnr or 0 -- use the current buffer if none is specified
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, vim.split(new_lines, "\n"))
end

function M.aichat_wrapper(args, is_visual_mode)
    local selection = GetVisualSelection()
    if args == nil or args == "" then
        if string.len(selection) and is_visual_mode then
            -- there is a visual selection, so use that as the input
            local chan_id = M.Aichat()
            -- not ideal, but the defer is needed to prevent the input from
            -- getting pasted above the aichat chession
            vim.defer_fn(
                function()
                    util.SendToTerm(
                        chan_id,
                        {
                            text_to_send = string.format(
                                util.dedent(
                                    [[
                            Please explain the following code: 

                            ```
                            %s
                            ```
                                    ]]
                                ),
                                selection
                            ),
                            -- use_bracketed_paste = false,
                            curly_wrap = true
                        }
                    )
                end,
                500
            )
        else
            -- No args and not in visual mode, so just open up a chat win
            M.Aichat()
        end
    else
        if string.len(selection) then
            -- In visual mode and args were provided, so marshall the visually selected
            -- text into the prompt

            local prompt =
                string.format(
                util.dedent(
                    [[
            You are a coding expert. I will provide you with code and instructions, 
            reply with the updated code and nothing else. Do not provide any 
            explanation or commentary. Make sure to use a markdown block with 
            language indicated (eg ```python)

            Code:
            ```
            %s
            ```

            Instruction:
            ```
            %s
            ```
                    ]]
                ),
                GetVisualSelection(),
                args
            )

            M.Aichat(prompt)
        else
            -- Args provided, but no visual mode, so just start aichat
            -- with the provided prompt
            M.Aichat(args)
        end
    end
end

-- return the contents of the last backtick enclosed chunk from
-- the given markdown
function M.extract_last_backtick_value(content)
    local last_block = nil
    local pattern = "```.-\n(.-)```"

    for block in string.gmatch(content, pattern) do
        last_block = block
    end

    local function trim(s)
        return s:match "^%s*(.-)%s*$"
    end

    local output
    if last_block then
        output = last_block
    else
        output = content
    end
    return trim(output)
end

function M.read_file(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return nil
    end

    local content = file:read("*all")
    file:close()

    return content
end

function M.extract_markdown_content(file_path)
    local content = M.read_file(file_path)
    if not content then
        return nil
    end

    return M.extract_last_backtick_value(content)
end

function M.get_last_aichat_response(file_path)
    local file = io.open(file_path, "r")
    local lines = {}
    local block = {}
    local block_delim = "--------"

    for line in file:lines() do
        table.insert(lines, line)
    end

    file:close()

    local started_block = false
    local ended_block = false
    -- iterate through the messages.md file in reverse and extract the contents
    -- of the last block
    for i = #lines, 1, -1 do
        local line = lines[i]
        if started_block and not ended_block then
            table.insert(block, line)
        end
        if line == block_delim then
            if not started_block then
                started_block = true
            else
                ended_block = true
                table.remove(block)
                break
            end
        end
    end

    local text = table.concat(util.reverse_array(block), "\n")
    return text
end

function M.ensure_aichat_bin_installed()
    local version_number = "v0.8.10"
    local base_url =
        string.format("https://github.com/nikvdp/aichat/releases/download/%s/aichat-%s", version_number, version_number)

    -- Determine OS and architecture
    local os = vim.loop.os_uname().sysname
    local arch = vim.loop.os_uname().machine

    -- Construct download URL
    local aichat_url
    if os == "Linux" and arch == "x86_64" then
        aichat_url = base_url .. "-x86_64-unknown-linux-musl.tar.gz"
    elseif os == "Linux" and arch == "aarch64" then
        aichat_url = base_url .. "-aarch64-unknown-linux-musl.tar.gz"
    elseif os == "Darwin" and arch == "x86_64" then
        aichat_url = base_url .. "-x86_64-apple-darwin.tar.gz"
    elseif os == "Darwin" and arch == "arm64" then
        aichat_url = base_url .. "-aarch64-apple-darwin.tar.gz"
    else
        print("Unsupported OS or architecture.")
        return
    end

    -- Get the path to Neovim's data directory
    local data_dir = vim.fn.stdpath("data")

    -- Create 'aichat' directory inside the data directory
    local aichat_dir = data_dir .. "/aichat"
    vim.fn.mkdir(aichat_dir, "p")

    -- Check if 'aichat' is already downloaded
    if vim.loop.fs_stat(aichat_dir .. "/aichat") then
        -- print("'aichat' is already downloaded.")
    else
        -- print("'aichat' has been downloaded and made executable.")
        vim.api.nvim_echo(
            {{string.format("[%s]: downloading 'aichat' binary...", M.plugin_name), "Question"}},
            false,
            {}
        )

        -- Download 'aichat' from the specified URL
        vim.fn.system("curl -L -o " .. aichat_dir .. "/aichat.tar.gz " .. aichat_url)

        -- Extract 'aichat' and make it executable
        vim.fn.system("tar -xzf " .. aichat_dir .. "/aichat.tar.gz -C " .. aichat_dir)
        vim.fn.system("chmod +x " .. aichat_dir .. "/aichat")

        vim.api.nvim_echo(
            {{string.format("[%s]: downloading 'aichat' binary... DONE", M.plugin_name), "Question"}},
            false,
            {}
        )
    end

    -- Add 'aichat' directory to PATH for this vim session
    vim.env.PATH = vim.env.PATH .. ":" .. aichat_dir
end

function M.set_vim_cmds(cmd_root)
    -- the line1 =~ line2 is a hack to detect if a range was passed in or not.
    -- when a range is passed in vim sets line1 and line2 to the line numbers of the
    -- range. unfortunately there doesn't seem to be a better way to do this
    cmd_root = cmd_root:sub(1, 1):upper() .. cmd_root:sub(2) -- ensure cmd_root is capitalized
    local set_cmd_cmd =
        string.format(
        [[
    command! -nargs=* -range %s lua require'%s'.aichat_wrapper(<q-args>, <line1> ~= <line2>)
    ]],
        cmd_root,
        M.plugin_name
    )
    vim.cmd(set_cmd_cmd)
end

M.init()

return M
