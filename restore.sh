#!/usr/bin/env bash
# Sets up Hyprland + DMS from this folder, also on a fresh Fedora install (Workstation or a
# minimal install): installs the missing packages (DMS, Hyprland, Alacritty, fish, plus the
# desktop basics a minimal install lacks: graphics, audio, fonts, login screen...), then
# restores the saved config.
# Before overwriting anything, it backs up the current config to ~/.config-backups/<date>.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
BACKUP="$HOME/.config-backups/$(date +%Y%m%d-%H%M%S)"
# Claude Code keeps sessions per directory, named after its path with non-alphanumerics as "-"
CLAUDE_PROJECT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$(printf '%s' "$REPO" | sed 's/[^a-zA-Z0-9]/-/g')"
# COPRs: Dux Labs, the DMS developers (duxlabs/dms ships the shell; duxlabs/dux-repo ships
# quickshell, matugen, dux-search, dux-gop, dux-files, dux-greeter...; they replace the
# deprecated avengemedia/dms and avengemedia/danklinux) and Hyprland (the one recommended by
# the Hyprland wiki for Fedora)
DMS_COPRS=(duxlabs/dms duxlabs/dux-repo)
HYPR_COPR="lionheartp/Hyprland"
HYPR_REPO_ID="copr:copr.fedorainfracloud.org:lionheartp:Hyprland"
# Installed with weak deps (DMS recommends cava, qt6ct, qt6-qtmultimedia...).
# breeze-icon-theme: breeze-dark is one of the fallbacks of the Sweet-Red icon theme.
# lua-devel, make: to build the hyprexpo plugin (hyprexpo.sh).
PACKAGES=(dms dux-search matugen dux-gop alacritty fish zoxide gcr gnome-keyring
    breeze-icon-theme xdg-desktop-portal-gtk lua-devel make)
# dux-files: file manager from the DMS developers (duxlabs/dux-repo; its weak deps
# gvfs and udisks2 handle trash, network places and USB drives)
# GNOME apps: gnome-disk-utility (Disks: partitions, formatting, SMART, disk images; asks for
# root through the DMS polkit agent), baobab (Disk Usage Analyzer) and gnome-boxes (virtual
# machines; pulls QEMU/KVM and libvirt, whose sockets the package presets enable)
PACKAGES+=(dux-files gnome-disk-utility baobab gnome-boxes)
# More GNOME apps: loupe (Image Viewer), papers (Document Viewer: PDF...), decibels (Audio
# Player), showtime (Video Player), snapshot (Camera), gnome-calculator
PACKAGES+=(loupe papers decibels showtime snapshot gnome-calculator)
# dux-edit: text editor from Dux Labs (dedit), for quick edits outside VS Code
PACKAGES+=(dux-edit)
# Wine (Fedora's build; pulls the 32-bit libraries for older Windows apps) and winetricks
PACKAGES+=(wine winetricks)
# Codecs for the GStreamer apps (Showtime, Decibels...): what Fedora ships without RPM Fusion.
# openh264 comes from Fedora's Cisco repo; installed apart with --skip-unavailable so a
# missing one doesn't stop the rest
CODECS=(gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-plugins-ugly-free
    gstreamer1-plugin-libav gstreamer1-plugin-openh264 gstreamer1-plugin-dav1d ffmpeg-free)
# Flatpak with Flathub (remote added below) and GNOME Software as the app store (its flatpak
# plugin is built in; it talks to dnf through dnf5daemon, started on demand over D-Bus).
# code: VS Code from Microsoft's repo (set up below, before installing)
PACKAGES+=(flatpak gnome-software code)
# Desktop basics that Fedora Workstation has and a minimal install doesn't:
# graphics (Intel/AMD; NVIDIA needs RPM Fusion), audio (DMS volume uses PipeWire), battery and
# power profiles, Wi-Fi and Bluetooth, fonts (DMS uses Fira Code as monospace), xdg tools,
# python3 (reads session.json below), git (hyprexpo.sh clones the plugin), libva-utils (vainfo),
# dconf (stores gsettings; without it settings like the icon theme are lost)
PACKAGES+=(python3 git-core libva-utils dconf mesa-dri-drivers mesa-vulkan-drivers
    pipewire pipewire-pulseaudio wireplumber
    upower power-profiles-daemon NetworkManager-wifi bluez polkit xdg-utils xdg-user-dirs
    google-noto-sans-vf-fonts google-noto-sans-mono-vf-fonts google-noto-color-emoji-fonts
    fira-code-fonts)
