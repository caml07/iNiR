# iNiR on Void Linux

Guide for the Void Linux port of iNiR (x86_64 glibc + runit + XBPS). The V1 port
implementation is complete through the PR7 engineering-closure sweep plus the
post-closure hardware/provider fixes found on real Void installs. Decisions:
see `docs/adr/`; glossary: see `CONTEXT.md`.

## Status

- V1 scope: **the normal per-user iNiR install path works on Void Linux x86_64
  glibc with runit and elogind/Turnstile**. The shell
  payload lives in the user install just as it does on the repo-managed Arch
  path; XBPS dependency transactions and system-service activation still use
  normal privilege elevation when required. Disruptive service ownership
  changes are confirmation-gated. An iNiR XBPS package is a separate milestone
  (see Packaging).
- Non-goals for V1 (documented as *compatibility profiles*, not supported):
  musl libc, non-x86_64 installs, and `seatd` without elogind. The Niri/
  Quickshell core may be packageable on musl, but the complete provider matrix
  has not been release-qualified and proprietary/prebuilt providers such as
  Cloudflare WARP are glibc-only. See ADR-0005.
- Validation historically used QEMU first and then the external-disk install.
  For the 2.32 closure the exact-SHA physical install/reboot is authoritative;
  QEMU remains an additional fresh-state/VirtIO regression environment. Both
  kinds of evidence are recorded in `docs/VOID_VM_VALIDATION.md`.
- Current 2.32 candidate checkpoint (2026-10-01): a fresh fetch resolved Snow
  `main` and `prerelease` to
  `c08bb928fe71c6a00bfede3e99ef26fb1825ebe2` (`VERSION=2.32.0`). The candidate
  branch integrates that exact tree plus the Void port, regenerates the IPC
  registry from merged QML (70 targets / 403 functions) and the Settings search
  index (1,942 entries), and passes the merged local distribution suite. The
  physical Void install has also passed a real `./setup install`, reboot through
  SDDM, and Doctor 28/28. Doctor was also invoked from a TTY/SSH-style context
  to verify recovery of the live supervised Niri/Quickshell environment. The
  same boot passed live network/audio/Bluetooth/Power Profiles/ydotool checks,
  Qt 6.11 family switching and a real Kira companion smoke. A post-reboot clean-shell
  check also caught and fixed the lazy `packageSearch` IPC target; the final
  physical runtime is synced to `66dfd5f6` and package search works immediately
  after shell startup. The release VM remains a useful follow-up, especially
  for VirtIO/VirGL, but is no longer the blocking gate for the fork's
  `prerelease` branch.

The 2.31 `9574fa42` closure remains useful historical evidence: that cycle
proved clean install/reinstall, reboot/runtime, SDDM graphical login, the
NetworkManager handoff, Power Profiles, Web Wallpaper, ydotool input, Darkly/
Foot repair and the first external-disk hardware gate. Historical SHA/date
references below describe those runs and are not the current upstream tip.

## Installer experience on Void

Use the fork's release-candidate branch for the current Void port:

```bash
git clone https://github.com/caml07/iNiR.git
cd iNiR
git checkout prerelease
./setup install
```

For the first install, keep it interactive so setup can offer the
NetworkManager and SDDM ownership handoffs described below. Later updates from
that repo-managed checkout continue tracking `prerelease` through the normal
`inir update` / `./setup update` flow.

Void does not get a second-class manual-only path. `./setup install` uses the
same TUI shell as the other automated installers and adapts the operations
behind it to XBPS/runit. A normal first run presents:

- the detected distro/package manager, CPU/GPU/RAM/session summary;
- an install plan and backup destination before package/config work starts;
- progress for dependencies, system configuration, config installation and
  version tracking;
- low-memory guidance when the machine is small enough for it to matter;
- a dynamic XBPS free-space check for only the packages still missing, plus
  download/build headroom;
