# AGENTS.md — iNiR Void Linux port

Agent-facing state for the Void Linux port of iNiR. Spec: `docs/VOID.md`.
Decisions: `docs/adr/`. Glossary: `CONTEXT.md`. This work is **in progress**
on branch `feat/void-turnstile-session` (base: upstream `prerelease`). PR3 is
split into sequential PRs.

## Current progress (2026-09-01)

- PR1 `feat/void-systemd-predicate`: validated locally and in the Void VM.
- PR2 `feat/void-dependencies`: committed as `3444ccbd` and pushed to
  `origin/feat/void-dependencies`. **Fixed**: added `rsync`, `base-devel`,
  `pkg-config`, `cairo-devel`, `python3-devel`, `glib-devel`,
  `gobject-introspection`, `python3-gobject-devel`, `libffi-devel` to base
  packages; added `ONLY_MISSING_DEPS` handling for update path.
- The canonical VM checkout is `/home/voidcaml/inir-src`. PR3.0 was installed
  and exercised successfully in the Void VM on 2026-08-31.
- Host validation passed: 5 suites and 27 tests, with 0 failures. `bash -n`
  and `git diff --check` also passed.
- VM validation passed all five dependency groups twice. The sorted
  `xbps-query -l` snapshots produced an empty second-run diff.
- Validated Void package names include `python3-Pillow`, `geoclue2`,
  `tesseract-ocr*`, and `ImageMagick`. `adw-gtk3`, `capitaine-cursors`, and
  `whitesur-icon-theme` are not in the current Void repositories and were
  excluded from the XBPS group.
- PR3 is split into four sequential branches/PRs:
  - PR3.0 `feat/void-runsvdir-supervisor`: per-user runit fallback (no turnstile);
    **implementation and VM validation complete**, local tests pass.
  - PR3.1 `feat/void-turnstile-session`: turnstile + elogind profile with confirmed elevation;
    **implementation and VM validation complete**.
  - PR3.2 `feat/void-nonsystemd-runtime`: non-systemd runtime adapters for UI/services.
  - PR3.3 `feat/void-optional-systemd-adapters`: Awww, GameMode, Warp, captures — degrade or adapt.

The detailed commands and observations are in `docs/VOID_VM_VALIDATION.md`.

### Latest VM checkpoint

- Install completed at version `2.29.3`; all critical QML/config files verified.
- `fish-shell` had to be installed explicitly because Void names the package
  `fish-shell`, not `fish`. The dependency profile now installs it and maps the
  `fish` command to that package.
- PR3.1 enabled `dbus`, `elogind`, `polkitd`, and `turnstiled` with confirmed
  elevation; `manage_rundir = no` is set for elogind.
- `~/.config/service/{dbus,inir,turnstile-ready}` are supervised by turnstile.
  `inir/run` uses `chpst -e "$TURNSTILE_ENV_DIR"`; the Niri fallback KDL block
  was removed. A turnstile backend `runsvdir` is expected and is not the Niri
  fallback.
- Kitty under Niri has `WAYLAND_DISPLAY=wayland-1`,
  `XDG_SESSION_TYPE=wayland`, and a session D-Bus address.
- SPICE clipboard is not supported in this Wayland-only VM session because
  Void's `spice-vdagent` requires an X11 `DISPLAY`; it does not block the port.

## Where things are

- Work repo: `~/Projects/inir` (clone of the fork `caml07/iNiR`; `origin` =
  fork, `upstream` = `snowarch/inir`). PRs for this project target
  `snowarch/inir` `prerelease` (CONTRIBUTING.md).
- The original clone stays at `/home/caml/inir` (upstream `main` clone,
  untouched; `inir-fix` worktree there holds the open PR #222 branch
  `fix/window-identity-rules` — do not touch).
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
(→ `loginctl`), `apply-gtk-theme.sh:994`, `niri-config.py:1376,1441`,
`scripts/test-local-distribution.sh:26-32,202-211`.

## Files to change (port)

- `sdata/lib/deps-map.sh` — Void fixes: `void:quickshell` (repo, not
  COMPILE), `void:uv` (repo, not CARGO), `qt6-qt5compat` (not `qt6-5compat`),
  no kirigami/syntax-highlighting in base.
- `sdata/subcmd-install/1.deps-router.sh` — route `void` to
  `dist-void/install-deps.sh` (new), not the generic path.
- `defaults/niri/config.d/50-startup.kdl` — marked blocks (ADR-0003);
  `3.files.sh` injects per distro/predicate (idempotent).
- `sdata/migrations/021-systemd-single-instance.sh` — predicate guard;
  must also remove a runsvdir entry when the predicate holds.
- `sdata/migrations/022-service-compositor-wants.sh` — predicate guard.
- `services/Updates.qml` — `xbps-install -nu` check, `-Su` update.
- `services/deferred/PackageSearch.qml` — `xbps-query -Rs/-s`,
  `sudo xbps-install -S/--`, `sudo xbps-remove -Rns`.
- `services/AppCatalog.qml` + `defaults/app-catalog.json` — `xbps` targets.
- `sdata/lib/functions.sh` — supervisor selection and turnstile user-service
  rendering; detects active turnstile without requiring user access to its
  system-service status.
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
- `sdata/lib/versioning.sh` — `package_manager: xbps` support for the
  future XBPS template.

## Verify (run before finishing any port task)

- `make test-local` / `scripts/test-local-distribution.sh` — must pass on
  Arch (systemd) paths; Void branches only exercised in the VM.
- Shellcheck on any touched `.sh` (repo uses bash 4+).
- Idempotency: run the touched installer step twice, diff the second run.
- No `spawn-*` inir entry added by hand anywhere; no `make install` in any
  XBPS template (it installs the systemd unit, `Makefile:54`).

## Do not

- Touch `/home/caml/inir` or `inir-fix` (PR #222 work).
- Commit without being asked. Never commit the untracked
  `05-caelestia-terminal.sh`.
- Gate anything on `command -v systemctl` alone.
- Rename Void packages to Arch names or vice versa (e.g. `qt6-qt5compat`).
