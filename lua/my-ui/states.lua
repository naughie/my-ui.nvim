local M = {}

local mkstate = require("glocal-states")

local last_active_win = mkstate.tab()
local ui_stack = mkstate.tab()

local ui_win_table = {}
local all_ui = {}

local api = vim.api

local function ui_stack_push(win, tab)
    local stack = ui_stack.get(tab)
    if stack then
        table.insert(stack, win)
    else
        ui_stack.set({ win }, tab)
    end
end
local function ui_stack_remove(win, tab)
    local stack = ui_stack.get(tab)
    if not stack or #stack == 0 then return end

    local found_index = nil
    for i = 1, #stack do
        if stack[i] == win then
            found_index = i
            break
        end
    end
    if not found_index then return end
    table.remove(stack, found_index)
end
local function ui_stack_move_last(win, tab)
    ui_stack_remove(win, tab)
    local stack = ui_stack.get(tab)
    if stack then
        table.insert(stack, win)
    else
        ui_stack.set({ win }, tab)
    end
end

local function inspect_ui_stack(tab)
    return ui_stack.get(tab)
end

M.last_active_win = {
    set = function(win, tab)
        last_active_win.set(win, tab)
    end,

    focus = function()
        local win = last_active_win.get()
        if not win or not api.nvim_win_is_valid(win) then return end

        api.nvim_set_current_win(win)
        return true
    end,
}

M.ui_stack = {
    push = ui_stack_push,
    remove = ui_stack_remove,
    move_last = ui_stack_move_last,

    focus = function()
        local stack = ui_stack.get()
        if not stack or #stack == 0 then return end
        local win = stack[#stack]
        if not api.nvim_win_is_valid(win) then return end

        api.nvim_set_current_win(win)
        return true
    end,

    inspect = function(tab)
        vim.inspect(ui_stack.get(tab))
    end,
}

M.ui_win_table = {
    insert = function(win)
        ui_win_table[win] = true
    end,

    remove = function(win)
        ui_win_table[win] = nil
    end,

    contains = function(win)
        return ui_win_table[win]
    end,
}

M.all_ui = {
    insert = function(ui)
        table.insert(all_ui, ui)
    end,

    iter = function()
        return ipairs(all_ui)
    end,
}

return M
