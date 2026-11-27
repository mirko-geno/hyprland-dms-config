#!/usr/bin/env bash
# Builds the hyprexpo workspace overview plugin (github.com/sandwichfarm/hyprexpo) for the
# installed Hyprland and installs it to ~/.local/lib/hyprexpo, where hypr/hyprexpo.lua loads it.
# Run by restore.sh; run it again after every Hyprland update.
# Needs hyprland-devel (same version as hyprland) and lua-devel.
set -euo pipefail

REPO_URL="https://github.com/sandwichfarm/hyprexpo"
DEST="$HOME/.local/lib/hyprexpo/hyprexpo.so"
# Hyprland build the installed plugin was built for (skips rebuilding; --force rebuilds anyway)
STAMP="$HOME/.local/lib/hyprexpo/hyprland-build"
HEADER="/usr/include/hyprland/src/version.h"

[[ -f "$HEADER" ]] || { echo "hyprexpo: hyprland-devel is not installed" >&2; exit 1; }

# The plugin must be built against the exact Hyprland build it runs in: same package release,
# not only the same commit (a COPR rebuild against new libraries keeps the commit)
build="$(rpm -q --qf '%{version}-%{release}' hyprland)"
devel="$(rpm -q --qf '%{version}-%{release}' hyprland-devel)"
if [[ "$build" != "$devel" ]]; then
    echo "hyprexpo: hyprland-devel ($devel) doesn't match the installed Hyprland ($build);" \
        "update both: sudo dnf upgrade hyprland hyprland-devel" >&2
    exit 1
fi
commit="$(sed -n 's/^#define GIT_COMMIT_HASH *"\(.*\)"/\1/p' "$HEADER")"

if [[ "${1:-}" != "--force" && -f "$DEST" && "$(cat "$STAMP" 2>/dev/null)" == "$build" ]]; then
    echo "hyprexpo is already built for this Hyprland"
    exit 0
fi

# The plugin links the same Lua as Hyprland. The fork asks for Lua 5.5 (upstream Hyprland 0.57),
# but the COPR builds Hyprland against Fedora's Lua 5.4; the plugin only uses Lua C functions
# that are the same in both, so the version check is skipped (-o check-lua) when they match.
hypr_lua="$(ldd "$(command -v Hyprland)" | sed -n 's/.*liblua-\([0-9.]*\)\.so.*/\1/p' | head -1)"
dev_lua="$(pkg-config --modversion lua | cut -d. -f1,2)"
if [[ -n "$hypr_lua" && "$hypr_lua" != "$dev_lua" ]]; then
    echo "hyprexpo: Hyprland uses Lua $hypr_lua but lua-devel is $dev_lua" >&2
    exit 1
fi

src="$(mktemp -d)"
trap 'rm -rf "$src"' EXIT
git clone -q "$REPO_URL" "$src"

# hyprpm.toml pins a plugin commit per Hyprland commit: ["<hyprland>", "<plugin>"], # <version>
pin="$(sed -n "s/.*\[\"$commit\", *\"\([0-9a-f]*\)\"\].*/\1/p" "$src/hyprpm.toml" | head -1)"
if [[ -z "$pin" ]]; then
    echo "hyprexpo: no plugin version for Hyprland $(pkg-config --modversion hyprland) ($commit) yet;" \
        "Super+Tab stays the DMS overview until the fork adds one (then run this again)" >&2
    exit 1
fi
git -C "$src" checkout -q "$pin"

echo "Building hyprexpo ${pin:0:7} for Hyprland $(pkg-config --modversion hyprland)"
make -C "$src" -o check-lua LUA_PKG_CONFIG=lua -j"$(nproc)" hyprexpo.so >/dev/null
# install replaces the file instead of writing into it: overwriting a loaded .so crashes Hyprland
install -Dm755 "$src/hyprexpo.so" "$DEST"
echo "$build" > "$STAMP"
echo "Installed $DEST"

# Load it now if the running Hyprland is the installed binary. After an update the session still
# runs the old, replaced one ("/usr/bin/Hyprland (deleted)") until re-login, even with the same commit.
running="$(readlink "/proc/$(pidof -s Hyprland)/exe" 2>/dev/null || true)"
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" && "$running" == "$(readlink -f "$(command -v Hyprland)")" ]]; then
    hyprctl plugin unload "$DEST" >/dev/null 2>&1 || true
    hyprctl plugin load "$DEST" >/dev/null && hyprctl reload >/dev/null && echo "Loaded in the running Hyprland"
else
    echo "It loads on the next Hyprland login"
fi
