local M = {}

local states = require("my-ui.states")

local config_fg = require("my-ui.ui.fg_win")
local config_bg = require("my-ui.ui.bg_win")

local api = vim.api
local augroup = api.nvim_create_augroup("NaughieMyuiUi", { clear = true })

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
            width = num_or_call(opts.main.width),
            height = num_or_call(opts.main.height),
        },
        companion = {
            width = num_or_call(opts.companion.width),
            height = num_or_call(opts.companion.height),
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

local function declare_ui_common()
    local ui = {}

    local fg_internal_api = config_fg.configure(ui)
    local bg_internal_api = config_bg.configure(ui)

    local internal_api = { fg = fg_internal_api, bg = bg_internal_api }

    ui.close = function(tab)
        local win = ui.states.win_id.get(tab)
        ui.states.win_id.clear(tab)
        internal_api.bg.close(tab)
        if win and api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    end

    internal_api.create_buf = function(opts, setup_buf)
        local buf = internal_api.fg.create_buf(opts)
        if not buf then return end

        local tab = api.nvim_get_current_tabpage()
        api.nvim_create_autocmd("WinLeave", {
            group = augroup,
            buffer = buf,
            callback = function()
                internal_api.bg.delete_focus(tab)
            end,
        })

        if setup_buf then
            setup_buf(buf, tab)
        end
    end

    internal_api.calc_geom = function(geom_opts, key, with_geom)
        return modify_geom_with(with_geom, function()
            local dim = calc_geom_dim(geom_opts)
            local pos = calc_geom_position_in(geom_opts[key], dim)
            return {
                width = dim[key].width,
                height = dim[key].height,
                col = pos.col,
                row = pos.row,
            }
        end)
    end

    internal_api.open_float = function(opts, key, with_geom, setup_win, cleanup_win)
        if ui.states.win_id.get() then return end

        local buf = ui.states.buf_id.get()
        if not buf then return end

        local tab = api.nvim_get_current_tabpage()

        local geom = internal_api.calc_geom(opts.geom, key, with_geom)
        internal_api.bg.open(geom, opts.background)
        local win = internal_api.fg.open_float(geom, opts[key])

        api.nvim_create_autocmd("WinClosed", {
            group = augroup,
            pattern = tostring(win),
            callback = function()
                internal_api.bg.close(tab)

                cleanup_win(tab, win)
            end,
        })

        if setup_win then
            setup_win(win, buf, tab)
        end
    end

    internal_api.focus = function(bg_opts)
        local win = ui.states.win_id.get()
        if not win or not api.nvim_win_is_valid(win) then return end

        internal_api.bg.redraw(bg_opts)
        vim.schedule(function()
            api.nvim_set_current_win(win)
        end)

        return true
    end

    return ui, internal_api
end

function M.declare_ui(opts)
    local main_ui, main_internal_api = declare_ui_common()
    local companion_ui, companion_internal_api = declare_ui_common()

    local ui = {
        main = main_ui,
        companion = companion_ui,
        opts = opts,
    }

    local internal_api = { main = main_internal_api, companion = companion_internal_api }

    ui.update_opts = function(new_opts)
        local merged = vim.tbl_deep_extend("force", vim.deepcopy(ui.opts), new_opts or {})
        ui.opts = merged
    end

    ui.main.create_buf = function(setup_buf)
        internal_api.main.create_buf(ui.opts.main, function(buf, tab)
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

            if setup_buf then
                setup_buf(buf, tab)
            end
        end)
    end

    ui.main.open_float = function(setup_win, with_geom)
        internal_api.main.open_float(ui.opts, "main", with_geom, function(win, buf, tab)
            states.ui_stack.push(ui.main, win, tab)
            if setup_win then
                setup_win(win, buf, tab)
            end
        end, function(tab, win)
            states.ui_stack.remove(win, tab)

            local companion = ui.companion.states.win_id.get(tab)
            if companion and api.nvim_win_is_valid(companion) then
                ui.companion.close(tab)
            end
        end)
    end

    ui.companion.create_buf = function(setup_buf)
        internal_api.companion.create_buf(ui.opts.companion, setup_buf)
    end

    ui.companion.open_float = function(setup_win, with_geom)
        internal_api.companion.open_float(ui.opts, "companion", with_geom, setup_win, function(tab)
            if ui.opts.main.close_on_companion_closed then
                local main = ui.main.states.win_id.get(tab)
                if main and api.nvim_win_is_valid(main) then
                    ui.main.close(tab)
                end
            end
        end)
    end

    ui.main.calc_geom = function()
        return internal_api.main.calc_geom(ui.opts.geom, "main")
    end
    ui.companion.calc_geom = function()
        return internal_api.companion.calc_geom(ui.opts.geom, "companion")
    end

    ui.main.focus = function()
        return internal_api.main.focus(ui.opts.background)
    end
    ui.companion.focus = function()
        return internal_api.companion.focus(ui.opts.background)
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