# Login screen, only when there is no display manager yet (a minimal install has none;
# on Workstation GDM is kept): greetd with the DMS greeter
if [[ ! -e /etc/systemd/system/display-manager.service ]]; then
    PACKAGES+=(greetd dux-greeter)
    SETUP_GREETER=1
fi
# Installed without weak deps: they pull a bar, a launcher and kitty, which DMS already covers.
# hyprland-guiutils: dialogs Hyprland runs (app not responding, permissions, update news);
# without it Hyprland shows a warning on every login.
# hyprland-devel: Hyprland headers (and compiler) to build the hyprexpo plugin.
HYPR_PACKAGES=(hyprland xdg-desktop-portal-hyprland hyprland-guiutils hyprland-devel)

# Whether a repo is configured (enabled or not); `dnf repo info` exits 0 even for unknown repos
has_repo() { dnf -q repo list --all 2>/dev/null | awk '{print $1}' | grep -qx "$1"; }
# Packages: only the missing ones, so on an already set up system nothing is asked.
# Checked by capability, so replacements count (e.g. mesa-vulkan-drivers-freeworld).
missing() { for p in "$@"; do rpm -q --whatprovides "$p" >/dev/null 2>&1 || echo "$p"; done; }
mapfile -t need < <(missing "${PACKAGES[@]}")
mapfile -t need_hypr < <(missing "${HYPR_PACKAGES[@]}")
mapfile -t need_codecs < <(missing "${CODECS[@]}")
# hyprland-devel must be the same version as an already installed hyprland
if rpm -q hyprland >/dev/null 2>&1; then
    need_hypr=("${need_hypr[@]/#hyprland-devel/hyprland-devel-$(rpm -q --qf '%{version}-%{release}' hyprland)}")
