local M = {}

local bg = require("my-ui.bg")
local states = require("my-ui.states")

local mkstate = require("glocal-states")
local api = vim.api

local augroup = api.nvim_create_augroup("NaughieMyuiUiCloseBg", { clear = true })

local function open_float_with(buf, geom, win_id_state)
    local new_win = api.nvim_open_win(buf, true, {
        relative = "editor",
        width = geom.width,
        height = geom.height,
        col = geom.col,
        row = geom.row,
        style = "minimal",
        border = "none",
        focusable = false,
    })

    local old_win = win_id_state.set(new_win)

    states.ui_win_table.insert(new_win)

    api.nvim_create_autocmd("WinClosed", {
        group = augroup,
        pattern = tostring(new_win),
        callback = function()
            win_id_state.clear_if(function(value)
                return value == new_win
            end, tab)
            states.ui_win_table.remove(new_win)
        end,
    })

    return new_win, old_win
end

local function create_buf_with(buf_id_state)
    if buf_id_state.get() then return end

    local new_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(new_buf, "bufhidden", "hide")
    buf_id_state.set(new_buf)

    return new_buf
end

function M.configure(ui)
    ui.bg_states = {
        buf_id = mkstate.tab(),
        win_id = mkstate.tab(),
        bg = mkstate.tab(),
        hl_ns = mkstate.tab(),
    }

    local internal_api = {}

    internal_api.open = function(fg_geom, bg_opts)
        create_buf_with(ui.bg_states.buf_id)
        local buf = ui.bg_states.buf_id.get()
        if not buf then return end

        local bg_buf = bg.build(bg_opts.pat, fg_geom)
        ui.bg_states.bg.set(bg_buf)

        api.nvim_buf_set_lines(buf, 0, -1, false, bg_buf.lines)

        local win = open_float_with(buf, bg_buf, ui.bg_states.win_id)

        local ns = api.nvim_create_namespace("")
        api.nvim_win_set_hl_ns(win, ns)
        ui.bg_states.hl_ns.set(ns)

        bg.define_tick_highlight(ns, bg_opts.hl_group_on_focus)

        bg.add_highlight(bg_buf, buf, bg_opts.hl_group, bg_opts.hl_group_on_focus)
    end

    internal_api.delete_focus = function(tab)
        local buf = ui.bg_states.buf_id.get(tab)
        if not buf then return end
        bg.clear_focus_highlight(buf)
    end

    internal_api.redraw = function(bg_opts)
        local buf = ui.bg_states.buf_id.get()
        if not buf then return end

        local bg_buf = ui.bg_states.bg.get()
        if not bg_buf then return end

        local win, old_win = open_float_with(buf, bg_buf, ui.bg_states.win_id)
        local ns = ui.bg_states.hl_ns.get()
        if not ns then return end
        api.nvim_win_set_hl_ns(win, ns)

        bg.add_highlight(bg_buf, buf, bg_opts.hl_group, bg_opts.hl_group_on_focus)

        if old_win and api.nvim_win_is_valid(old_win) then api.nvim_win_close(old_win, true) end
    end

    internal_api.close = function(tab)
        local win = ui.bg_states.win_id.get(tab)
        ui.bg_states.win_id.clear(tab)
        if win and api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    end

    return internal_api
end

return M
