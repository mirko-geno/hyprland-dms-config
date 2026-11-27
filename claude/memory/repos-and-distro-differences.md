---
name: repos-and-distro-differences
description: "Always flag which repos a change needs (COPR, RPM Fusion, third-party) and Nobara-vs-Fedora differences; user wants these explained up front"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 42c16d2b-9a8e-429b-9088-fb4b39241420
  modified: 2026-11-27T06:05:19.934Z
---

When adding packages or setup steps, say up front which repo each one comes from and whether a
plain Fedora (especially the fedora-minimal target) has that repo. Call out Nobara-only things
(terra, nobara repos, winehq-staging, Nobara's codec packages) instead of assuming the desktop's
state carries over.

**Why:** 2026-11-27 the user asked "why do we want terra? do we need RPM Fusion / third-party
repos?" after a terra-only step broke restore.sh in a Fedora 45 VM; they said "recordá ese tipo
de cuestiones". The desktop is Nobara 44 (terra, nobara repos, codecs preinstalled); the notebook
target is plain Fedora minimal, which has only fedora, updates and fedora-cisco-openh264.

**How to apply:** for each new package check `dnf repoquery --qf '%{reponame}'` and note when it
comes from a Nobara repo. Repos restore.sh adds on purpose: duxlabs/dms, duxlabs/dux-repo,
lionheartp/Hyprland, Microsoft's vscode repo, Flathub, and RPM Fusion free+nonfree only when the GPU is
AMD or Intel (HW video decoding: mesa-va-drivers-freeworld / intel-media-driver). Not added: terra (Nobara-only; the
script only adds a glaze-devel exclude when terra exists). dnf5 `repo info X` exits 0 even for
unknown repos: use `dnf repo list --all` (restore.sh `has_repo`). Conflicting alternatives:
require the capability, not a package name (power profiles: Fedora 41+ ships tuned-ppd, Nobara
power-profiles-daemon, both provide ppd-service and conflict; Wine: Nobara's winehq-staging
conflicts with Fedora's wine). See [[hyprland-dms-setup]].
