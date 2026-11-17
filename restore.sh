#!/usr/bin/env bash
# Sets up Hyprland + DMS from this folder, also on a fresh Fedora install: installs the missing
# packages (DMS, Hyprland, Alacritty, fish...), then restores the saved config.
# Before overwriting anything, it backs up the current config to ~/.config-backups/<date>.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
BACKUP="$HOME/.config-backups/$(date +%Y%m%d-%H%M%S)"
# Claude Code keeps sessions per directory, named after its path with non-alphanumerics as "-"
CLAUDE_PROJECT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$(printf '%s' "$REPO" | sed 's/[^a-zA-Z0-9]/-/g')"
# COPRs: DMS (enabling it also enables its dependency repo avengemedia/danklinux, which
# ships quickshell, matugen, dgop, danksearch...) and Hyprland (the one recommended by the
# Hyprland wiki for Fedora)
DMS_COPR="avengemedia/dms"
HYPR_COPR="lionheartp/Hyprland"
HYPR_REPO_ID="copr:copr.fedorainfracloud.org:lionheartp:Hyprland"
# Installed with weak deps (DMS recommends cava, qt6ct, qt6-qtmultimedia...).
# breeze-icon-theme: breeze-dark is one of the fallbacks of the Sweet-Red icon theme.
PACKAGES=(dms danksearch matugen dgop alacritty fish zoxide gcr gnome-keyring
    breeze-icon-theme xdg-desktop-portal-gtk)
# Installed without weak deps: they pull a bar, a launcher and kitty, which DMS already covers
HYPR_PACKAGES=(hyprland xdg-desktop-portal-hyprland)

# Packages: only the missing ones, so on an already set up system nothing is asked
missing() { for p in "$@"; do rpm -q "$p" >/dev/null 2>&1 || echo "$p"; done; }
mapfile -t need < <(missing "${PACKAGES[@]}")
mapfile -t need_hypr < <(missing "${HYPR_PACKAGES[@]}")
if (( ${#need[@]} + ${#need_hypr[@]} )); then
    echo "Installing ${need[*]} ${need_hypr[*]} (needs sudo)"
    # dnf copr and dnf config-manager come from dnf5-plugins
    rpm -q dnf5-plugins >/dev/null || sudo dnf install -y dnf5-plugins
    sudo dnf copr enable -y "$DMS_COPR"
    sudo dnf copr enable -y "$HYPR_COPR"
    # The Hyprland COPR also ships quickshell and matugen; keep the versions DMS depends on
    sudo dnf config-manager setopt "$HYPR_REPO_ID.excludepkgs=quickshell,matugen"
    if (( ${#need[@]} )); then sudo dnf install -y "${need[@]}"; fi
    if (( ${#need_hypr[@]} )); then
        sudo dnf install -y --setopt=install_weak_deps=False "${need_hypr[@]}"
    fi
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
for t in "$REPO/icons/"*/; do
    t="$(basename "$t")"
    [[ -d "$HOME/.icons/$t" ]] && mkdir -p "$BACKUP/icons" && cp -a "$HOME/.icons/$t" "$BACKUP/icons/"
done
[[ -f "$CFG/environment.d/90-ssh-agent.conf" ]] && cp "$CFG/environment.d/90-ssh-agent.conf" "$BACKUP/"
[[ -d "$CLAUDE_PROJECT" ]] && mkdir -p "$BACKUP/claude" && cp -r "$CLAUDE_PROJECT/." "$BACKUP/claude/"

# Hyprland
mkdir -p "$CFG/hypr/dms"
cp "$REPO/hypr/"*.lua "$CFG/hypr/"
cp "$REPO/hypr/dms/"*.lua "$CFG/hypr/dms/"
[[ -d "$REPO/hypr/scripts" ]] && cp -r "$REPO/hypr/scripts" "$CFG/hypr/"

# DMS: config, session state, and started with the Hyprland session (dms.service is a
# systemd user service; `dms setup` normally adds this link)
mkdir -p "$CFG/dms" "$STATE/dms"
cp -r "$REPO/dms/config/." "$CFG/dms/"
cp "$REPO/dms/state/session.json" "$STATE/dms/"
systemctl --user add-wants hyprland-session.target dms.service

# Alacritty
mkdir -p "$CFG/alacritty"
cp "$REPO/alacritty/"*.toml "$CFG/alacritty/"

# fish (installed above, with zoxide used by config.fish): copy the config, make it the default shell
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

# Icon themes (Sweet-Red, set in DMS, and candy-icons, which it inherits from)
for t in "$REPO/icons/"*/; do
    rm -rf "$HOME/.icons/$(basename "$t")"
    cp -a "$t" "$HOME/.icons/"
done

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
