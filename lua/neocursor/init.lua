local M = {}
-- Module-level variables
M.side = "L" -- wincmd sides: H, J, K, or L
M.bufname = "neocursor"

local Job = require "plenary.job"
local async = require("plenary.async")
local await = async.await
local async_void = async.void
local util = require "neocursor.util"
local GetVisualSelection = require("neocursor.util").GetVisualSelection
local GetVisualSelectionLineNos = require("neocursor.util").GetVisualSelectionLineNos
local vimecho = require("neocursor.util").vimecho

function M.gen_aichat_wrapper_script(input_file, output_file)
    return util.dedent(
        string.format( [==[
                #!/bin/bash
                aichat < "%s" | tee "%s"
                cols="$(tput cols)"
                msg="Keep Y/N? "
                y_color=$(tput setaf 2)
                n_color=$(tput setaf 1)
                reset_color=$(tput sgr0)
                msg_colorized="Keep ${y_color}Y${reset_color}/${n_color}N${reset_color}? "
                padding=$((($cols - ${#msg}) / 2))
                printf "%%${padding}s" ""
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
            output_file
        )
    )
end

function M.Aichat(input)
    local start_line, end_line = GetVisualSelectionLineNos()
    local bufnr = vim.api.nvim_get_current_buf()

    vim.cmd("wincmd n")
    vim.cmd("wincmd L")

    local input_file = "/tmp/aichat_input"
    local output_file = "/tmp/aichat_output"
    local script_file = "/tmp/aichat_script.sh"
    local file = nil
    local script = nil

    if input then
        script = M.gen_aichat_wrapper_script(input_file, output_file)
        file = io.open(input_file, "w")
        -- TODO: generate an alternate wrapper script that doesn't pass in user input
        file:write(input)
        file:close()
        local file = nil
        if input_file ~= nil then
            file = io.open(input_file, "w")
            file:write(input)
            file:close()
        end
    else
        script = [[
#!/bin/bash
exec aichat]]
    end

    file = io.open(script_file, "w")
    file:write(script)
    file:close()

    local term_id =
        vim.fn.termopen(
        "bash " .. script_file,
        {
            on_exit = function(job_id, exit_code, event)
                if exit_code == 0 then
                    local output = M.extract_markdown_content(output_file)
                    M.replace_lines(start_line, end_line, output, bufnr)
                else
                    -- print("NNN!!!")
                    vimecho("N :(")
                end
                os.remove(input_file) -- clean up temporary files
                os.remove(script_file)
            end,
            stdout_buffered = true,
            stderr_buffered = true
        }
    )
end

-- Function to replace specified lines in a specified buffer
function M.replace_lines(start_line, end_line, new_lines, bufnr)
    bufnr = bufnr or 0 -- use the current buffer if none is specified
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, vim.split(new_lines, "\n"))
end

function M.aichat_wrapper(args)
    local selection = GetVisualSelection()
    if args == nil or args == "" then
        -- No args and not in visual mode, so just open up a chat win
        M.Aichat()
    else
        if string.len(selection) then
            -- if vim.fn.mode() == "v" or vim.fn.mode() == "V" or vim.fn.mode() == "^V" then
            -- Visual mode and args, so marshall the visually selected
            -- text into the prompt
            local prompt =
                table.concat(
                {
                    "You are a coding expert. I will provide you with code and instructions, reply with the updated code and nothing else. Do no provide any explanation or commentary. Make sure to use a markdown block with language indicated (eg ```python)\n\n Code: \n\n```\n",
                    GetVisualSelection(),
                    "\n```\n\nInstruction: \n\n```\n",
                    args,
                    "\n```\n"
                }
            )

            M.Aichat(prompt)
        else
            -- Args provided, but no visual mode, so just start aichat
            -- with the provided prompt
            M.Aichat(args)
        end
    end
end

function M.get_buf_text(bufnr)
    -- bufnr is the buffer number. If nil, the current buffer is used.
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    -- Get the number of lines in the buffer
    local line_count = vim.api.nvim_buf_line_count(bufnr)

    -- Get all lines from the buffer
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line_count, false)

    -- Join all lines into a single string
    local text = table.concat(lines, "\n")

    return text
end

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

vim.cmd([[
  command! -nargs=* -range Aichat lua require'neocursor'.aichat_wrapper(<q-args>)
]])

return M
