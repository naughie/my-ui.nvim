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
    }
end

local hl_ns = api.nvim_create_namespace("naughie_myui_bg_hl")
local hl_ns_focus = api.nvim_create_namespace("naughie_myui_bg_hl_on_focus")

function M.add_highlight(bg_hl, buf, hl_group, hl_group_focus)
    for _, hl in ipairs(bg_hl) do
        vim.hl.range(buf, hl_ns, hl_group, { hl.line, hl.from }, { hl.line, hl.to }, {})
        vim.hl.range(buf, hl_ns_focus, hl_group_focus, { hl.line, hl.from }, { hl.line, hl.to }, {})
    end
end

function M.clear_focus_highlight(buf)
    if not api.nvim_buf_is_valid(buf) then return end
    api.nvim_buf_clear_namespace(buf, hl_ns_focus, 0, -1)
end

function M.restore_focus_highlight(bg_hl, buf, hl_group_focus)
    for _, hl in ipairs(bg_hl) do
        vim.hl.range(buf, hl_ns_focus, hl_group_focus, { hl.line, hl.from }, { hl.line, hl.to }, {})
    end
end

return M
