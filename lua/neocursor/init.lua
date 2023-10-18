local M = {}
-- Module-level variables
M.side = "L" -- wincmd sides: H, J, K, or L
M.bufname = "neocursor"

local Job = require "plenary.job"
local async = require("plenary.async")
local await = async.await
local async_void = async.void
local GetVisualSelection = require("neocursor.util").GetVisualSelection
local vimecho = require("neocursor.util").vimecho

function M.Aichat(input)
    vim.cmd("wincmd n")
    vim.cmd("wincmd L")
    local bufnr = vim.api.nvim_get_current_buf()

    local input_file = "/tmp/aichat_input"
    local script_file = "/tmp/aichat_script.sh"
    local file = io.open(input_file, "w")
    file:write(input)
    file:close()

    -- write a small wrapper script to run the aichat command to
    -- pass the input file to aichat over stdin and give a different
    -- exit status depending on if user hits Y or N after the result
    local script =
        [==[
#!/bin/bash
aichat < "]==] ..
    input_file ..
        [==["
cols="$(tput cols)"
msg="Keep Y/N? "
y_color=$(tput setaf 2)
n_color=$(tput setaf 1)
reset_color=$(tput sgr0)
msg_colorized="Keep ${y_color}Y${reset_color}/${n_color}N${reset_color}? "
padding=$((($cols - ${#msg}) / 2))
printf "%${padding}s" ""
echo -n -e "$msg_colorized"
while true; do
    read -r -n 1 key
    if test "$key" == "Y" || test "$key" == "y"; then
        exit 0
    elif test "$key" == "N" || test "$key" == "n"; then
        exit 1
    fi
done
]==]

    file = io.open(script_file, "w")
    file:write(script)
    file:close()

    local term_id =
        vim.fn.termopen(
        "bash " .. script_file,
        {
            on_exit = function(job_id, exit_code, event)
                if exit_code == 0 then
                    -- print("Y!!")
                    vimecho("Y!")
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

function M.aichat_wrapper(args)
    if args == "" then
        if vim.fn.mode() == "v" or vim.fn.mode() == "V" or vim.fn.mode() == "^V" then
            -- Visual mode and no args
            M.Aichat(GetVisualSelection())
        else
            -- No args and not in visual mode
            M.Aichat()
        end
    else
        -- Args provided
        M.Aichat(args)
    end
end

vim.cmd([[
  command! -nargs=* -range Aichat lua require'neocursor'.aichat_wrapper(<q-args>)
]])

return M
