# AGENTS.md — iNiR Void Linux port

Agent-facing state for the Void Linux port of iNiR. Spec: `docs/VOID.md`.
Decisions: `docs/adr/`. Glossary: `CONTEXT.md`. Operational procedure:
`docs/VOID_PORT_RUNBOOK.md`.

The canonical Void integration/release-candidate branch on the fork is
`prerelease`. At the 2026-09-19 branch-formalization checkpoint it is
`5c13b6c4fa1b3c0459a38117e91d05e140943b0a` and contains Snow through
`9574fa42` (iNiR 2.31.0). PR1 through PR7 engineering closure and the clean
release-VM gate are complete. The remaining release evidence is the planned
external-disk/hardware test.

## Current progress (2026-09-19)

- PR1-PR3: usable-systemd predicate, XBPS dependency routing, runsvdir/
  turnstile supervision, non-systemd runtime adapters, PipeWire user services,
  and Niri startup are complete. The 2026-09-18 sweep also fixed remaining
  predicate-sensitive runtime gaps and Night Light/Doctor coverage.
- PR4.0-PR4.3: NetworkManager, BlueZ, ydotool, and WARP providers/lifecycle
  are complete. WARP registration and a real tunnel are intentionally not part
  of the port gate because they require user account/TOS state.
- PR5.0-PR5.5: Mission Center, OCR, visual providers, required fonts, Darkly,
  KDE/Qt integration, QML runtime dependencies, Void identity, and session
  closure are complete. All PR5 checkers passed in the VM with their
  idempotency modes enabled.
- PR6: XBPS update counting, package search/installed search, install/remove
  terminal actions, and app-catalog targets are implemented and VM validated.
  The checker also caught and corrected an invalid draft command:
  XBPS removal uses `xbps-remove -R -- <pkg>`, not pacman-style `-Rns`.
- PR7 closure sweep: removed remaining Arch-only package actions/defaults,
  added XBPS paths to required migrations/uninstall flows, made OCR independent
  across toolkit/screencapture, closed base QML runtime gaps (Kirigami,
  kdialog, breeze-icons, qt6ct), completed audio/profile parity, and added the
  official Power Profiles provider with runit/D-Bus/polkit verification.
- Fat-check fixes integrated into `prerelease` include systemd-predicate
  cleanup, required desktop tools, git-worktree detection, Niri/Turnstile
  socket lifecycle, WARP runit logging, a real Void distro icon, supported
  Void installer messaging, dunst client-package handling, and a self-contained
  OCR checker.
- The clean 2.31 VM also passed a normal install/reinstall, reboot, live
  Power Profiles activation, Doctor 27/27, Web Wallpaper, both sidebars,
  end-to-end Super+Q through ydotool/uinput, and `inir logs --issues` under
  runit.
- `make test-local`, the PR7 static/full VM checker, real-Wayland QML smoke,
  package-action terminal capture, `bash -n`, and `git diff --check` pass
  after the closure sweep. ShellCheck is not installed on the host.
- Final graphical-login parity is closed with a Void SDDM provider:
  `sddm` + `xorg-minimal` are base dependencies and setup offers the runit
  service only after installation completes. The release VM passed persistent
  SDDM greeter boot plus an SDDM-launched Niri/Quickshell session with Doctor
  27/27. Manual `niri --session` is the recovery path rather than the intended
  normal boot flow.

The detailed commands and observations are in `docs/VOID_VM_VALIDATION.md`.
Repo-local procedures are also available under `.agents/skills/`:
`inir-void-port`, `inir-void-provider`, `inir-void-validation`, and
`inir-void-debugging`.

### Latest VM checkpoint

- Release-validation VM: `voidlinux-release-clean`, user `voidcaml`;
  canonical checkout `/home/voidcaml/inir-release-test`. Its DHCP address is
  intentionally not treated as stable state. The root filesystem is 30 GiB.
- The 2026-09-19 release VM completed real reboots. The resulting local session
  now normally starts at the SDDM `ii-pixel` greeter. A temporary validation
  autologin proved SDDM launches the packaged `niri.desktop` entry
  (`/usr/bin/niri --session`) into a seat0 Wayland user session with a single
  supervised Quickshell shell; the temporary autologin was then removed and a
  final boot returned to the normal greeter.
- The usable-systemd-user-manager predicate remained false. Turnstile's user
  runsvdir supervised iNiR, PipeWire, WirePlumber, PipeWire Pulse, and ydotool.
- Quickshell inherited the new Niri socket after boot. Niri config validation,
  both sidebars, end-to-end `Mod+Q` via ydotool/uinput, audio, ydotool, font
  aliases, Darkly, KDE platform integration, Void icon mapping, and the
  Quickshell severe-error log scan all passed.
- NetworkManager reported `connected`, BlueZ owned `org.bluez`, and WARP's
  socket plus `vlogger` runit logger were present after boot.
- `power-profiles-daemon` stayed active across reboot,
  `powerprofilesctl list` returned profiles, and
  `org.freedesktop.UPower.PowerProfiles` owned its system D-Bus name.
- The VM exposes no Bluetooth hardware. WARP account registration/tunnel,
  visual confirmation of the rendered Void icon, and SPICE clipboard under the
  Wayland-only session are not claimed as validated gates.

### Fork branch policy

- `main` is the fork's upstream baseline and is updated from
  `upstream/main` by fast-forward only.
- `prerelease` is the canonical Void integration/release-candidate branch.
- Short-lived `feat/*`, `fix/*`, and `docs/*` branches are deleted from the
  fork after integration. A genuinely divergent historical tip is tagged under
  `archive/void-preintegration/*` before its branch is removed.
