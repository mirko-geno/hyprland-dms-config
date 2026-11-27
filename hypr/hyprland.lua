-- Hyprland configuration (Lua) — https://wiki.hypr.land/configuring/

-- DMS_STARTUP_BEGIN
hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	if not os.getenv("HYPRLAND_NO_SD_TARGET") then
		hl.exec_cmd("systemctl --user start hyprland-session.target")
	end
end)
-- DMS_STARTUP_END

hl.config({
	input = {
		-- Same layout as the system (localectl), which niri reads on its own
		kb_layout = "latam",
		numlock_by_default = true,
		follow_mouse = 0,
		-- Don't move focus when the cursor crosses between floating and tiled windows
		-- (Hyprland does that by default even with follow_mouse = 0)
		float_switch_override_focus = 0,
		-- dms/input.lua is required later and wins per key
		touchpad = {
			tap_to_click = true,
			natural_scroll = true,
		},
	},
	general = {
		gaps_in = 5,
		gaps_out = 5,
		border_size = 2,
		layout = "dwindle",
	},
	decoration = {
		rounding = 12,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = true,
			range = 30,
			render_power = 4,
			offset = "0 5",
			color = "rgba(00000070)",
		},
	},
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
	},
	-- No donation screen (hyprland-donate-screen, from hyprland-guiutils)
	ecosystem = {
		no_donation_nag = true,
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		mfact = 0.5,
	},
})

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "default" })

hl.window_rule({ match = { class = "^(org\\.wezfurlong\\.wezterm)$" }, tile = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.)" }, rounding = 12 })
hl.window_rule({ match = { class = "^(gnome-control-center)$" }, tile = true })
hl.window_rule({ match = { class = "^(pavucontrol)$" }, tile = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, tile = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Calculator)$" }, float = true })
hl.window_rule({ match = { class = "^(gnome-calculator)$" }, float = true })
hl.window_rule({ match = { class = "^(galculator)$" }, float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true })
hl.window_rule({ match = { class = "^(xdg-desktop-portal)$" }, float = true })
hl.window_rule({
	match = { class = "^(steam)$", title = "^(notificationtoasts)" },
	no_initial_focus = true,
	pin = true,
})
hl.window_rule({
	match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" },
	float = true,
})
hl.window_rule({ match = { class = "^(zoom)$" }, float = true })
hl.layer_rule({ match = { namespace = "^(quickshell)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^dms:.*" }, no_anim = true })

require("dms.colors")
require("dms.outputs")
require("dms.layout")
require("dms.cursor")
require("dms.input")
require("dms.binds")
require("dms.binds-user")
require("dms.windowrules")

-- Custom "stack" layout (dwindle-like + equal stack with Super+Alt+T / Super+Alt+Space).
-- Loaded last so its binds replace the DMS stock ones.
require("stack")

-- Workspaces 1-4 on the landscape monitor, 5-8 on the portrait one (Super+F1..F8)
require("workspaces")

-- Super+V: floating windows get a fixed size and are centered
require("floating")

-- Workspace overview plugin (Super+Tab)
require("hyprexpo")
