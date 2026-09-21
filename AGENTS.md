# AGENTS.md — iNiR Void Linux port

Agent-facing state for the Void Linux port of iNiR. Spec: `docs/VOID.md`.
Decisions: `docs/adr/`. Glossary: `CONTEXT.md`. Operational procedure:
`docs/VOID_PORT_RUNBOOK.md`.

The canonical Void integration/release-candidate branch on the fork is
`prerelease`. At the 2026-09-20 checkpoint the fork contains Snow through
`9574fa42` (iNiR 2.31.0); a fresh fetch found Snow `main` and `prerelease` at
that same commit, so there is no upstream delta waiting to be ported. PR1
through PR7 engineering closure, the clean release-VM gate, and the real
external-disk hardware gate are complete. The final post-migration boot proved
NetworkManager live under runit, so no release-blocking Void hardware evidence
remains for the 2.31.0 port.

## Current progress (2026-09-20)

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
- The first real external-disk run found two VM-hidden gaps: Void's stock
  `dhcpcd`/`wpa_supplicant` services prevented the installed NetworkManager
  provider from activating, and runit-reparented `swayidle`/keyboard helpers
  accumulated across shell restarts. The Turnstile xembed service also rendered
  `$TURNSTILE_ENV_DIR` literally and crash-looped. The external-disk closure
  branch adds a rollback-safe NetworkManager handoff, Doctor runtime coverage,
  distro detection for `setup doctor`, runit-aware helper cleanup, and correct
  xembed environment rendering. Hardware
  restart testing converged to one shell/idle/keyboard helper. A later real
  reboot closed the final gate: `nmcli` reported `connected`, the Wi-Fi device
  was owned by NetworkManager, `runsv NetworkManager` directly parented the
  daemon, the persistent service links pointed to `/etc/sv/NetworkManager`, and
  `dhcpcd`/standalone `wpa_supplicant`/`wicd` were disabled.
- A later real-Void report exposed two post-closure theming/provider gaps. The
  Darkly provider installed the Qt style but had disabled KDecoration, so
  `darkly-settings6` could not load `kcm_darklydecoration.so`. The release VM
  reproduced the partial state, then passed a real rebuild/install with
  `kf6-kdecoration-devel`, `WITH_DECORATIONS=ON`, KCM linkage, settings smoke,
  provider idempotency and the full local suite. The same report exposed a
  stale Foot `colors.ini` include; the canonical generated path is now
  `~/.config/foot/inir-colors.ini` across shipped config, generation, installer
  repair and uninstall cleanup.

The detailed commands and observations are in `docs/VOID_VM_VALIDATION.md`.
Repo-local procedures are also available under `.agents/skills/`:
`inir-void-port`, `inir-void-provider`, `inir-void-validation`, and
`inir-void-debugging`. Release/upstream closure work also has a dedicated
`inir-void-release` skill.

## Standard maintenance loop

This is the workflow that proved reliable while finishing the Void port. Reuse
it for future Snow syncs, Void regressions, provider repairs, and release
candidate updates instead of rebuilding the process ad hoc.

1. **Refresh facts before editing.** Fetch both `origin` and `upstream`, inspect
   `origin/prerelease`, `upstream/main`, and `upstream/prerelease`, then record
   the exact delta. Never assume an older feature branch reflects current
   integration state.
2. **Protect the user's live checkout.** If the physical Void checkout or any
   other working tree is dirty, leave it untouched. Create a clean temporary
   clone/worktree from the fork's `prerelease` for implementation, docs, and
   publishing. Do not reset/stash/rebase user-owned changes just to make an
   audit convenient.
3. **Branch from the current fork integration tip.** Use a small `fix/*`,
   `feat/*`, or `docs/*` branch based on `origin/prerelease`. `main` remains the
   upstream baseline; Void work lands through `prerelease`.
4. **Reproduce first, then TDD.** For a bug, capture the actual failing state
   (VM or physical Void), add the narrowest regression/checker contract, prove
   RED, implement the minimum GREEN fix, and keep feature + regression test in
   the same code commit when practical.
5. **Validate the provider, not just the binary.** Verify provisioning,
   activation, runtime ownership, the real iNiR action/UI path, and a second-run
   idempotency snapshot. A package/plugin existing on disk is not sufficient.
6. **Use the release VM for Void-specific behavior.** The canonical VM is
   `voidlinux-release-clean`; discover its current address dynamically rather
   than hard-coding DHCP state. Pull the latest fork `prerelease` before
   overlaying/testing a candidate.
7. **Treat SSH/automation as non-graphical unless proven otherwise.** Missing
   `NIRI_SOCKET`/`WAYLAND_DISPLAY` in an automation shell does not prove the
   graphical session is broken. Inspect the real Niri/Quickshell process
   environment and session ownership before filing a runtime failure.