- confirmation-gated system-service changes rather than silently assuming
  systemd or replacing existing service owners.

Two first-install prompts are deliberately special. If Void is still using its
base `dhcpcd`/standalone `wpa_supplicant` stack, setup can migrate it to
NetworkManager with rollback if activation fails. After the install itself is
complete, setup can enable SDDM so the next normal login uses Void's packaged
`niri --session` entry. Non-interactive `-y` runs leave both of those ownership
decisions unchanged.

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
2. **turnstile** (`turnstiled` service active) → per-user service
   `~/.config/service/inir/run`:
   ```sh
   #!/bin/sh
   exec chpst -e "$TURNSTILE_ENV_DIR" /path/to/inir run --session
   ```
   - Turnstile also provides the session D-Bus bus via a dedicated
     user service. Install `~/.config/service/dbus/run` and
     `~/.config/service/dbus/check` from turnstile examples,
     then add `dbus` to `core_services` in
     `~/.config/service/turnstile-ready/conf`.
    - With elogind: `manage_rundir = no` in `/etc/turnstile/turnstiled.conf`.
   - Session env for services: `turnstile-update-runit-env VAR=value`, read
      with `exec chpst -e "$TURNSTILE_ENV_DIR" ...`.
3. **runsvdir fallback** (zero system deps) → Niri spawns it:
   ```kdl
   spawn-sh-at-startup "exec runsvdir ~/.config/service"
   ```
    Niri kills its spawn on exit; session env is inherited from Niri. This is
    distinct from the runsvdir process that turnstile's runit backend owns.

Control: `sv restart|down|up ~/.config/service/inir` (non-systemd
equivalent of `systemctl --user`). `inir logs` → `sv status` (journalctl
does not exist without systemd).

Audio under non-systemd supervisors is also supervised per user:
`~/.config/service/{pipewire,wireplumber,pipewire-pulse}/run`, rendered by
`reconcile_audio_user_services` with `chpst -e "$TURNSTILE_ENV_DIR"` under
turnstile. Only services carrying `# Managed by iNiR.` are touched; user-owned
services are preserved, and the systemd tier removes the owned ones.

## Session

- Normal installed entry is SDDM. The Void base profile installs `sddm` plus
  `xorg-minimal`; after all setup tasks complete, the interactive installer
  offers to enable `/etc/sv/sddm` through runit. On the next boot (and as soon
  as the service is enabled), SDDM presents the graphical login and launches
  Void's packaged Niri desktop entry, whose command is
  `Exec=/usr/bin/niri --session`.
- `niri --session` remains the supported manual fallback from a local TTY for
  recovery/debugging or when the user intentionally declines SDDM. The
  `niri-session` wrapper was not present in the tested Void package.
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
- `power-profiles-daemon` — Quickshell Power Profiles D-Bus provider
- `sddm` — graphical login/display manager. It is offered only after the
  install is complete, refuses activation when D-Bus/Niri session metadata is
  unavailable, and never replaces another enabled display manager.

Guided only (never auto-enabled): `seatd` (+ `_seatd` group).

Note: the session D-Bus bus under turnstile is provided by a **user**
service (`~/.config/service/dbus`), not the system `dbus` service.

## Dependencies (XBPS)

Primary profile (glibc + elogind): `niri`, `quickshell` (repo, not compiled),
`fish-shell` (provides `/usr/bin/fish` used by terminal and iNiR launchers),
`sddm`, `xorg-minimal`,
`elogind`, `dbus`, `polkit`, `seatd`, `turnstile`, `xdg-desktop-portal-gtk`,
`xdg-desktop-portal-wlr`, `polkit-gnome`, `qt6-qt5compat` (not `qt6-5compat`),
`uv` (repo), `NetworkManager`, `bluez`, `blueman`, `pipewire`,
`libspa-bluetooth`, `alsa-pipewire`, `libdbusmenu-gtk3`,
`power-profiles-daemon`, `kf6-kirigami`, `kdialog`, `breeze-icons`,
`qt6ct`, `qt6-webengine`, `layer-shell-qt`, `wl-clipboard`, `cliphist`,
`grim`, `slurp`, `swappy`, `swayidle`, `swaylock`, `gum`, `dunst`, `jq`,
`awww` (official XBPS wallpaper backend), fonts, etc.

