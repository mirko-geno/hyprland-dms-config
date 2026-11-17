---
name: hyprland-dms-setup
description: "Hyprland+DMS repo ~/hyprland-dms-config: backup/restore workflow, Hyprland install from COPR, what is shared with the niri repo"
metadata:
  type: project
---

User is trying Hyprland 0.57 (Lua config: ~/.config/hypr/hyprland.lua + dms/*.lua via require) as a tiling alternative to niri, both with DMS, picked as sessions in GDM. Repo ~/hyprland-dms-config (private, GitHub mirko-geno/hyprland-dms-config) mirrors the niri repo structure ([[niri-dms-setup]]): backup.sh / restore.sh / README in English; hypr/ instead of niri/; dms, alacritty, fish, cursor, ssh-agent, wallpaper and claude/ are the same as in the niri repo (shared files, restoring one repo overwrites them).

Hyprland comes from the lionheartp/Hyprland COPR with quickshell,matugen excluded (would replace DMS's versions) and no weak deps; restore.sh does this if Hyprland is missing. Validate with `Hyprland --verify-config -c <file>` (prints "config ok"; checks required dms files relative to that file). Only change from DMS-generated config so far: kb_layout = "latam" (Hyprland ignores localectl). Custom Lua layout ~/.config/hypr/stack.lua (lua:stack, required last in hyprland.lua): equal cells along the monitor long side (Super+Alt+T / Super+Alt+Space add a cell via a pending flag), dwindle-like splits inside cells for normal windows, move via layout msg "move l/r/u/d" (generic window.move/swap don't reach Lua layouts), togglesplit/swapsplit. Test Lua layouts on a headless output (`hyprctl output create headless NAME`, `hyprctl eval`, workspace_rule with layout) under a fresh layout name each time: re-registering a name errors; any save in ~/.config/hypr reloads config and resets Lua state. ~/.config/hypr/workspaces.lua: workspace rules pin 1-4 to DP-1 (landscape), 5-8 to HDMI-A-1 (portrait), Super+F1..F8 focus, Super+Ctrl+F1..F8 move window (user's keyboard groups F1-F4 / F5-F8). Left-handed keybinds otherwise not ported yet; stock DMS binds use Super+1..9 for workspaces.

**Why:** user wants each compositor setup reproducible on its own.
**How to apply:** after config changes run the validator, ./backup.sh, update README; new config files go in backup.sh/restore.sh too. User commits/pushes themselves. `sudo` doesn't work through `!` in Claude Code: give the user sudo commands to run in their own terminal.
