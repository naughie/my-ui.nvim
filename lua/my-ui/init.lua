local M = {}

local states = require("my-ui.states")
local config = require("my-ui.config")
local ui = require("my-ui.ui")

local api = vim.api

local augroup = api.nvim_create_augroup("NaughieMyui", { clear = true })

-- path should be `vim.fn.fnameescape`d before call
function M.open_file_into_current_win(path, force)
    if force then
        vim.cmd("edit! " .. path)
    else
        vim.cmd("edit " .. path)
    end
end

-- path should be `vim.fn.fnameescape`d before call
function M.focus_on_last_active_win()
    return states.last_active_win.focus()
end

-- path should be `vim.fn.fnameescape`d before call
function M.open_file_into_last_active_win(path, force)
    if states.last_active_win.focus() then
        M.open_file_into_current_win(path, force)
        return true
    end
end

function M.focus_on_last_active_ui()
    return states.ui_stack.focus()
end

function M.inspect_ui_stack(tab)
    return states.ui_stack.inspect(tab)
end

function M.declare_ui(user_opts)
    local opts = vim.tbl_deep_extend("force", vim.deepcopy(config.default_opts), user_opts or {})
    return ui.declare_ui(opts)
end

M.close_all = ui.close_all

api.nvim_create_autocmd("WinLeave", {
    group = augroup,
    callback = function()
        local win = api.nvim_get_current_win()
        if not win or states.ui_win_table.contains(win) then return end
        states.last_active_win.set(win)
    end,
})

return M