Notes:

- Quickshell from the Void repo is rebuilt by Void in lockstep with Qt
  updates, so the Qt/Quickshell ABI check (`check_qs_abi`) self-heals.
  `deps-map.sh` must say `void:quickshell`, not `void:COMPILE`.
- `kf6-syntax-highlighting` and `kf6-kirigami` are base runtime dependencies
  because shared shell components import `org.kde.syntaxhighlighting` and
  `org.kde.kirigami` directly.
- Power Profiles is a visible shell capability. Void provides
  `power-profiles-daemon`, including `powerprofilesctl`, a runit service,
  the `org.freedesktop.UPower.PowerProfiles` D-Bus service, and polkit policy.
  Setup activates it only through the confirmed-elevation system-service step.
- Interactive Web Wallpaper uses the official Void `qt6-webengine` and
  `layer-shell-qt` QML providers. The host is pure Qt QML and prefers `qml6`
  or `qml`; Void's packaged fallback is `/usr/lib/qt6/bin/qml`. Quickshell is
  deliberately not used as the QtWebEngine host. Doctor repairs either missing
  QML provider through XBPS.
- The legacy opt-in Super-tap daemon follows the same user-supervisor tiers as
  the shell: systemd when the ADR-0002 predicate succeeds, otherwise Turnstile
  or the runsvdir fallback. It remains disabled unless
  `II_ENABLE_SUPER_DAEMON=1` is explicitly set.
- `ydotool` is not packaged in the current Void repositories. PR4.2 provides
  verified upstream v1.0.4 source, a predicate-selected user service,
  input-group `/dev/uinput` permissions, and install/Doctor update paths.
  The provider's UI operation is VM validated through the lock-screen keyboard;
  simulated paste uses the same verified daemon path but was not exercised as a
  separate UI action.
- Bluetooth uses the toolkit profile's `bluez` daemon and `blueman` frontend.
  The audio profile adds `libspa-bluetooth` for PipeWire Bluetooth audio.
- The current release target is glibc. Historical musl package notes (for
  example `ddcutil` compatibility packages) are not part of the V1 support
  contract and must not be used to imply that the full shell/provider matrix
  has been qualified on musl.
- Repo sanity: `xbps-query -L` (doctor check).
- Darkly is built from pinned v0.5.39 source with Qt6/KF6 dependencies,
  including `kf6-kdecoration-devel`. The provider requires both
  `styles/darkly6.so` and
  `org.kde.kdecoration3.kcm/kcm_darklydecoration.so`; a style-only install is
  considered incomplete and Doctor can repair it.
- Foot wallpaper theming writes `~/.config/foot/inir-colors.ini`. The shipped
  `foot.ini`, generator, installer repair and uninstall paths all use that
  managed name; the historical `colors.ini` path is legacy cleanup only.

## Capability providers

Void follows the same dependency-profile model as Arch. A selected profile is
supported only when iNiR provisions, activates, operates, and verifies every
capability it exposes. Provider resolution prefers official XBPS packages,
then a maintained Flatpak, then a pinned upstream artifact with an update
path. See ADR-0004 and `docs/VOID_CAPABILITIES.md`.

Cloudflare WARP is deliberately outside those required dependency profiles.
Void does not ship an official `cloudflare-warp` XBPS package, and the WARP
daemon is privileged networking software rather than a normal sandboxed GUI,
so Flatpak is not an appropriate provider. On **Void x86_64 glibc** the setup
Extras menu offers an explicit WARP provider that:

