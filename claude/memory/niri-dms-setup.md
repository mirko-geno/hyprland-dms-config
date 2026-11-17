---
name: niri-dms-setup
description: "User's niri+DMS desktop setup, left-handed keybind scheme, and the ~/niri-dms-config backup repo workflow"
metadata:
  node_type: memory
  type: project
  originSessionId: b72d4f5c-b8ea-4bf6-810c-f3d731982a15
  modified: 2026-11-07T01:09:52.275Z
---

User runs niri 26.04 + DMS (DankMaterialShell) on Nobara (Fedora 44), logging in through GDM; GNOME is still installed but not the running session. Terminal Alacritty, shell fish. Left-handed: avoids arrow keys / right-side keys; keybinds use number keys and F-keys (Super+1-4 focus, Super+Ctrl+1-4 move, Super+F1-F9 workspaces, Super+Shift+F1-F9 send to workspace, Super+Ctrl+F1-F4 send to monitor, Super+Tab overview, Super+A DMS Spotlight, Alt+F4 close, Alt+T / Super+T terminal). Volume keys step 3%. HDMI-A-1 (32") is portrait. ~/.config/niri/scripts/auto-layout.py (spawn-at-startup, niri event stream): first tiled window on a workspace gets 100% width on any monitor; on landscape the 2nd window shrinks the first back to 50%; when a close/move leaves one tiled window it goes back to 100%; on portrait outputs (detected by size) new windows are consumed into the left column. No per-output block in config.kdl (niri uses the first matching output block, which would override DMS's outputs.kdl). Don't pkill/pgrep -f with the script name: it matches Claude's own shell.

Config is backed up in the private GitHub repo ~/niri-dms-config via backup.sh / restore.sh; README documents everything. Besides niri/DMS/Alacritty it covers: fish config (restore installs fish+zoxide and sets it as default shell), cursor theme Hacked-Red + fallback (~/.icons/default, environment.d), gcr-ssh-agent (GNOME's SSH agent, SSH_AUTH_SOCK in environment.d), and this Claude session + memory (claude/). User commits/pushes themselves; new folders need `git add -A`.

**Why:** user wants to replicate/restore the desktop easily.
**How to apply:** after changing anything covered, run `niri validate` if niri config changed, then `./backup.sh` in the repo and update README; new config files must also be added to backup.sh/restore.sh. Prefer simple solutions (user dislikes "trambolikos" like system daemons). Code comments and README in English; talk to the user in Spanish (rioplatense). Ask before reading ~/.ssh.
