-- Workspace overview: hyprexpo fork (github.com/sandwichfarm/hyprexpo), built by hand against
-- hyprland-devel from the COPR and installed to ~/.local/lib/hyprexpo (see README).
-- Super+Tab opens a 2x2 grid of each monitor's workspaces (1-4 on DP-1, 5-8 on HDMI-A-1).
local PLUGIN = os.getenv("HOME") .. "/.local/lib/hyprexpo/hyprexpo.so"

-- Without the plugin (e.g. fresh install), keep the DMS overview on Super+Tab
local f = io.open(PLUGIN, "r")
if not f then return end
f:close()

-- Loading again on config reload is a no-op
hl.plugin.load(PLUGIN)

-- Plugin options are unknown until the plugin is loaded (and always in --verify-config)
if hl.plugin.hyprexpo then
    hl.config({
        plugin = {
            hyprexpo = {
                columns = 2,
                rows = 2,
                dynamic_grid = 0,
                skip_empty = 0, -- empty workspaces stay visible and selectable
                max_workspace = 8,
                workspace_method = "DP-1 first 1, HDMI-A-1 first 5",
                label_text_mode = "id", -- labels show the workspace number, not the tile position
            },
        },
    })
end

-- Replaces the DMS overview bind from dms/binds.lua (falls back to it if the plugin didn't load)
hl.unbind("SUPER + TAB")
hl.bind("SUPER + TAB", function()
    if hl.plugin.hyprexpo then
        hl.plugin.hyprexpo.expo("toggle all")
    else
        hl.dispatch(hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
    end
end)
