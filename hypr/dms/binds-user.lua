-- Your keybinds. dms setup never overwrites this file.
-- Loaded after binds.lua: binding a stock key here replaces it, hl.unbind("SUPER + X") frees it.
-- Saving in the DMS keybind editor rewrites this file and keeps only hl.bind/hl.unbind lines.

-- Workspaces are switched only with Super+F1..F8 (see workspaces.lua)
hl.unbind("SUPER + 5")
hl.unbind("SUPER + 6")
hl.unbind("SUPER + 7")
hl.unbind("SUPER + 8")
hl.unbind("SUPER + 9")

-- Left-handed focus: Super+1/2/3/4 = left/right/up/down (replaces Super+H/J/K/L; arrows kept)
hl.unbind("SUPER + 1")
hl.unbind("SUPER + 2")
hl.unbind("SUPER + 3")
hl.unbind("SUPER + 4")
hl.bind("SUPER + 1", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + 2", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + 3", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + 4", hl.dsp.focus({ direction = "d" }))
hl.unbind("SUPER + H")
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")

-- Close windows with Alt+F4 instead of Super+Q
hl.unbind("SUPER + Q")
hl.bind("ALT + F4", hl.dsp.window.close())

-- Super+V toggles floating instead of Super+Shift+T (Super+V was the DMS clipboard);
-- the bind itself is in floating.lua (sizes and centers the window)
hl.unbind("SUPER + SHIFT + T")
hl.unbind("SUPER + V")

-- DMS clipboard history, moved from Super+V
hl.bind("SUPER + C", hl.dsp.exec_cmd("dms ipc call clipboard toggle"))

-- Super+Space opens the DMS search bar (spotlight-bar, stock Alt+Space) instead of the
-- app panel (spotlight); Alt+Space does nothing
hl.unbind("SUPER + space")
hl.unbind("ALT + space")
hl.bind("SUPER + space", hl.dsp.exec_cmd("dms ipc call spotlight-bar toggle"))
