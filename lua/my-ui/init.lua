local M = {}

local mkstate = require("glocal-states")

local api = vim.api

local default_opts = {
    geom = {
        main = {
            width = function() return math.floor(api.nvim_get_option("columns") * 0.5) end,
            height = function() return math.floor(api.nvim_get_option("lines") * 0.8) end,
            col = function(dim)
                return math.floor((api.nvim_get_option("columns") - dim.main.width) / 2)
            end,
            row = function(dim)
                return math.floor((api.nvim_get_option("lines") - dim.main.height) / 2)
            end,
        },
        companion = {
            width = function() return math.floor(api.nvim_get_option("columns") * 0.5) end,
            height = 3,
            col = function(dim)
                return math.floor((api.nvim_get_option("columns") - dim.companion.width) / 2)
            end,
            row = function(dim)
                return math.floor((api.nvim_get_option("lines") - dim.main.height) / 2) + dim.main.height + 2
            end,
        },
    },

    main = {
        setup_buf = function(buf) end,
        close_on_companion_closed = false,
    },
    companion = {
        setup_buf = function(buf) end,
    },
}

local last_active_win = mkstate.tab()

local ui_win_table = {}
local all_ui = {}

local augroup = api.nvim_create_augroup("NaughieMyui", { clear = true })

-- path should be `vim.fn.fnameescape`d before call
function M.open_file_into_current_win(path)
    vim.cmd("edit! " .. path)
end

-- path should be `vim.fn.fnameescape`d before call
function M.focus_on_last_active_win()
    local win = last_active_win.get()
    if not win or not api.nvim_win_is_valid(win) then return end

    api.nvim_set_current_win(win)
end

-- path should be `vim.fn.fnameescape`d before call
function M.open_file_into_last_active_win(path)
    local win = last_active_win.get()
    if not win or not api.nvim_win_is_valid(win) then
        return false
    end

    api.nvim_set_current_win(win)
    M.open_file_into_current_win(path)
    return true
end

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

local function open_float_with(buf, geom, win_id_state)
    local new_win = api.nvim_open_win(buf, true, {
        relative = "editor",
        width = geom.width,
        height = geom.height,
        col = geom.col,
        row = geom.row,
        style = "minimal",
        border = "rounded",
    })
    win_id_state.set(new_win)
    ui_win_table[new_win] = true

    local tab = api.nvim_get_current_tabpage()
    api.nvim_create_autocmd("WinClosed", {
        group = augroup,
        pattern = tostring(new_win),
        callback = function()
            win_id_state.clear(tab)
            ui_win_table[new_win] = nil
        end,
    })

    return new_win
end

local function create_buf_with(buf_id_state)
    if buf_id_state.get() then return end

    local new_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(new_buf, "bufhidden", "hide")
    buf_id_state.set(new_buf)

    return new_buf
end

local function declare_ui_one()
    local ui = { states = ui_states() }

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

    ui.focus = function()
        local win = ui.states.win_id.get()
        if not win then return end
        api.nvim_set_current_win(win)
        return true
    end

    ui.close = function(tab)
        local win = ui.states.win_id.get(tab)
        ui.states.win_id.clear(tab)
        if win then api.nvim_win_close(win, true) end
    end

    return ui
end

function M.declare_ui(user_opts)
    local opts = vim.tbl_deep_extend("force", vim.deepcopy(default_opts), user_opts or {})

    local ui = {
        main = declare_ui_one(),
        companion = declare_ui_one(),
        -- background = declare_ui_one(),
        opts = opts,
    }

    ui.update_opts = function(new_opts)
        local merged = vim.tbl_deep_extend("force", vim.deepcopy(ui.opts), new_opts or {})
        ui.opts = merged
    end

    ui.main.calc_geom = function()
        local dim = calc_geom_dim(ui.opts)
        local pos = calc_geom_position_in(ui.opts.geom.main, dim)
        return {
            width = dim.main.width,
            height = dim.main.height,
            col = pos.col,
            row = pos.row,
        }
    end

    ui.main.create_buf = function(setup_buf)
        local buf = create_buf_with(ui.main.states.buf_id)
        if not buf then return end

        if ui.opts.main and ui.opts.main.setup_buf and type(ui.opts.main.setup_buf) == "function" then
            ui.opts.main.setup_buf(buf)
        end
        if setup_buf then
            setup_buf(buf)
        end
    end

    ui.main.open_float = function(setup_win)
        if ui.main.states.win_id.get() then return end

        local buf = ui.main.states.buf_id.get()
        if not buf then return end

        local geom = ui.main.calc_geom()
        local win = open_float_with(buf, geom, ui.main.states.win_id)

        local tab = api.nvim_get_current_tabpage()
        api.nvim_create_autocmd("WinClosed", {
            group = augroup,
            pattern = tostring(win),
            callback = function()
                ui.main.states.win_id.clear(tab)

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

    ui.companion.calc_geom = function()
        local dim = calc_geom_dim(ui.opts)
        local pos = calc_geom_position_in(ui.opts.geom.companion, dim)
        return {
            width = dim.companion.width,
            height = dim.companion.height,
            col = pos.col,
            row = pos.row,
        }
    end

    ui.companion.create_buf = function(setup_buf)
        local buf = create_buf_with(ui.companion.states.buf_id)
        if not buf then return end

        if ui.opts.companion and ui.opts.companion.setup_buf and type(ui.opts.companion.setup_buf) == "function" then
            ui.opts.companion.setup_buf(buf)
        end
        if setup_buf then
            setup_buf(buf)
        end
    end

    ui.companion.open_float = function(setup_win)
        if ui.companion.states.win_id.get() then return end

        local buf = ui.companion.states.buf_id.get()
        if not buf then return end

        local geom = ui.companion.calc_geom()
        local win = open_float_with(buf, geom, ui.companion.states.win_id)

        local tab = api.nvim_get_current_tabpage()
        api.nvim_create_autocmd("WinClosed", {
            group = augroup,
            pattern = tostring(win),
            callback = function()
                ui.companion.states.win_id.clear(tab)

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

    table.insert(all_ui, ui)

    return ui
end

function M.close_all()
    for _, ui in ipairs(all_ui) do
        ui.main.close()
    end
end

api.nvim_create_autocmd("WinLeave", {
    group = augroup,
    callback = function()
        local win = api.nvim_get_current_win()
        if not win or ui_win_table[win] then return end
        last_active_win.set(win)
    end,
})

return M
