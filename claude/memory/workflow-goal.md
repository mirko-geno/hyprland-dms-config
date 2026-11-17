---
name: workflow-goal
description: "IMPORTANT: user's target workflow — pure tiling (NO scrolling/niri-style layouts), workspaces as virtual monitors, fast keyboard window management without mouse resizing"
metadata:
  type: user
---

IMPORTANT. User wants a tiling window manager, **not scrolling**: never propose niri-like behavior (e.g. Hyprland's `scrolling` layout) for Hyprland. Their workflow comes from GNOME: several workspaces used as "virtual monitors", switching between them fast; what bothered them in GNOME was constantly resizing windows with the mouse. Goal: many windows managed quickly from the keyboard. niri was nice but its scrollable model didn't fit this workflow, which is why they moved to Hyprland ([[hyprland-dms-setup]]).

**Why:** stated explicitly by the user after I suggested the scrolling layout.
**How to apply:** solutions should be tiling-based (dwindle/master, splits, keybinds) and avoid mouse resizing; keep normal binds (Super+T, Super+Space) behaving normally and add custom behavior on separate binds.

Workspace overviews: user tried Hyprtasking (2026-11-17) and had it removed. A GNOME-like overview (Hyprspace) adds little in a tiling WM since windows are always visible; what they'd value is a big grid of workspaces, which the plugins didn't give. Plugins built with hyprpm also proved fragile (hyprexpo removed upstream in May 2026; Hyprtasking doesn't render on rotated monitors, select/drag can't share one button). Don't push overview plugins again unless asked; Super+Tab is the DMS overview.
