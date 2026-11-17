-- Fixed workspaces per monitor, matching the keyboard's F-key groups (F1-F4, gap, F5-F8):
-- workspaces 1-4 always live on the landscape monitor (DP-1), 5-8 on the portrait one
-- (HDMI-A-1). Each monitor starts on its first workspace.
-- Super+F1..F8 goes to that workspace (and to its monitor); Super+Ctrl+F1..F8 sends the
-- focused window there.
local monitors = {
    ["DP-1"] = { 1, 2, 3, 4 },
    ["HDMI-A-1"] = { 5, 6, 7, 8 },
}

for monitor, workspaces in pairs(monitors) do
    for i, ws in ipairs(workspaces) do
        hl.workspace_rule({ workspace = tostring(ws), monitor = monitor, default = i == 1 })
        hl.bind("SUPER + F" .. ws, hl.dsp.focus({ workspace = tostring(ws) }))
        hl.bind("SUPER + CTRL + F" .. ws, hl.dsp.window.move({ workspace = tostring(ws) }))
    end
end
