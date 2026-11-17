-- "stack" layout: dwindle-like tiling plus an equal-size stack along the monitor's long side.
--
-- A workspace is a list of cells laid out along the long side of the monitor (rows on
-- portrait monitors, columns on landscape ones), all the same size. Each cell is a
-- dwindle-like binary tree:
-- - Normal windows (Super+T, Super+Space, anything else) split the focused window in half,
--   side by side if it is wider than tall, top/bottom otherwise, like dwindle.
-- - Windows opened with the stack binds (Super+Alt+T, Super+Alt+Space) get a new cell at
--   the end, so they span the whole width (or height) and every cell is resized equally:
--   100% -> 50/50 -> 33/33/33... Normal windows already split in the stack direction are
--   turned into cells of their own first, so they count as stack entries too.
-- - When a window closes, its cell (or its half of a split) is given back and the cells
--   are re-split equally.
-- State lives in Lua, so a config reload re-tiles existing windows as normal splits.

local M = {
    pending_stack = false, -- the next new window opens as a new cell
    workspaces = {},       -- workspace id -> { cells = { node, ... }, last = window id }
    focus = {},            -- recently focused window ids, most recent first
}

-- Tree nodes: { id = "<window id>" } for a window, { a = node, b = node, side_by_side = bool }
-- for a split. Like dwindle with preserve_split, the direction is chosen when the split is
-- made (from the shape of the window being split) and kept afterwards.

local function target_id(target)
    local w = target.window
    return w and tostring(w.stable_id) or ("target" .. target.index)
end

local function contains(node, id)
    if node.id then return node.id == id end
    return contains(node.a, id) or contains(node.b, id)
end

-- Returns the node without the windows not in `present` (nil if none is left)
local function prune(node, present)
    if node.id then return present[node.id] and node or nil end
    local a, b = prune(node.a, present), prune(node.b, present)
    if not a then return b end
    if not b then return a end
    node.a, node.b = a, b
    return node
end

-- Replaces the leaf `id` with a split of it and `new_id`; true if found
local function split_leaf(node, id, new_id, side_by_side)
    for _, side in ipairs({ "a", "b" }) do
        local child = node[side]
        if child.id == id then
            node[side] = { a = child, b = { id = new_id }, side_by_side = side_by_side }
            return true
        elseif not child.id and split_leaf(child, id, new_id, side_by_side) then
            return true
        end
    end
    return false
end

-- Split node whose direct child is the leaf `id`
local function parent_of(node, id)
    if node.id then return nil end
    if node.a.id == id or node.b.id == id then return node end
    return parent_of(node.a, id) or parent_of(node.b, id)
end

local function find_leaf(node, id)
    if node.id then return node.id == id and node or nil end
    return find_leaf(node.a, id) or find_leaf(node.b, id)
end

local function focus_rank(id)
    for i, f in ipairs(M.focus) do
        if f == id then return i end
    end
    return math.huge
end

-- Closest window in direction l/r/u/d from the window `id`, by on-screen position.
-- Ties: the most aligned one, then the most recently focused one.
local function neighbor(targets, id, dir)
    local from = targets[id] and targets[id].box
    if not from then return nil end
    local function key(b, dist)
        local off = (dir == "l" or dir == "r") and math.abs((b.y + b.h / 2) - (from.y + from.h / 2))
            or math.abs((b.x + b.w / 2) - (from.x + from.w / 2))
        return dist, off
    end
    local best, best_dist, best_off
    for other, target in pairs(targets) do
        local b = target.box
        local dist
        if other ~= id then
            local overlap_y = b.y < from.y + from.h and from.y < b.y + b.h
            local overlap_x = b.x < from.x + from.w and from.x < b.x + b.w
            if dir == "r" and overlap_y and b.x >= from.x + from.w - 1 then dist = b.x - from.x
            elseif dir == "l" and overlap_y and b.x + b.w <= from.x + 1 then dist = from.x - b.x
            elseif dir == "d" and overlap_x and b.y >= from.y + from.h - 1 then dist = b.y - from.y
            elseif dir == "u" and overlap_x and b.y + b.h <= from.y + 1 then dist = from.y - b.y
            end
        end
        if dist then
            local d, off = key(b, dist)
            if not best or d < best_dist or (d == best_dist and (off < best_off
                or (off == best_off and focus_rank(other) < focus_rank(best)))) then
                best, best_dist, best_off = other, d, off
            end
        end
    end
    return best
end

local function state_for(workspace_id)
    local st = M.workspaces[workspace_id]
    if not st then
        st = { cells = {} }
        M.workspaces[workspace_id] = st
    end
    return st
end

local function in_workspace(st, id)
    for _, cell in ipairs(st.cells) do
        if contains(cell, id) then return true end
    end
    return false
end

-- Splits whose direction matches the stack (side by side on landscape, top/bottom on
-- portrait) are broken into separate cells, recursively; other splits stay as one cell
local function flatten(node, side_by_side, out)
    if not node.id and node.side_by_side == side_by_side then
        flatten(node.a, side_by_side, out)
        flatten(node.b, side_by_side, out)
    else
        table.insert(out, node)
    end
    return out
end