fi
if (( ${#need[@]} + ${#need_hypr[@]} )); then
    echo "Installing ${need[*]} ${need_hypr[*]} (needs sudo)"
    # dnf copr and dnf config-manager come from dnf5-plugins
    rpm -q dnf5-plugins >/dev/null || sudo dnf install -y dnf5-plugins
    for c in "${DMS_COPRS[@]}"; do sudo dnf copr enable -y "$c"; done
    sudo dnf copr enable -y "$HYPR_COPR"
    # The Hyprland COPR also ships quickshell and matugen; keep the versions DMS depends on
    sudo dnf config-manager setopt "$HYPR_REPO_ID.excludepkgs=quickshell,matugen"
    # Nobara's terra repo ships a newer glaze-devel that doesn't provide glaze-static, which
    # hyprland-devel needs (from the Hyprland COPR); this adds to terra's own exclude list
    if has_repo terra; then
        sudo dnf config-manager setopt "terra.excludepkgs=glaze-devel"
    fi
    # VS Code: Microsoft's repo and signing key (the official instructions)
    if [[ ! -f /etc/yum.repos.d/vscode.repo ]]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        printf '%s\n' "[code]" "name=Visual Studio Code" \
            "baseurl=https://packages.microsoft.com/yumrepos/vscode" "enabled=1" \
            "autorefresh=1" "type=rpm-md" "gpgcheck=1" \
            "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" |
            sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
    fi
    if (( ${#need[@]} )); then sudo dnf install -y "${need[@]}"; fi
    if (( ${#need_hypr[@]} )); then
        sudo dnf install -y --setopt=install_weak_deps=False "${need_hypr[@]}"
    fi
fi
if (( ${#need_codecs[@]} )); then
    echo "Installing codecs: ${need_codecs[*]} (needs sudo)"
    if has_repo fedora-cisco-openh264; then
        sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
    fi
    sudo dnf install -y --skip-unavailable "${need_codecs[@]}"
fi

# Hardware video decoding (H.264/H.265...): Fedora's Mesa and Intel drivers leave out the
# patented codecs, so these come from RPM Fusion (free for AMD's Mesa driver, nonfree for
# Intel's). Without them video still plays, decoded on the CPU (more battery). The GPU vendor
# comes from sysfs (lspci is not on a minimal install): 0x1002 AMD, 0x8086 Intel.
gpus="$(cat /sys/class/drm/card*/device/vendor 2>/dev/null | sort -u)"
hwdec=()
grep -qx 0x1002 <<<"$gpus" && ! rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1 && hwdec+=(amd)
grep -qx 0x8086 <<<"$gpus" && ! rpm -q intel-media-driver >/dev/null 2>&1 && hwdec+=(intel)
if (( ${#hwdec[@]} )); then
    echo "Setting up hardware video decoding (${hwdec[*]}) from RPM Fusion (needs sudo)"
    if ! has_repo rpmfusion-free || ! has_repo rpmfusion-nonfree; then
        fedora="$(rpm -E %fedora)"
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$fedora.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fedora.noarch.rpm"
    fi
    if [[ " ${hwdec[*]} " == *" amd "* ]]; then
        if rpm -q mesa-va-drivers >/dev/null 2>&1; then
            sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
        else
            sudo dnf install -y mesa-va-drivers-freeworld
        fi
    fi
    if [[ " ${hwdec[*]} " == *" intel "* ]]; then
        # Replaces Fedora's libva-intel-media-driver if installed
        sudo dnf install -y --allowerasing intel-media-driver
    fi
fi

# Flathub, for Flatpak apps (from GNOME Software or `flatpak install flathub <app>`)
if ! flatpak remotes --system --columns=name | grep -qx flathub; then
    echo "Adding the Flathub remote (needs sudo)"
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi
# Zen Browser (Flatpak from Flathub, system-wide like on the desktop)
if ! flatpak info --system app.zen_browser.zen >/dev/null 2>&1; then
    echo "Installing Zen Browser from Flathub (needs sudo)"
    sudo flatpak install -y --noninteractive flathub app.zen_browser.zen
fi

# Bluetooth is not enabled on a minimal install
if ! systemctl is-enabled -q bluetooth.service 2>/dev/null; then
    echo "Enabling Bluetooth (needs sudo)"
    sudo systemctl enable bluetooth.service
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
cp "$REPO/hypr/xdph.conf" "$CFG/hypr/"
[[ -d "$REPO/hypr/scripts" ]] && cp -r "$REPO/hypr/scripts" "$CFG/hypr/"
# Workspace overview plugin (Super+Tab); without it Super+Tab is the DMS overview
"$REPO/hyprexpo.sh" || echo "hyprexpo was not built: Super+Tab stays the DMS overview" >&2

# DMS: config, session state, and started with the Hyprland session (dms.service is a
# systemd user service; `dms setup` normally adds this link). dsearch.service (from
# dux-search) is the file index behind the "/" file search in DMS; its preset is disabled.
mkdir -p "$CFG/dms" "$STATE/dms"
cp -r "$REPO/dms/config/." "$CFG/dms/"
cp "$REPO/dms/state/session.json" "$STATE/dms/"
systemctl --user add-wants hyprland-session.target dms.service
systemctl --user enable --now dsearch.service
# Icon theme: DMS applies it through gsettings, and at startup it compares gsettings with the
# theme it applied last (session.json); on a fresh system gsettings still says Adwaita, so DMS
# takes it for an outside change and switches to "System Default". Set it beforehand.
icon_theme="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("iconThemeDark",""))' "$REPO/dms/config/settings.json")"
if [[ -n "$icon_theme" && "$icon_theme" != "System Default" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
fi

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

# Standard user folders (Documents, Downloads...), which a minimal install doesn't create
xdg-user-dirs-update

# Dux Files opens folders (xdg-open, "show in folder" from apps); saved in ~/.config/mimeapps.list
xdg-mime default dev.duxlabs.files.desktop inode/directory
# Zen opens web links and HTML files
if [[ -f /var/lib/flatpak/exports/share/applications/app.zen_browser.zen.desktop ]]; then
    xdg-mime default app.zen_browser.zen.desktop x-scheme-handler/http x-scheme-handler/https \
        text/html application/xhtml+xml
fi
# Default apps for images, documents, audio and video: every type each app declares
for app in org.gnome.Loupe org.gnome.Papers org.gnome.Decibels org.gnome.Showtime; do
    f="/usr/share/applications/$app.desktop"
    [[ -f "$f" ]] || continue
    read -ra types < <(sed -n 's/^MimeType=//p' "$f" | tr ';' ' ')
    (( ${#types[@]} )) && xdg-mime default "$app.desktop" "${types[@]}"
done

echo "Done. Hyprland reloads its config on its own (or run: hyprctl reload); for DMS: dms restart"

# Login screen (minimal install). Last, once everything else succeeded (set -e stops the script
# on any error before this), because `dms-greeter enable` starts greetd right away.
# sync copies the DMS theme, wallpaper and settings to the greeter; it refuses to run unless
# the user is in the greeter group, which is new in this login, hence sg. enable writes the
# greetd config, PAM and SELinux bits and enables greetd (it asks for sudo itself).
if [[ -n "${SETUP_GREETER:-}" ]]; then
    echo "Setting up the DMS greeter as the login screen (reboot afterwards if it doesn't show up)"
    id -nG | grep -qw greeter || sudo usermod -aG greeter "$(id -un)"
    sg greeter -c "dms-greeter sync" ||
        echo "dms-greeter sync failed; run it again after logging in to Hyprland" >&2
    sudo systemctl set-default graphical.target
    dms-greeter enable
fi