8. **Reboot for lifecycle claims.** For service/session fixes, require a real
   reboot when persistence is part of the contract. Recheck SDDM ->
   `niri --session`, supervisor ownership, one Quickshell, helper counts,
   NetworkManager/BlueZ/Power Profiles signals, and relevant IPC/action paths.
9. **Use physical hardware only for the final gaps.** VM validation comes
   first. The external-disk Void install is for hardware/network/session facts
   the VM cannot prove. Record exactly what was exercised; do not convert a
   mechanical check into a visual/hardware claim.
10. **Update docs with the code.** At minimum review `AGENTS.md`, `docs/VOID.md`,
    `docs/VOID_CAPABILITIES.md`, `docs/VOID_PORT_RUNBOOK.md`, and
    `docs/VOID_VM_VALIDATION.md`. If public install/runtime behavior changed,
    also review README/INSTALL/SETUP/PACKAGES/RUNTIME/AUTOSTART and localized
    distro-support notes.
11. **Compare doc-verifier failures to a clean baseline.** The repository has
    known non-Void verifier findings. A non-zero `scripts/verify-docs.sh` is not
    automatically a regression; compare the exact findings with a detached
    clean `origin/prerelease` worktree before making that claim.
12. **Run final gates.** `bash -n` for touched shell files, Python compile when
    relevant, `git diff --check`, `make test-local`, the versioned Void checker,
    and idempotency mode where supported. Run ShellCheck when installed and say
    when it is unavailable.
13. **Review and secret-scan before commit.** Inspect the final diff, verify no
    unrelated files are staged, and run the staged secret scan when available.
14. **Keep history readable.** Prefer a code/test commit and a separate docs
    commit for large closure sweeps. Use concise commit messages such as
    `fix(void): ...` and `docs(void): ...`.
15. **Publish through a PR to `prerelease`.** Push the short-lived branch, open
    a PR against the fork's `prerelease`, summarize exact validation evidence,
    merge explicitly after the gates pass, and let GitHub delete the merged
    branch. Do not merge Void work directly into `main`.

### Repeated gotchas worth remembering

- Void root-owned runit services can be healthy even when an unprivileged
  `sv status /var/service/<name>` reports `access denied`. Cross-check the
  service link, `runsv` parent, daemon process, D-Bus/socket signal, and the
  feature's operational CLI.
- Turnstile/runit is a **session startup/restart lifecycle**, not a per-keybind
  hot path. Keybind latency debugging should still split Niri -> spawn ->
  launcher/IPC -> QML/action.
- NetworkManager migration must not silently destroy a working Void network.
  Keep the confirmation + rollback contract and defer it until the rest of the
  install is complete.
- SDDM enablement is also confirmation-gated and late in setup. A manual
  `niri --session` launch is a recovery/debug path, not the normal installed
  login flow.
- Count the actual supervised shell process (`qs -n -p .../quickshell/inir`),
  not every short-lived `qs` IPC client. For helper-leak regressions, count
  `swayidle` and `keyboard_lock_state_daemon.py` separately.
- Darkly completeness requires both the Qt style and the KDecoration settings
  KCM. `darkly6.so` alone can make the provider look healthy while
  `darkly-settings6` still fails.
- Foot theming uses one canonical managed file:
  `~/.config/foot/inir-colors.ini`. `colors.ini` is legacy cleanup/migration
  input only.
- Large XBPS/font transactions need free-space headroom. Preserve the dynamic
  preflight instead of assuming a minimal 20 GiB root is enough.

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

- Canonical repository: fork `caml07/iNiR`; `origin` is the fork and
  `upstream` is `snowarch/inir` in normal development checkouts.
- Do not rely on a hard-coded local checkout path. The physical Void install
  has had a dirty `~/iNiR` checkout during validation, while clean release work
  has intentionally used disposable clones/worktrees. Always inspect the path,
  branch, and status you were actually given before editing.
- The separate upstream/PR worktrees used for unrelated Snow work remain out of
  scope unless the user explicitly brings them into the task.
- If `scripts/colors/modules/05-caelestia-terminal.sh` exists as an untracked
  user file, never stage, rewrite, or commit it.

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

- Touch unrelated upstream/PR worktrees or a dirty physical-validation checkout
  merely to obtain a clean tree. Use a disposable clean clone/worktree instead.
- Commit without being asked. Never commit the untracked
  `05-caelestia-terminal.sh`.
- Stage or modify the current user-owned dirty files
  `scripts/generate-settings-search-index.py` and
  `scripts/test-detect-sensors.py` unless the user explicitly asks for them.
- Gate anything on `command -v systemctl` alone.
- Rename Void packages to Arch names or vice versa (e.g. `qt6-qt5compat`).
