local M = {}

local api = vim.api
local strwidth = vim.fn.strwidth

function M.build(bg_pat, geom)
    local base_width = geom.width + 2
    local base_height = geom.height + 2

    local pat_hor_len = strwidth(bg_pat.hor)
    local copies = math.floor(base_width / pat_hor_len) + 1
    local pat_width = pat_hor_len * copies

    local diff = pat_width - base_width
    local col_offset = math.floor(diff / 2)

    local pat_cor_len = strwidth(bg_pat.corner)

    local hor = bg_pat.corner .. string.rep(bg_pat.hor, copies) .. bg_pat.corner

    local max_ver_width = { left = 0, right = 0 }
    for _, pat in ipairs(bg_pat.ver.left) do
        local max_width = math.max(vim.fn.strwidth(pat), max_ver_width.left)
        max_ver_width.left = max_width
    end
    for _, pat in ipairs(bg_pat.ver.right) do
        local max_width = math.max(vim.fn.strwidth(pat), max_ver_width.right)
        max_ver_width.right = max_width
    end

    local lines = {}
    local hl = {}

    table.insert(lines, hor)
    table.insert(hl, { line = 0, from = 0, to = -1 })

    for i = 1, base_height do
        local l_idx = i % #bg_pat.ver.left
        if l_idx == 0 then l_idx = #bg_pat.ver.left end

        local r_idx = i % #bg_pat.ver.right
        if r_idx == 0 then r_idx = #bg_pat.ver.right end

        local l_pat = bg_pat.ver.left[l_idx]
        local r_pat = bg_pat.ver.right[r_idx]

        local offset = 2 * pat_cor_len - strwidth(l_pat) - strwidth(r_pat)

        table.insert(lines, l_pat .. string.rep(" ", pat_width + offset) .. r_pat)

        local total_width = string.len(l_pat) + string.len(r_pat) + pat_width + offset
        local l_width = string.len(l_pat) + max_ver_width.left - vim.fn.strwidth(l_pat)
        local r_width = string.len(r_pat) + max_ver_width.right - vim.fn.strwidth(r_pat)
        table.insert(hl, { line = i, from = 0, to = l_width })
        table.insert(hl, { line = i, from = total_width - r_width, to = total_width })
    end
    table.insert(lines, hor)
    table.insert(hl, { line = base_height + 1, from = 0, to = -1 })

    return {
        lines = lines,
        width = pat_width + pat_cor_len * 2,
        height = base_height + 2,
        col = geom.col - pat_cor_len - col_offset - 1,
        row = geom.row - 2,
        hl = hl,
        pat = bg_pat,
    }
end

local hl_ns = api.nvim_create_namespace("naughie_myui_bg_hl")
local hl_ns_focus = api.nvim_create_namespace("naughie_myui_bg_hl_on_focus")

local function add_ticks(bg_hl, buf)
    local bg_pat = bg_hl.pat
    local total_width = bg_hl.width

    local l_above_len = string.len(bg_pat.ver.left[1])
    api.nvim_buf_set_extmark(buf, hl_ns_focus, 1, l_above_len, {
        virt_text = { { "\u{e0bc}", "NaughieMyuiUiTick" } },
        virt_text_pos = "overlay",
    })
    local above_offset = l_above_len + (total_width - strwidth(bg_pat.ver.left[1]) - strwidth(bg_pat.ver.right[1]))
    api.nvim_buf_set_extmark(buf, hl_ns_focus, 1, above_offset - 1, {
        virt_text = { { "\u{e0be}", "NaughieMyuiUiTick" } },
        virt_text_pos = "overlay",
    })

    local below_height = bg_hl.height - 2
    local l_idx = below_height % #bg_pat.ver.left
    if l_idx == 0 then l_idx = #bg_pat.ver.left end

    local r_idx = below_height % #bg_pat.ver.right
    if r_idx == 0 then r_idx = #bg_pat.ver.right end

    local l_below_len = string.len(bg_pat.ver.left[l_idx])
    api.nvim_buf_set_extmark(buf, hl_ns_focus, below_height, l_below_len, {
        virt_text = { { "\u{e0b8}", "NaughieMyuiUiTick" } },
        virt_text_pos = "overlay",
    })
    local below_offset = l_below_len + (total_width - strwidth(bg_pat.ver.left[l_idx]) - strwidth(bg_pat.ver.right[r_idx]))
    api.nvim_buf_set_extmark(buf, hl_ns_focus, below_height, below_offset - 1, {
        virt_text = { { "\u{e0ba}", "NaughieMyuiUiTick" } },
        virt_text_pos = "overlay",
    })
end

function M.add_highlight(bg_hl, buf, hl_group, hl_group_focus)
    for _, hl in ipairs(bg_hl.hl) do
        vim.hl.range(buf, hl_ns, hl_group, { hl.line, hl.from }, { hl.line, hl.to }, {})
        vim.hl.range(buf, hl_ns_focus, hl_group_focus, { hl.line, hl.from }, { hl.line, hl.to }, {})
    end

    add_ticks(bg_hl, buf)
end

function M.clear_focus_highlight(buf)
    if not api.nvim_buf_is_valid(buf) then return end
    api.nvim_buf_clear_namespace(buf, hl_ns_focus, 0, -1)
end

function M.restore_focus_highlight(bg_hl, buf, hl_group_focus)
    for _, hl in ipairs(bg_hl.hl) do
        vim.hl.range(buf, hl_ns_focus, hl_group_focus, { hl.line, hl.from }, { hl.line, hl.to }, {})
    end

    add_ticks(bg_hl, buf)
end

function M.define_tick_highlight(local_ns, hl_group_focus)
    local hl_info = api.nvim_get_hl(0, { name = hl_group_focus, link = false })
    if not hl_info then return end
    local bg = string.format("#%06x", hl_info.bg or 0)

    api.nvim_set_hl(local_ns, "NaughieMyuiUiTick", { fg = bg })
end

return M
