-- Floating windows: Super+V toggles floating. A window that becomes floating gets a fixed
-- size, FLOAT_AREA of its monitor's area with the monitor's proportions, and is centered on
-- that monitor, instead of keeping its tiled size (which often left part of it outside).
local FLOAT_AREA = 0.30

-- Logical size of a monitor: width/height come unrotated and unscaled
local function logical_size(m)
    local w, h = m.width, m.height
    if m.transform % 2 == 1 then w, h = h, w end
    return w / m.scale, h / m.scale
end

local function toggle_floating()
    local w = hl.get_active_window()
    if not w then return end
    local was_floating = w.floating
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    if was_floating or not w.monitor then return end
    local mw, mh = logical_size(w.monitor)
    local side = math.sqrt(FLOAT_AREA)
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(mw * side), y = math.floor(mh * side) }))
    hl.dispatch(hl.dsp.window.center())
end

-- Replaces the Super+V bind from dms/binds-user.lua
hl.unbind("SUPER + V")
hl.bind("SUPER + V", toggle_floating)