- reads the latest `cloudflare-warp` version, artifact path and SHA-256 from
  Cloudflare's official APT `Packages` metadata;
- falls back to the last in-tree verified artifact if that metadata is
  temporarily unavailable;
- installs the Void runtime prerequisites required by the upstream daemon,
  including `nftables` for its Linux firewall path;
- extracts only `warp-cli` and `warp-svc` without executing Debian maintainer
  scripts;
- creates/repairs an iNiR-owned runit service only after the user opts in;
- never downgrades a newer local WARP version; and
- refreshes during a later iNiR update only when the installation is already
  owned by the iNiR WARP provider.

WARP account registration and accepting Cloudflare terms remain user-owned
operations. The optional provider's end-to-end VM gate now also covers a real
`connect -> Connected` transition, the `CloudflareWARP` interface/routing
state, `warp=on`, disconnect/`warp=off`, and reconnect. WARP remains an
optional Extra rather than a base-release dependency, and is not offered by
this port on musl or non-x86_64 Void.

`discover-overlay` is not a supported capability: the repository contains no
provider, origin, install path, or documented user requirement for it. PR3.3
removes its GameMode setting and process control instead of inventing a Void
service.

## Package management UI (Updates / PackageSearch / AppCatalog)

- Updates check (no root): `xbps-install -nu` (list available updates).
- Update all: `sudo xbps-install -Su` (terminal, `_runTerminalScript`).
- Search: `xbps-query -Rs "<query>" | head -200`.
- Installed: `xbps-query -s "<query>"`.
- Install: `sudo xbps-install -S -- "<pkg>"`; remove: `sudo xbps-remove -R -- "<pkg>"`.
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
and removes marked blocks per distro and predicate (ADR-0003). The template
keeps the systemd environment command as an unmarked default; setup renders
that command, the marked runsvdir block, or no startup block for turnstile.
It also handles an existing split `config.d/50-startup.kdl` or monolithic
`config.kdl`. Injection must be idempotent, and migration 021 must remove the
runsvdir block when the predicate holds (no double shell on Void+systemd).

## Migration rules

`021-systemd-single-instance` and `022-service-compositor-wants` must be
no-ops when the predicate is false (their `command -v systemctl` check is
not enough — without the user-manager socket, `systemctl --user` hangs for
10-30s).

## Historical delivery queue and branch policy

The implementation was delivered incrementally against
`snowarch/inir:prerelease`. Those feature/fix branches were useful while the
port was being built, but they are no longer active development refs. The
canonical fork branch for the completed Void integration and release candidate
is `prerelease`. The table below records the original 2.31 delivery sequence;
at the 2026-09-20 pre-Darkly/Foot closure checkpoint the
published integration tip is `fd6725f2`, which already contains Snow's complete
`9574fa42` 2.31.0 baseline.

| Order | Historical delivery | Scope | Closure evidence |
|---|---|---|---|
| 1 | PR1 / `feat/void-systemd-predicate` | Usable-systemd predicate, migrations 021/022, and local-distribution guards. | Arch local tests plus predicate validation on Void. |
| 2 | PR2 / `feat/void-dependencies` | Void dependency router, XBPS install script, and package-map corrections. | Fresh-VM dependency install and second-run idempotency. |
| 3 | PR3.0-PR3.3 | Supervisors, lifecycle, session runtime, and optional runtime adapters. | Versioned PR3.2/PR3.3 contracts and live non-systemd session validation. |
| 4 | PR4.0-PR4.3 | NetworkManager, BlueZ, ydotool, and WARP providers/lifecycle. | Provider provisioning, activation, repair, and representative operation checks. |
| 5 | PR5.0-PR5.5 | Mission Center, OCR, visual providers, fonts, Darkly, and desktop/runtime parity. | All PR5 checkers plus live Niri/sidebar/theme/keybind validation. |
| 6 | PR6 / `feat/void-xbps-ui` | XBPS updates, search, install/remove, and app-catalog targets. | UI wiring and a real isolated-root XBPS transaction. |
| 7 | PR7 / `feat/void-port-closure` | Doctor/versioning, final ADR-0002 sweep, capability audit, and release-VM closure. | Doctor 27/27, full checker sweep, clean install/reinstall, reboot, live Power Profiles, Web Wallpaper, and local gates. |

