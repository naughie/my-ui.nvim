local M = {}

local api = vim.api

local function available_height()
    return api.nvim_get_option("lines") - vim.o.cmdheight
end

local function centered_col(dim)
    local bg_col = math.floor((api.nvim_get_option("columns") - dim.bg.width) / 2)
    return bg_col + math.floor((dim.bg.width - dim.width) / 2)
end

local function main_bg_row(dim)
    local centered_row = math.floor((api.nvim_get_option("lines") - dim.main.bg.height) / 2)
    local stacked_height = dim.main.bg.height + dim.companion.bg.height - 1

    return math.max(0, math.min(centered_row, available_height() - stacked_height))
end

M.default_opts = {
    geom = {
        main = {
            width = function() return math.floor(api.nvim_get_option("columns") * 0.5) end,
            height = function() return math.floor(api.nvim_get_option("lines") * 0.8) end,
            col = function(dim)
                return centered_col(dim.main)
            end,
            row = function(dim)
                return main_bg_row(dim) + (dim.main.bg.height - dim.main.height) / 2
            end,
        },
        companion = {
            width = function() return math.floor(api.nvim_get_option("columns") * 0.5) end,
            height = 3,
            col = function(dim)
                return centered_col(dim.companion)
            end,
            row = function(dim)
                local bg_row = main_bg_row(dim) + dim.main.bg.height - 1
                return bg_row + (dim.companion.bg.height - dim.companion.height) / 2
            end,
        },
    },

    main = {
        setup_buf = function(buf) end,
        close_on_companion_closed = false,
        hide_cursor = false,
    },
    companion = {
        setup_buf = function(buf) end,
        hide_cursor = false,
    },

    background = {
        hl_group = "FloatBorder",
        hl_group_on_focus = "Visual",

        pat = {
            hor = "｡o♡｡o｡",
            ver = { left = { "୨୧", ":." }, right = { "୨୧", ".:" } },
            corner = "🎀",
        },
    },
}

return M
