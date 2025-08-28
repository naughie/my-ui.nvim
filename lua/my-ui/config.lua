local M = {}

local api = vim.api

M.default_opts = {
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
                return math.floor((api.nvim_get_option("lines") - dim.main.height) / 2) + dim.main.height + 3
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