Current fork policy:

- `main` follows `upstream/main` by fast-forward and is not the Void
  integration branch.
- `prerelease` is the only active Void integration/release-candidate branch.
- completed short-lived port branches are removed after integration; a
  divergent historical tip is preserved by an
  `archive/void-preintegration/*` tag before branch deletion.
- `main` and `prerelease` are protected against deletion and force-push.

Documentation and VM observations travel with the canonical integration branch.
The clean Void external-disk installation and its post-migration reboot have
been performed; the final live NetworkManager/runit state, SDDM session path,
physical Bluetooth adapter, Power Profiles state and helper-process counts are
recorded in `docs/VOID_VM_VALIDATION.md`. This closes the 2.31.0 Void hardware
release gate; it is historical evidence, not the current 2.32 Snow baseline.

### External hardware prerequisites

iNiR installs the shell/rice and its userland capability providers. It does not
install or choose kernel GPU drivers, firmware, Mesa/Vulkan drivers, proprietary
GPU stacks, bootloader configuration, or hardware-specific kernel parameters.
Those remain the base Void installation's responsibility.

Before running iNiR on a new machine, the tester should first confirm that the
base Void installation can boot normally and that its graphics stack is usable
for Wayland/Niri on that hardware. This matters especially when the external
disk will be moved between machines with different GPUs. iNiR can provision its
own desktop dependencies afterward, but it should not guess which hardware
driver is correct for an unknown machine.

The default dependency set is large because `nerd-fonts-ttf` alone expands to
several GiB. The Void installer now performs a dynamic XBPS disk-space preflight
for only the packages still missing and includes 2 GiB of download/build
headroom. In the clean release VM, a 20 GiB root filesystem ran out of space
during the initial font transaction; a 30 GiB virtual disk completed the full
install and later idempotent installs passed with about 7 GiB free.

## VM validation

The detailed 2026-08-29, 2026-08-30 and 2026-08-31 VM execution log is in
`docs/VOID_VM_VALIDATION.md`.

Recipe (QEMU, KVM available on the host):

```
qemu-system-x86_64 \
  -accel kvm -m 4096 -smp 4 \
  -display gtk,gl=on \
  -device virtio-vga-gl \
  -drive file=void.img,format=qcow2,if=virtio \
  -netdev user,id=n1 -device virtio-net-pci,netdev=n1
```

- Graphics: the validated VM path uses **VirGL**. The original plain
  `virtio-vga` configuration exposed DRM but negotiated no
  `VIRTIO_GPU_F_VIRGL`; Niri then skipped the software EGL renderer and had no
  usable output. Lavapipe/software rendering is therefore not a supported
  fallback for the Void release VM.
- `scripts/check-void-graphics.sh` catches that specific VirtIO failure before
  the installer starts the large dependency transaction. It also rejects a
  machine with no accessible DRM render node. Set
  `INIR_SKIP_GRAPHICS_PREFLIGHT=1` only when deliberately testing an unusual
  graphics stack outside the validated profile.
- Venus remains an optional VM configuration when the host/QEMU stack supports
  it: `-device virtio-gpu-gl,hostmem=8G,blob=true,venus=true`.
- Verification order in the VM:
  0. Quickshell 0.3.0 (repo) runs iNiR — the make-or-break check.
  1. Installer end-to-end on a fresh Void.
  2. Session: SDDM → packaged Niri entry (`niri --session`) → shell supervised
     by the selected non-systemd user supervisor. Direct TTY launch remains a
     recovery path, not the normal installed flow.
  3. Services: dbus/elogind/polkitd/turnstiled up.
  4. UI: updates list, search/install/remove via xbps.
  5. `test-local-distribution.sh` with predicate-conditional invariants.