- On 2026-09-19 the fork was reduced from 41 remote heads to `main`,
  `prerelease`, and the unrelated `fix/window-identity-rules` branch. The
  latter is preserved because its separate checkout is outside this port task.
- `main` and `prerelease` are protected against deletion and force-push.
  GitHub is configured to delete merged branches automatically.

## Where things are

- Work repo: `~/Projects/inir` (clone of the fork `caml07/iNiR`; `origin` =
  fork, `upstream` = `snowarch/inir`). PRs for this project target
  `snowarch/inir` `prerelease` (CONTRIBUTING.md).
- The original clone stays at `/home/caml/inir` (upstream `main` clone,
  untouched). Its `inir-fix` worktree holds the now-merged PR #222 branch
  `fix/window-identity-rules`; it remains outside this port task — do not
  touch it.
- Untracked user file that must never be touched or committed:
  `scripts/colors/modules/05-caelestia-terminal.sh`.

## The port's load-bearing rule

**Predicate, not distro.** Every systemd-sensitive path is gated by
"usable systemd user manager" = `-S $XDG_RUNTIME_DIR/systemd/private` AND
`timeout 3s systemctl --user show-environment` answers (ADR-0002). Never
gate on `command -v systemctl` or on distro name. Applies to:
installer (unit vs runit service), migrations 021/022, `scripts/inir`
restart/kill/stop/status/logs, `MemoryPressureService.qml` (→ `sv restart`),
`TrayService.qml` (skip `systemd-run`), `Session.qml`/`Idle.qml`
(→ `loginctl`), `apply-gtk-theme.sh:1110`, `niri-config.py:1727,1738`,
`scripts/test-local-distribution.sh`.

## Capability rule

**Provider, not hopeful detection.** A capability selected in the Void
installer is supported only when provider, provisioning, activation, operation,
and verification are complete (ADR-0004). Prefer XBPS, then Flatpak, then a
pinned upstream provider. Do not leave a control enabled merely because a
binary might exist. `discover-overlay` is removed because no provider or user
requirement can be identified.

## Files to change (port)

- `sdata/lib/deps-map.sh` / `sdata/dist-void/install-deps.sh` — keep Void
  package names literal. `quickshell` and `uv` are repo packages,
  `qt6-qt5compat` is the correct Qt compat package, and
  `kf6-syntax-highlighting` is a required base runtime dependency for the
  sidebars.
- `sdata/subcmd-install/1.deps-router.sh` — route `void` to
  `dist-void/install-deps.sh` (new), not the generic path.
- `defaults/niri/config.d/50-startup.kdl` — marked blocks (ADR-0003);
  `3.files.sh` injects per distro/predicate (idempotent).
- `sdata/migrations/021-systemd-single-instance.sh` — predicate guard;
  must also remove a runsvdir entry when the predicate holds.
- `sdata/migrations/022-service-compositor-wants.sh` — predicate guard.
- `services/Updates.qml` — `xbps-install -nu` check, `-Su` update.
- `services/deferred/PackageSearch.qml` — `xbps-query -Rs/-s`,
  `sudo xbps-install -S/--`, `sudo xbps-remove -R`.
- `services/AppCatalog.qml` + `defaults/app-catalog.json` — `xbps` targets.
- `sdata/lib/functions.sh` — supervisor selection and turnstile user-service
  rendering; detects active turnstile without requiring user access to its
  system-service status. Also owns `reconcile_audio_user_services`
  (`pipewire`, `wireplumber`, `pipewire-pulse` user services for
  non-systemd supervisors).
- `sdata/subcmd-install/2.setups.sh` — PR3.1 confirmed enabling of
  `dbus`, `elogind`, `polkitd`, and `turnstiled`, plus `manage_rundir = no`.
- `sdata/subcmd-install/3.files.sh` — delegates supervisor rendering to the
  shared reconciler.
- `scripts/inir` — `sv` branches in restart/kill/stop/status/logs when the
  predicate is false.
- `sdata/lib/doctor.sh` — `xbps-query -L` repo check; no-session-bus
  warning; `--fix-abi` Void case.
- `scripts/test-local-distribution.sh` — systemd invariants conditional on
  the predicate.
- `scripts/check-void-pr33.sh` — repeatable live-VM contract for PR3.3
  (providers, predicate, `discover-overlay` removal, WARP guard, audio
  user services, `pactl`).
- `sdata/lib/versioning.sh` — `package_manager: xbps` support for the
  future XBPS template.
- `docs/VOID_CAPABILITIES.md` — delivery ledger for all user-selectable Void
  capabilities; no row may be marked supported without a repeatable check.

## Verify (run before finishing any port task)

- `make test-local` / `scripts/test-local-distribution.sh` — must pass on
  Arch (systemd) paths; Void branches only exercised in the VM.
- Shellcheck on any touched `.sh` (repo uses bash 4+).
- Idempotency: run the touched installer step twice, diff the second run.
- Checks that can run over SSH are valid when `XDG_RUNTIME_DIR` and
  `DBUS_SESSION_BUS_ADDRESS` point to the active graphical user's session.
- No `spawn-*` inir entry added by hand anywhere; no `make install` in any
  XBPS template (it installs the systemd unit, `Makefile:54`).

## Do not

- Touch `/home/caml/inir` or `inir-fix` (PR #222 work).
- Commit without being asked. Never commit the untracked
  `05-caelestia-terminal.sh`.
- Stage or modify the current user-owned dirty files
  `scripts/generate-settings-search-index.py` and
  `scripts/test-detect-sensors.py` unless the user explicitly asks for them.
- Gate anything on `command -v systemctl` alone.
- Rename Void packages to Arch names or vice versa (e.g. `qt6-qt5compat`).
