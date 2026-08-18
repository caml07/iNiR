# iNiR on Void Linux

Guide for the Void Linux port of iNiR (glibc + runit + XBPS). The port is
**in progress** — this document is the spec the implementation is being
built against and will be revised after VM validation. Decisions: see
`docs/adr/`; glossary: see `CONTEXT.md`.

## Status

- V1 scope: **per-user installer works on Void** (same install path as Arch,
  no root). An XBPS package is a separate milestone (see Packaging).
- Non-goals for V1 (documented as *compatibility profiles*, not supported):
  musl libc; `seatd` without elogind; building ydotool from source.
- Validation: QEMU VM first (see VM validation), then a small real partition.

## How the port decides what to do

Everything systemd-sensitive is gated by one predicate, never by distro name:

```
usable systemd user manager =
    -S $XDG_RUNTIME_DIR/systemd/private          (socket exists)
    AND `timeout 3s systemctl --user show-environment` answers
```

Void can run systemd; Arch can lack a user manager. See ADR-0002.

## Session supervisor (non-systemd)

Three tiers, decided by the predicate (ADR-0001):

1. **systemd** (predicate holds) → `inir.service`, as on Arch.
2. **turnstile** (`turnstiled` service running) → per-user service
   `~/.config/service/inir/run`:
   ```sh
   #!/bin/sh
   exec /path/to/inir run --session
   ```
   - Turnstile also provides the session D-Bus bus:
     `core_services="dbus"` in `~/.config/service/turnstile-ready/conf`.
   - With elogind: `manage_rundir=no` in `/etc/turnstile/turnstiled.conf`.
   - Session env for services: `turnstile-update-runit-env VAR=value`, read
     with `exec chpst -e "$TURNSTILE_ENV_DIR" ...`.
3. **runsvdir fallback** (zero system deps) → Niri spawns it:
   ```kdl
   spawn-sh-at-startup "exec runsvdir ~/.config/service"
   ```
   Niri kills its spawns on exit; session env is inherited from Niri.

Control: `sv restart|down|up ~/.config/service/inir` (non-systemd
equivalent of `systemctl --user`). `inir logs` → `sv status` (journalctl
does not exist without systemd).

## Session

- Supported session entry: `niri-session` (Void's, provided by the `niri`
  package). It execs `niri --session` and wraps in `dbus-run-session` when
  `DBUS_SESSION_BUS_ADDRESS` is unset (the turnstile path already has a bus).
- Manual `niri` launches are unsupported: doctor warns when the session
  lacks a D-Bus bus.
- Env propagation without systemd: `dbus-update-activation-environment`
  (replaces `systemctl --user set-environment`), or turnstile's envdir.

## System services (installed once, requires root)

Auto-enabled with confirmation during setup (`ln -s /etc/sv/<svc> /var/service/`):

- `dbus` — system D-Bus (required by elogind/polkitd)
- `elogind` — logind replacement: `/run/user/$UID`, `loginctl`, power/suspend
- `polkitd` — policykit daemon (GUI sudo prompts)
- `turnstiled` — per-user services + session bus (tier 2 supervisor)

Guided only (never auto-enabled): `seatd` (+ `_seatd` group) and `sddm`
(package built with `-DUSE_ELOGIND=ON`).

## Dependencies (XBPS)

Primary profile (glibc + elogind): `niri`, `quickshell` (repo, not compiled),
`elogind`, `dbus`, `polkit`, `seatd`, `turnstile`, `xdg-desktop-portal-gtk`,
`xdg-desktop-portal-wlr`, `polkit-gnome`, `qt6-qt5compat` (not `qt6-5compat`),
`uv` (repo), `NetworkManager`, `pipewire`, `wl-clipboard`, `cliphist`,
`grim`, `slurp`, `swappy`, `swayidle`, `swaylock`, `gum`, `dunst`, fonts, etc.

Notes:

- Quickshell from the Void repo is rebuilt by Void in lockstep with Qt
  updates, so the Qt/Quickshell ABI check (`check_qs_abi`) self-heals.
  `deps-map.sh` must say `void:quickshell`, not `void:COMPILE`.
- `kf6-kirigami` / `kf6-syntax-highlighting` are needed only for the
  compile-from-source profile, not the base install.
- `ydotool` is NOT packaged in Void; compiling it is a compatibility profile.
- `ddcutil` on musl needs `libexecinfo-devel` + `musl-legacy-compat`.
- Repo sanity: `xbps-query -L` (doctor check).

## Package management UI (Updates / PackageSearch / AppCatalog)

