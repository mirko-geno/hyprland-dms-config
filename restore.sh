#!/usr/bin/env bash
# Restores the config saved in this folder (Hyprland, DMS, Alacritty).
# Before overwriting anything, it backs up the current config to ~/.config-backups/<date>.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
BACKUP="$HOME/.config-backups/$(date +%Y%m%d-%H%M%S)"
# Claude Code keeps sessions per directory, named after its path with non-alphanumerics as "-"
CLAUDE_PROJECT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$(printf '%s' "$REPO" | sed 's/[^a-zA-Z0-9]/-/g')"
# Hyprland COPR recommended by the Hyprland wiki for Fedora
HYPR_COPR="lionheartp/Hyprland"
HYPR_REPO_ID="copr:copr.fedorainfracloud.org:lionheartp:Hyprland"

# Hyprland: install it if missing. The COPR also ships quickshell and matugen, which would
# replace the versions DMS depends on, so they are excluded from it.
if ! command -v Hyprland >/dev/null; then
    echo "Installing Hyprland from the $HYPR_COPR COPR (needs sudo)"
    sudo dnf copr enable -y "$HYPR_COPR"
    sudo dnf config-manager setopt "$HYPR_REPO_ID.excludepkgs=quickshell,matugen"
    # No weak deps: they pull a bar, a launcher and kitty, which DMS already covers
    sudo dnf install -y --setopt=install_weak_deps=False hyprland xdg-desktop-portal-hyprland
fi

# Validate the Hyprland config before touching anything
Hyprland --verify-config -c "$REPO/hypr/hyprland.lua" 2>&1 | grep -q 'config ok' || {
    echo "The saved Hyprland config is not valid, nothing was restored." >&2
    Hyprland --verify-config -c "$REPO/hypr/hyprland.lua" >&2
    exit 1
}

echo "Backing up current config to $BACKUP"
mkdir -p "$BACKUP/state"
for d in hypr dms alacritty fish; do
    [[ -e "$CFG/$d" ]] && cp -r "$CFG/$d" "$BACKUP/"
done
[[ -f "$STATE/dms/session.json" ]] && cp "$STATE/dms/session.json" "$BACKUP/state/"
mkdir -p "$BACKUP/cursor"
[[ -f "$HOME/.icons/default/index.theme" ]] && cp "$HOME/.icons/default/index.theme" "$BACKUP/cursor/"
[[ -f "$CFG/environment.d/90-cursor.conf" ]] && cp "$CFG/environment.d/90-cursor.conf" "$BACKUP/cursor/"
[[ -d "$HOME/.icons/Hacked-Red" ]] && cp -a "$HOME/.icons/Hacked-Red" "$BACKUP/cursor/"
[[ -f "$CFG/environment.d/90-ssh-agent.conf" ]] && cp "$CFG/environment.d/90-ssh-agent.conf" "$BACKUP/"
[[ -d "$CLAUDE_PROJECT" ]] && mkdir -p "$BACKUP/claude" && cp -r "$CLAUDE_PROJECT/." "$BACKUP/claude/"

# Hyprland
mkdir -p "$CFG/hypr/dms"
cp "$REPO/hypr/"*.lua "$CFG/hypr/"
cp "$REPO/hypr/dms/"*.lua "$CFG/hypr/dms/"
[[ -d "$REPO/hypr/scripts" ]] && cp -r "$REPO/hypr/scripts" "$CFG/hypr/"

# DMS
mkdir -p "$CFG/dms" "$STATE/dms"
cp -r "$REPO/dms/config/." "$CFG/dms/"
cp "$REPO/dms/state/session.json" "$STATE/dms/"

# Alacritty
mkdir -p "$CFG/alacritty"
cp "$REPO/alacritty/"*.toml "$CFG/alacritty/"

# fish: install it (and zoxide, used by config.fish) if missing, copy the config, make it the default shell
missing=()
for p in fish zoxide; do command -v "$p" >/dev/null || missing+=("$p"); done
if (( ${#missing[@]} )); then
    echo "Installing ${missing[*]} (needs sudo)"
    sudo dnf install -y "${missing[@]}"
fi
mkdir -p "$CFG/fish"
cp -r "$REPO/fish/." "$CFG/fish/"
fish_path="$(command -v fish)"
if [[ "$(getent passwd "$(id -un)" | cut -d: -f7)" != "$fish_path" ]]; then
    echo "Setting fish as the default shell (asks for your password)"
    chsh -s "$fish_path"
fi

# Cursor
mkdir -p "$HOME/.icons/default" "$CFG/environment.d"
cp "$REPO/cursor/index.theme" "$HOME/.icons/default/"
cp "$REPO/cursor/90-cursor.conf" "$CFG/environment.d/"
rm -rf "$HOME/.icons/Hacked-Red"
cp -a "$REPO/cursor/Hacked-Red" "$HOME/.icons/"

# SSH agent (needs the gcr and gnome-keyring packages)
cp "$REPO/ssh-agent/90-ssh-agent.conf" "$CFG/environment.d/"
systemctl --user enable gcr-ssh-agent.socket 2>/dev/null || echo "Could not enable gcr-ssh-agent.socket (is gcr installed?)"

# Claude Code sessions and memory (resume with: claude --resume <session id>)
if [[ -d "$REPO/claude" ]]; then
    mkdir -p "$CLAUDE_PROJECT"
    cp -r "$REPO/claude/." "$CLAUDE_PROJECT/"
fi

# Wallpaper: copied to the path session.json expects if it is missing
wp="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wallpaperPath",""))' "$REPO/dms/state/session.json")"
if [[ -n "$wp" && ! -f "$wp" && -f "$REPO/wallpaper/$(basename "$wp")" ]]; then
    mkdir -p "$(dirname "$wp")"
    cp "$REPO/wallpaper/$(basename "$wp")" "$wp"
fi

echo "Done. Hyprland reloads its config on its own (or run: hyprctl reload); for DMS: dms restart"
