# Void capability matrix

This is the delivery ledger for user-selectable iNiR capabilities on Void.
The contract terms are defined by ADR-0004. A row reaches **supported** only
after provider, provisioning, activation, operation, and verification pass.

| Capability | Profile | Void provider | Activation | Current state | Owner |
|---|---|---|---|---|---|
| Niri + Quickshell | base | XBPS `niri`, `quickshell`, Qt 6 packages | session supervisor | VM validated | PR1-PR3.2 |
| Session D-Bus and login | base | XBPS `dbus`, `elogind`, `turnstile` | confirmed runit services + turnstile | VM validated | PR3.1 |
| iNiR lifecycle | base | installed launcher | systemd, turnstile, or runsvdir by predicate | VM validated | PR3.0-PR3.2 |
| Network | base | XBPS `NetworkManager` | runit service | package present; activation audit pending | PR4 |
| Bluetooth | toolkit | XBPS BlueZ provider + `blueman` | runit service | provider/activation audit pending | PR4 |
| Awww wallpaper | base | official XBPS `awww` | systemd transient unit or session daemon by predicate | package and runtime adapter pending | PR3.3 |
| GameMode | base | built into iNiR | session process | core works; obsolete `discover-overlay` control pending removal | PR3.3 |
| Screenshots | screencapture | XBPS `grim`, `slurp`, `swappy`, `wl-clipboard`, `jq` | direct session processes | packages/runtime fallback audit pending | PR3.3 |
| Screen recording | screencapture | XBPS `wf-recorder`, `ffmpeg`, PipeWire tools | direct session processes | `pipewire-pulse`/audio verification pending | PR3.3 |
| Clipboard history and paste | base/toolkit | XBPS `wl-clipboard`, `cliphist`; upstream ydotool provider TBD | session watchers + ydotool service | copy works; simulated paste provider pending | PR4 |
| Cloudflare WARP | toolkit | upstream provider TBD | runit system service | visible UI exists; provider and lifecycle pending | PR4 |
| Mission Center | toolkit | maintained Flatpak | Flatpak application | provisioning/launcher pending | PR5 |
| OCR | toolkit | XBPS Tesseract + user-space language download | direct process | English/Spanish VM validated; full language flow pending | PR5 |
| Themes, icons, cursors | fonts/theme | XBPS first, pinned upstream fallback | files/config only | unavailable Arch defaults need Void providers | PR5 |
| Package updates/search/catalog | base | XBPS | direct commands with confirmed elevation | not implemented | PR6 |
| Doctor and ABI repair | base | XBPS diagnostics | direct commands | partial | PR7 |

## Rules

- Profiles exposed by the Void installer match the Arch installer model.
- Missing optional profiles do not block the base shell, but selecting a
  profile must install all providers required by that profile.
- WARP remains visible while its provider is developed, but it must report an
  unavailable provider rather than issue a systemd command on Void.
- Packaging iNiR itself as an XBPS package remains outside V1. This matrix
  covers the per-user installer.
- Exact package names and upstream versions move from **TBD** only after they
  are validated in the Void VM.
