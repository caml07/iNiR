# iNiR on Void Linux

The context of the Void Linux port of iNiR: runit as init, XBPS as package
manager, no systemd by default. This is the glossary for the port — decisions
live in `docs/adr/`, the user-facing guide in `docs/VOID.md`.

## Language

**Usable systemd user manager**:
The state where systemd can manage per-user services: the socket
`$XDG_RUNTIME_DIR/systemd/private` exists and a bounded probe of
`systemctl --user` answers. Not the same as "systemctl installed".
_Avoid_: has systemd, systemd distro

**Session supervisor**:
The mechanism that restarts the shell after a crash. Three tiers: the
`inir.service` user unit when the usable systemd user manager predicate holds;
a turnstile-managed user service (`~/.config/service/inir/run`) when the
`turnstiled` service is running; a `runsvdir` launched by Niri otherwise.
_Avoid_: process manager, service manager

**Turnstile user service**:
A per-user service in `~/.config/service/` supervised by the `turnstiled`
daemon, runit-compatible, controlled with `sv`. Turnstile can also provide the
session D-Bus bus as a core service and exports service env via
`turnstile-update-runit-env` / `chpst -e "$TURNSTILE_ENV_DIR"`.
_Avoid_: system runit service

**Startup entry**:
A `spawn-*` line in `50-startup.kdl` (or the monolithic `config.kdl`)
managed by setup — injected or removed per distro and supervisor. Adding one
by hand causes two shells.
_Avoid_: autostart line, spawn line

**Package-managed install**:
An install owned by the distro package manager (XBPS on Void): iNiR updates
with `xbps-install -Su`, not `inir update` or git. Recorded in `version.json`
(`install_mode`, `package_manager`).
_Avoid_: manual install, repo-linked install

**Compatibility profile**:
A documented, explicitly out-of-scope-for-V1 configuration: `musl` libc,
or `seatd` + `turnstile` without elogind (acpid for power management).
_Avoid_: supported configuration

**Non-systemd session**:
A login session started through `niri --session` on runit Void: no systemd
user manager, session D-Bus provided by `dbus-run-session` or by turnstile,
env propagated to services via `dbus-update-activation-environment` or
turnstile envdir.
