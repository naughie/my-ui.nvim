local M = {}

local mkstate = require("glocal-states")
local states = require("my-ui.states")
local bg = require("my-ui.bg")

local api = vim.api
local augroup = api.nvim_create_augroup("NaughieMyuiUi", { clear = true })

local function ui_states()
    return {
        buf_id = mkstate.tab(),
        win_id = mkstate.tab(),
    }
end

local function num_or_call(n, arg)
    if type(n) == "number" then
        return n
    elseif type(n) == "function" then
        return n(arg)
    else
        return 0
    end
end

local function calc_geom_dim(opts)
    return {
        main = {
            width = num_or_call(opts.geom.main.width),
            height = num_or_call(opts.geom.main.height),
        },
        companion = {
            width = num_or_call(opts.geom.companion.width),
            height = num_or_call(opts.geom.companion.height),
        },
    }
end

local function calc_geom_position_in(opts, dim)
    return {
        col = num_or_call(opts.col, dim),
        row = num_or_call(opts.row, dim),
    }
end

local function modify_geom_with(with_geom, calc_default)
    if not with_geom then
        return calc_default()
    elseif type(with_geom) == "function" then
        local geom = calc_default()
        return with_geom(geom)
    else
        return with_geom
    end
end

local function open_float_with(buf, geom, win_id_state, nofocus)
    local focusable = true
    if nofocus then focusable = false end

    local new_win = api.nvim_open_win(buf, true, {
        relative = "editor",
        width = geom.width,
        height = geom.height,
        col = geom.col,
        row = geom.row,
        style = "minimal",
        border = "none",
        focusable = focusable,
    })
    local old_win = win_id_state.set(new_win)
    states.ui_win_table.insert(new_win)

    local tab = api.nvim_get_current_tabpage()
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

local function open_bg_with(geom, bg_pat, bg_states, hl_group, hl_group_focus)
    create_buf_with(bg_states.buf_id)
    local buf = bg_states.buf_id.get()
    if not buf then return end

    local bg_buf = bg.build(bg_pat, geom)
    bg_states.bg.set(bg_buf)

    api.nvim_buf_set_lines(buf, 0, -1, false, bg_buf.lines)

    local win = open_float_with(buf, bg_buf, bg_states.win_id, true)
    local ns = api.nvim_create_namespace("")
    api.nvim_win_set_hl_ns(win, ns)
    bg_states.hl_ns.set(ns)

    bg.define_tick_highlight(ns, hl_group_focus)

    bg.add_highlight(bg_buf, buf, hl_group, hl_group_focus)
end

local function delete_bg_focus(bg_states, tab)
    local buf = bg_states.buf_id.get(tab)
    if not buf then return end
    bg.clear_focus_highlight(buf)
end

local function redraw_bg(bg_states, hl_group, hl_group_focus)
    local buf = bg_states.buf_id.get()
    if not buf then return end

    local bg_buf = bg_states.bg.get()
    if not bg_buf then return end

    local win, old_win = open_float_with(buf, bg_buf, bg_states.win_id, true)
    local ns = bg_states.hl_ns.get()
    if not ns then return end
    api.nvim_win_set_hl_ns(win, ns)

    bg.add_highlight(bg_buf, buf, hl_group, hl_group_focus)

    local win_before = bg_states.win_id.get()
    if old_win and api.nvim_win_is_valid(old_win) then api.nvim_win_close(old_win, true) end
    local win_after = bg_states.win_id.get()
end

local function declare_ui_common()
    local ui = { states = ui_states(), bg_states = ui_states() }
    ui.bg_states.bg = mkstate.tab()
    ui.bg_states.hl_ns = mkstate.tab()

    ui.get_buf = function()
        return ui.states.buf_id.get()
    end

    ui.delete_buf = function(tab)
        local buf = ui.states.buf_id.get(tab)
        if not buf then return end
        api.nvim_buf_delete(buf, { force = true })
        ui.states.buf_id.clear(tab)
    end

    ui.lines = function(start, end_idx, strict_indexing)
        local buf = ui.states.buf_id.get()
        if not buf then return end
        return api.nvim_buf_get_lines(buf, start, end_idx, strict_indexing)
    end

    ui.set_lines = function(start, end_idx, strict_indexing, replacement)
        local buf = ui.states.buf_id.get()
        if not buf then return end
        return api.nvim_buf_set_lines(buf, start, end_idx, strict_indexing, replacement)
    end

    ui.get_win = function()
        return ui.states.win_id.get()
    end

    ui.focus = function(hl_group, hl_group_on_focus)
        local win = ui.states.win_id.get()
        if not win then return end

        redraw_bg(ui.bg_states, hl_group, hl_group_on_focus)

        vim.schedule(function()
            api.nvim_set_current_win(win)
        end)

        return true
    end

    ui.close_bg = function(tab)
        local win = ui.bg_states.win_id.get(tab)
        ui.bg_states.win_id.clear(tab)
        if win then api.nvim_win_close(win, true) end
    end

    ui.close = function(tab)
        local win = ui.states.win_id.get(tab)
        ui.states.win_id.clear(tab)
        if win then api.nvim_win_close(win, true) end
        ui.close_bg(tab)
    end

    return ui
end