local function add_window(st, id, targets, landscape)
    if M.pending_stack then
        M.pending_stack = false
        -- Normal windows stacked in the same direction become cells of their own, so
        -- e.g. two top/bottom windows + a stacked one give 33/33/33, not 25/25/50
        local cells = {}
        for _, cell in ipairs(st.cells) do flatten(cell, landscape, cells) end
        table.insert(cells, { id = id })
        st.cells = cells
    else
        -- Split the most recently focused window of this workspace (or the last one placed)
        local focused
        for _, f in ipairs(M.focus) do
            if f ~= id and in_workspace(st, f) then
                focused = f
                break
            end
        end
        focused = focused or (st.last and in_workspace(st, st.last) and st.last)
        local placed = false
        if focused then
            -- Side by side if the window being split is wider than tall
            local box = targets[focused] and targets[focused].box
            local side_by_side = not box or box.w >= box.h
            for i, cell in ipairs(st.cells) do
                if cell.id == focused then
                    st.cells[i] = { a = cell, b = { id = id }, side_by_side = side_by_side }
                    placed = true
                    break
                elseif not cell.id and split_leaf(cell, focused, id, side_by_side) then
                    placed = true
                    break
                end
            end
        end
        if not placed then table.insert(st.cells, { id = id }) end
    end
    st.last = id
end

local function place_node(ctx, node, box, targets)
    if node.id then
        local target = targets[node.id]
        if target then target:place(box) end
        return
    end
    local side_by_side = node.side_by_side
    place_node(ctx, node.a, ctx:split(box, side_by_side and "left" or "top", 0.5), targets)
    place_node(ctx, node.b, ctx:split(box, side_by_side and "right" or "bottom", 0.5), targets)
end

local function active_id(ctx)
    for _, target in ipairs(ctx.targets) do
        if target.window and target.window.active then return target_id(target) end
    end
end

local function workspace_of(ctx)
    local w = ctx.targets[1] and ctx.targets[1].window
    return w and w.workspace and w.workspace.id or 0
end

hl.layout.register("stack", {
    recalculate = function(ctx)
        if #ctx.targets == 0 then return end
        local st = state_for(workspace_of(ctx))

        local targets, present = {}, {}
        for _, target in ipairs(ctx.targets) do
            local id = target_id(target)
            targets[id], present[id] = target, true
        end

        -- Drop windows that were closed, floated or moved away, and the cells left empty
        local cells = {}
        for _, cell in ipairs(st.cells) do
            local kept = prune(cell, present)
            if kept then table.insert(cells, kept) end
        end
        st.cells = cells

        local landscape = ctx.area.w >= ctx.area.h
        for _, target in ipairs(ctx.targets) do
            local id = target_id(target)
            if not in_workspace(st, id) then add_window(st, id, targets, landscape) end
        end

        -- Equal cells along the long side, then each cell's tree inside it
        local n = #st.cells
        for i, cell in ipairs(st.cells) do
            local box = landscape and ctx:column(i, n) or ctx:row(i, n)
            place_node(ctx, cell, box, targets)
        end
    end,

    layout_msg = function(ctx, msg)
        local command, arg = msg:match("^(%S+)%s*(%S*)")
        local id = active_id(ctx)
        local st = state_for(workspace_of(ctx))
        local parent
        for _, cell in ipairs(st.cells) do
            parent = parent or (id and parent_of(cell, id))
        end

        if command == "togglesplit" then
            -- Side by side <-> top/bottom for the focused window and its sibling
            if parent then parent.side_by_side = not parent.side_by_side end
        elseif command == "swapsplit" then
            if parent then parent.a, parent.b = parent.b, parent.a end
        elseif command == "move" then
            -- Swap the focused window with its neighbor in direction l/r/u/d
            -- (the generic window.move/swap dispatchers don't reach Lua layouts)
            local targets = {}
            for _, target in ipairs(ctx.targets) do targets[target_id(target)] = target end
            local other = id and neighbor(targets, id, arg)
            if not other then return true end
            local la, lb
            for _, cell in ipairs(st.cells) do
                la = la or find_leaf(cell, id)
                lb = lb or find_leaf(cell, other)
            end
            if la and lb then la.id, lb.id = lb.id, la.id end
        else
            return "stack: expected togglesplit, swapsplit or move l/r/u/d"
        end
        return true
    end,
})

hl.on("window.active", function(w)
    if not w then return end
    table.insert(M.focus, 1, tostring(w.stable_id))
    if #M.focus > 20 then table.remove(M.focus) end
end)

-- STACK_APPLY_BEGIN: use the layout everywhere and add its binds (everything above only defines it)
hl.config({ general = { layout = "lua:stack" } })

local function stacked(cmd)
    return function()
        M.pending_stack = true
        hl.exec_cmd(cmd)
    end
end
hl.bind("SUPER + ALT + T", stacked("alacritty"))
hl.bind("SUPER + ALT + space", stacked("dms ipc call spotlight toggle"))

-- Moving windows goes through the layout (replaces the DMS stock binds for window.move)
for key, dir in pairs({ left = "l", right = "r", up = "u", down = "d", H = "l", L = "r", K = "u", J = "d" }) do
    hl.unbind("SUPER + SHIFT + " .. key)
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.layout("move " .. dir))
end
