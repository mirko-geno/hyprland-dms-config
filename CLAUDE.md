# CLAUDE.md

Hyprland 0.57 (Lua config) + DMS (DankMaterialShell) desktop on Nobara/Fedora 44, kept
reproducible in this repo. `README.md` documents everything (keybinds, layout, restore);
read the relevant section instead of rediscovering it.

## Working with the user

- Talk to the user in **rioplatense Spanish**. Code comments, README and commit messages in English.
- The user is left-handed: keybinds use number keys, F keys and the left side of the
  keyboard (Super+1..4 focus, Super+Ctrl+1..4 move, Super+F1..F8 workspaces).
- Goal: pure tiling, fast keyboard window management, workspaces as "virtual monitors".
  No scrolling/niri-style layouts. Don't suggest workspace-overview plugins again
  (Hyprtasking was tried and removed; hyprexpo no longer exists).
- Prefer simple solutions; no extra daemons or heavy tooling.
- Commit/push only when asked. New folders need `git add -A`.
- Ask before reading `~/.ssh`.
- `sudo` does not work from Claude's shell (no terminal for the password, and `!` doesn't
  help either): give the user the command to run in their own terminal.

## Workflow after any config change

1. Validate: `Hyprland --verify-config` (must print `config ok`).
2. `./backup.sh` (copies the live config into the repo).
3. Update `README.md` (and `backup.sh` / `restore.sh` if new files are involved).

## Pitfalls

- Saving any file in `~/.config/hypr` reloads the live config immediately, and reloading
  resets the Lua state (the stack layout re-tiles open windows).
- `hypr/stack.lua` (custom Lua layout `lua:stack`): edit a copy in the scratchpad, test it
  on a headless output, verify the full config with the copy, then copy it in. Testing:
  `hyprctl output create headless NAME`, load the layout part with `hyprctl eval` under a
  **new layout name each time** (re-registering a name fails), assign it with
  `hl.workspace_rule({ workspace = "N", monitor = "NAME", layout = "lua:..." })`, spawn test
  windows with `hl.exec_cmd(cmd, { workspace = "N silent" })`, read geometry from
  `hyprctl clients -j`, then remove the output.
- Lua layouts don't receive Hyprland's move/swap/resize requests: those go through layout
  messages (`move`, `resize`, `grow`, `equalize`, `togglesplit`).
- Creating an `hl.timer` while the config loads crashes `Hyprland --verify-config`
  (create timers lazily, inside callbacks).
- Rebinding a key with `hl.bind` adds a second bind; `hl.unbind` it first.
- Never `pkill -f`/`pgrep -f` with a pattern that also appears in your own command line.
- `hyprctl repl 'return ...'` evaluates Lua in the running compositor (useful for checks).
- `hyprctl binds` shows `arg` as an internal index, not the command.
- Docker (when started) blocks VM networking via iptables FORWARD DROP.

## Repo notes

- Branch `fedora-minimal`: `restore.sh` support for a minimal Fedora install (not merged,
  untested on a real minimal install).
- `claude/` holds the old long session and the project memory. Start new sessions instead of
  resuming the old one: it is very large and expensive to resume.
- Shared with `~/niri-dms-config` (the niri setup): `dms/`, `alacritty/`, `fish/`, `cursor/`,
  `icons/`, `ssh-agent/`, wallpaper. Restoring one repo overwrites them.