function M.declare_ui(opts)
    local ui = {
        main = declare_ui_common(),
        companion = declare_ui_common(),
        opts = opts,
    }

    ui.update_opts = function(new_opts)
        local merged = vim.tbl_deep_extend("force", vim.deepcopy(ui.opts), new_opts or {})
        ui.opts = merged
    end

    ui.main.calc_geom = function(with_geom)
        return modify_geom_with(with_geom, function()
            local dim = calc_geom_dim(ui.opts)
            local pos = calc_geom_position_in(ui.opts.geom.main, dim)
            return {
                width = dim.main.width,
                height = dim.main.height,
                col = pos.col,
                row = pos.row,
            }
        end)
    end

    ui.main.create_buf = function(setup_buf)
        local buf = create_buf_with(ui.main.states.buf_id)
        if not buf then return end

        local tab = api.nvim_get_current_tabpage()
        api.nvim_create_autocmd("WinEnter", {
            group = augroup,
            buffer = buf,
            callback = function()
                vim.schedule(function()
                    -- nvim_open_win may trigger WinEnter when opening another window
                    local current_buf = api.nvim_get_current_buf()
                    if current_buf ~= buf then return end

                    local win = ui.main.states.win_id.get(tab)
                    if win then
                        states.ui_stack.move_last(ui.main, win, tab)
                    end
                end)
            end,
        })

        api.nvim_create_autocmd("WinLeave", {
            group = augroup,
            buffer = buf,
            callback = function()
                delete_bg_focus(ui.main.bg_states, tab)
            end,
        })

        if ui.opts.main and ui.opts.main.setup_buf and type(ui.opts.main.setup_buf) == "function" then
            ui.opts.main.setup_buf(buf)
        end
        if setup_buf then
            setup_buf(buf)
        end
    end

    ui.main.open_float = function(setup_win, with_geom)
        if ui.main.states.win_id.get() then return end

        local buf = ui.main.states.buf_id.get()
        if not buf then return end

        local geom = ui.main.calc_geom(with_geom)
        open_bg_with(geom, ui.opts.background.pat, ui.main.bg_states, ui.opts.background.hl_group, ui.opts.background.hl_group_on_focus)
        local win = open_float_with(buf, geom, ui.main.states.win_id)

        local tab = api.nvim_get_current_tabpage()

        states.ui_stack.push(ui.main, win, tab)

        api.nvim_create_autocmd("WinClosed", {
            group = augroup,
            pattern = tostring(win),
            callback = function()
                ui.main.states.win_id.clear(tab)
                states.ui_stack.remove(win, tab)
                ui.main.close_bg(tab)

                local companion = ui.companion.states.win_id.get(tab)
                if companion and api.nvim_win_is_valid(companion) then
                    ui.companion.close(tab)
                end
            end,
        })

        if setup_win then
            setup_win(win, buf)
        end
    end

    ui.companion.calc_geom = function(with_geom)
        return modify_geom_with(with_geom, function()
            local dim = calc_geom_dim(ui.opts)
            local pos = calc_geom_position_in(ui.opts.geom.companion, dim)
            return {
                width = dim.companion.width,
                height = dim.companion.height,
                col = pos.col,
                row = pos.row,
            }
        end)
    end

    ui.companion.create_buf = function(setup_buf)
        local buf = create_buf_with(ui.companion.states.buf_id)
        if not buf then return end

        local tab = api.nvim_get_current_tabpage()

        api.nvim_create_autocmd("WinLeave", {
            group = augroup,
            buffer = buf,
            callback = function()
                delete_bg_focus(ui.companion.bg_states, tab)
            end,
        })

        if ui.opts.companion and ui.opts.companion.setup_buf and type(ui.opts.companion.setup_buf) == "function" then
            ui.opts.companion.setup_buf(buf)
        end
        if setup_buf then
            setup_buf(buf)
        end
    end

    ui.companion.open_float = function(setup_win, with_geom)
        if ui.companion.states.win_id.get() then return end

        local buf = ui.companion.states.buf_id.get()
        if not buf then return end

        local geom = ui.companion.calc_geom(with_geom)
        open_bg_with(geom, ui.opts.background.pat, ui.companion.bg_states, ui.opts.background.hl_group, ui.opts.background.hl_group_on_focus)
        local win = open_float_with(buf, geom, ui.companion.states.win_id)

        local tab = api.nvim_get_current_tabpage()
        api.nvim_create_autocmd("WinClosed", {
            group = augroup,
            pattern = tostring(win),
            callback = function()
                ui.companion.states.win_id.clear(tab)
                ui.companion.close_bg(tab)

                if ui.opts.main.close_on_companion_closed then
                    local main = ui.main.states.win_id.get(tab)
                    if main and api.nvim_win_is_valid(main) then
                        ui.main.close(tab)
                    end
                end
            end,
        })

        if setup_win then
            setup_win(win, buf)
        end
    end

    local main_focus = ui.main.focus
    ui.main.focus = function()
        return main_focus(ui.opts.background.hl_group, ui.opts.background.hl_group_on_focus)
    end
    local companion_focus = ui.companion.focus
    ui.companion.focus = function()
        return companion_focus(ui.opts.background.hl_group, ui.opts.background.hl_group_on_focus)
    end

    states.all_ui.insert(ui)

    return ui
end

function M.close_all()
    for _, ui in states.all_ui.iter() do
        ui.main.close()
    end
end

return M