PR3 is split into four sequential PRs:
- PR3.0 `feat/void-runsvdir-supervisor`: runit fallback, no turnstile.
  If turnstiled is already enabled, setup leaves supervision to it and does
  not inject a second runsvdir supervisor; full turnstile configuration is
  PR3.1.
- PR3.1 `feat/void-turnstile-session`: turnstile + elogind with confirmed elevation.
  Complete and VM validated.
- PR3.2 `feat/void-nonsystemd-runtime`: non-systemd runtime adapters for UI/services.
  Implementation and VM validation are complete. XEmbed uses a runit user
  service so crashes are restarted by `runsv` instead of `systemd-run`; the
  service is optional when `xembedsniproxy` is not installed.
- PR3.3 `feat/void-optional-systemd-adapters`: predicate-safe Awww, GameMode,
  clipboard, captures, and thumbnails; install the official Void Awww provider;
  remove the undefined `discover-overlay` integration. WARP remains visible
  but its supported provider and runit lifecycle are delivered in PR4.

## FAQ / gotchas

- **Two shells after install**: a hand-written startup entry, or both Niri and
  turnstile owning `~/.config/service`. Remove hand-written
  `spawn-*`/runsvdir lines and rerun setup so it selects one tier.
- **Shell crashes and stays dead**: no supervisor (tier 3 requires the
  runsvdir entry; check `sv status ~/.config/service/inir`).
- **`inir logs` fails**: journalctl is systemd-only; use `sv status` (+
  `svlogd` if you configure a `log` directory for the service).
- **Qt/Quickshell ABI mismatch after a Void Qt update**: transient until
  Void rebuilds quickshell; `inir doctor --fix-abi` gains a Void case
  (`xbps-install -Sf quickshell` or local template rebuild).
- **Suspend/hibernate**: `loginctl suspend` (elogind) replaces
  `systemctl suspend`; `acpid` is the alternative in the seatd profile.
- **SPICE clipboard in a Wayland-only Niri session**: Void's
  `spice-vdagent` requires an X11 `DISPLAY`. The SPICE channel and daemon can
  be healthy while clipboard integration remains unavailable. This does not
  affect iNiR or turnstile.

## PR3.2 VM checkpoint

Keep `scripts/check-void-pr32.sh` as the repeatable, versioned validation
contract. SSH is only the transport; export the graphical user's runtime and
D-Bus address explicitly:

```bash
VM_IP="$(virsh -c qemu:///system domifaddr voidlinux-release-clean --source lease \
  | awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}')"
ssh "voidcaml@$VM_IP" '
cd ~/inir-src &&
git fetch origin &&
git checkout feat/void-nonsystemd-runtime &&
git pull --ff-only &&
export XDG_RUNTIME_DIR=/run/user/$(id -u) &&
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus &&
INIR_EXPECTED_COMMIT="$(git rev-parse origin/feat/void-nonsystemd-runtime)" \
  ./scripts/check-void-pr32.sh
'
```

The checker requires the false usable-systemd-user-manager predicate, a real
session bus, `sv` supervision of iNiR, supported `loginctl` power verbs, and a
clean expected branch. XEmbed is optional and is checked only when its binary
is installed.

## Sources

- Void handbook: services (`/etc/sv` → `/var/service/`), session management
  (elogind/seatd/turnstile), user services (turnstile),
  `xbps-install`/`xbps-query` usage.
- QEMU docs: virtio-gpu device (venus/gfxstream options), display backends.
- Repo facts: `scripts/inir` (service helpers, `run --session`),
  `sdata/lib/deps-map.sh`, `sdata/subcmd-install/3.files.sh`,
  migrations 021/022, `Makefile`, `scripts/test-local-distribution.sh`.
