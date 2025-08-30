local M = {}

local states = require("my-ui.states")

local mkstate = require("glocal-states")
local api = vim.api

local augroup = api.nvim_create_augroup("NaughieMyuiUiCloseFg", { clear = true })

local nocursor_hl = "n:MyUiNoCursor"
api.nvim_set_hl(0, "MyUiNoCursor", { reverse = true, blend = 100 })
local guicursor_info = api.nvim_get_option_info("guicursor")
local default_guicursor = guicursor_info and guicursor_info.default

local cursor_augroup = api.nvim_create_augroup("NaughieMyUiNoCursor", { clear = true })

function M.configure(ui)
    ui.states = {
        buf_id = mkstate.tab(),
        win_id = mkstate.tab(),
        guicursor = nil,
    }

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

    local internal_api = {}

    local unset_guicursor = function()
        local current_guicursor = vim.o.guicursor
        if current_guicursor ~= nocursor_hl then ui.states.guicursor = current_guicursor end

        vim.o.guicursor = nocursor_hl
    end

    local restore_guicursor = function()
        if not ui.states.guicursor or ui.states.guicursor == "" then
            vim.o.guicursor = default_guicursor
        else
            vim.o.guicursor = ui.states.guicursor
        end
        ui.states.guicursor = nil
    end

    internal_api.create_buf = function(opts)
        if ui.states.buf_id.get() then return end

        local new_buf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_option(new_buf, "bufhidden", "hide")
        local old_buf = ui.states.buf_id.set(new_buf)

        if opts.hide_cursor then
            api.nvim_create_autocmd("WinEnter", {
                group = cursor_augroup,
                buffer = new_buf,
                callback = function()
                    vim.schedule(function()
                        -- nvim_open_win may trigger WinEnter when opening another window
                        local current_buf = api.nvim_get_current_buf()
                        if current_buf ~= new_buf then return end

                        unset_guicursor()
                    end)
                end,
            })

            api.nvim_create_autocmd("WinLeave", {
                group = cursor_augroup,
                buffer = new_buf,
                callback = restore_guicursor,
            })
        end

        if opts.setup_buf and type(opts.setup_buf) == "function" then
            opts.setup_buf(new_buf)
        end

        return new_buf, old_buf
    end

    internal_api.open_float = function(geom, opts)
        local buf = ui.states.buf_id.get()
        if not buf then return end

        local new_win = api.nvim_open_win(buf, true, {
            relative = "editor",
            width = geom.width,
            height = geom.height,
            col = geom.col,
            row = geom.row,
            style = "minimal",
            border = "none",
            focusable = true,
        })
        local old_win = ui.states.win_id.set(new_win)
        api.nvim_set_option_value("winfixbuf", true, { win = new_win })

        states.ui_win_table.insert(new_win)

        api.nvim_create_autocmd("WinClosed", {
            group = augroup,
            pattern = tostring(new_win),
            callback = function()
                ui.states.win_id.clear_if(function(value)
                    return value == new_win
                end, tab)
                states.ui_win_table.remove(new_win)
            end,
        })

        if opts.hide_cursor then
            unset_guicursor()
        end

        return new_win, old_win
    end

    internal_api.close = function(tab)
        local win = ui.states.win_id.get(tab)
        ui.states.win_id.clear(tab)
        if win and api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    end

    return internal_api
end

return M
