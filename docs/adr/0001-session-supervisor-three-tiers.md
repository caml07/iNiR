# ADR-0001: Session supervisor in non-systemd = three tiers, not a respawn loop

On distros without a usable systemd user manager (default Void/runit), iNiR
loses the `Restart=on-failure` supervision of `inir.service`. We chose a
three-tier session supervisor instead of (a) a respawn loop in
`spawn-sh-at-startup` — rejected because `inir run --session` does `exec qs`,
so `inir kill` (SIGTERM, exit 143) respawns a deliberately killed shell and
`inir restart` races the loop into two shells (`run --session` skips instance
detection) — and (b) no supervision — rejected because a crash would leave
the shell dead until Niri restarts.

Tiers, in order of preference, decided by the usable-systemd-user-manager
predicate (ADR-0002), never by distro name:

1. **systemd user unit** (`inir.service`) — when the predicate holds (this
   includes Void installations that run systemd).
2. **turnstile user service** (`~/.config/service/inir/run` with
   `exec <launcher> run --session`) — when the `turnstiled` service is
   running. Turnstile is the Void-blessed path: it also manages the session
   D-Bus bus (`core_services="dbus"` in `~/.config/service/turnstile-ready/conf`),
   removing the `dbus-run-session` dependency in that path, and exports env
   via `turnstile-update-runit-env` / `chpst -e "$TURNSTILE_ENV_DIR"`
   (Void handbook, `config/services/user-services.md`). With elogind,
   `manage_rundir=no` in `/etc/turnstile/turnstiled.conf`.
3. **runsvdir spawned by Niri** (`spawn-sh-at-startup "exec runsvdir ~/.config/service"`)
   — zero-dependency fallback. Niri kills its spawns on exit, giving session
   lifetime for free; the session env (WAYLAND_DISPLAY, NIRI_SOCKET,
   XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS) is inherited from Niri.

Tiers 2 and 3 share the same `~/.config/service/inir/run` file, so installs
work under both supervisors. `sv` control (`sv restart/down/up`) is the
non-systemd equivalent of `systemctl --user` and is wired into the same
guards (`scripts/inir`, `MemoryPressureService.qml`, `apply-gtk-theme.sh`).

Status: proposed