- Updates check (no root): `xbps-install -nu` (list available updates).
- Update all: `sudo xbps-install -Su` (terminal, `_runTerminalScript`).
- Search: `xbps-query -Rs "<query>" | head -200`.
- Installed: `xbps-query -s "<query>"`.
- Install: `sudo xbps-install -S -- "<pkg>"`; remove: `sudo xbps-remove -Rns -- "<pkg>"`.
- App catalog: add `xbps` targets to `defaults/app-catalog.json`.

## Packaging

V1 ships through the per-user installer. An XBPS package is a later
milestone with its own recipe (documented here, not yet built):

- Template for `xbps-src` (Void's build tool): requires a local
  `void-packages` checkout and an `xbps-src` chroot to build.
- Do NOT call `make install` in the template — it installs the systemd unit
  (`install-systemd` target, `Makefile:54`). Use the partial targets
  (`install-bin`, `install-shell`, `install-icon`, `install-desktop`,
  `install-docs`) or copy `sdata/runtime-root-files.txt` /
  `runtime-payload-dirs.txt` payloads directly.
- `version.json` must report `install_mode: package-managed`,
  `package_manager: xbps` (`INIR_PACKAGE_MANAGER`), so iNiR updates via
  `xbps-install -Su` instead of `inir update`.
- Upstream (void-packages) submission is unlikely to be accepted for a
  theme/shell script; `distro/void/` in this repo is the official path.

## Startup template

`defaults/niri/config.d/50-startup.kdl` is the single source; setup injects
and removes marked blocks per distro and predicate (ADR-0003). Today the
template has three systemd-hard facts: the `systemctl --user
import-environment XDG_MENU_PREFIX && kbuildsycoca6` line, the
"managed by inir.service" comment, and no runsvdir entry. Injection must be
idempotent, and migration 021 must remove the runsvdir line when the
predicate holds (no double shell on Void+systemd).

## Migration rules

`021-systemd-single-instance` and `022-service-compositor-wants` must be
no-ops when the predicate is false (their `command -v systemctl` check is
not enough — without the user-manager socket, `systemctl --user` hangs for
10-30s).

## VM validation

Recipe (QEMU, KVM available on the host):

```
qemu-system-x86_64 \
  -accel kvm -m 4096 -smp 4 \
  -display gtk \
  -device virtio-gpu \
  -drive file=void.img,format=qcow2,if=virtio \
  -netdev user,id=n1 -device virtio-net-pci,netdev=n1
```

- Graphics: **lavapipe** (Mesa software Vulkan) — install `mesa-dri` in the
  guest; Niri runs on it (slow but functional). No host GPU required.
- Upgrade path (documented, needs host GL + blob support):
  `-device virtio-gpu-gl,hostmem=8G,blob=true,venus=true` (Vulkan via Venus,
  QEMU docs). RAM ≥ 8-10GB.
- Verification order in the VM:
  0. Quickshell 0.3.0 (repo) runs iNiR — the make-or-break check.
  1. Installer end-to-end on a fresh Void.
  2. Session: niri-session → shell supervised (turnstile, then runsvdir).
  3. Services: dbus/elogind/polkitd/turnstiled up.
  4. UI: updates list, search/install/remove via xbps.
  5. `test-local-distribution.sh` with predicate-conditional invariants.

## FAQ / gotchas

- **Two shells after install**: a hand-written startup entry or migration
  021 applied on Void. Remove the `spawn-*`/runsvdir lines.
- **Shell crashes and stays dead**: no supervisor (tier 3 requires the
  runsvdir entry; check `sv status ~/.config/service/inir`).
- **`inir logs` fails**: journalctl is systemd-only; use `sv status` (+
  `svlogd` if you configure a `log` directory for the service).
- **Qt/Quickshell ABI mismatch after a Void Qt update**: transient until
  Void rebuilds quickshell; `inir doctor --fix-abi` gains a Void case
  (`xbps-install -Sf quickshell` or local template rebuild).
- **Suspend/hibernate**: `loginctl suspend` (elogind) replaces
  `systemctl suspend`; `acpid` is the alternative in the seatd profile.

## Sources

- Void handbook: services (`/etc/sv` → `/var/service/`), session management
  (elogind/seatd/turnstile), user services (turnstile),
  `xbps-install`/`xbps-query` usage.
- QEMU docs: virtio-gpu device (venus/gfxstream options), display backends.
- Repo facts: `scripts/inir` (service helpers, `run --session`),
  `sdata/lib/deps-map.sh`, `sdata/subcmd-install/3.files.sh`,
  migrations 021/022, `Makefile`, `scripts/test-local-distribution.sh`.