# ADR-0002: The "usable systemd user manager" predicate governs the port

Void can run systemd; an Arch box can (rarely) lack a working user manager.
Every systemd-sensitive path in iNiR is therefore gated by a predicate, not
by `command -v systemctl` and not by the distro name.

The predicate: the socket `$XDG_RUNTIME_DIR/systemd/private` exists AND a
bounded probe of `systemctl --user` answers (e.g. `timeout 3s systemctl --user
show-environment`, the pattern already used at `scripts/inir:1579`). Without
the socket, `systemctl --user` can block for 10-30s — the probe bounds it.

Paths it gates:

- install: `inir.service` unit vs `~/.config/service/inir/run` (ADR-0001)
- migrations `021-systemd-single-instance` and `022-service-compositor-wants`:
  on Void they must be no-ops — and 021 must also remove a runsvdir startup
  entry when the predicate DOES hold, or a Void+systemd user gets two shells
- `scripts/inir`: restart/kill/stop/status/logs → `sv` variants
- `MemoryPressureService.qml` (`systemctl restart` → `sv restart`),
  `TrayService.qml` (`systemd-run` → skip on non-systemd),
  `Session.qml` / `Idle.qml` (→ `loginctl` via elogind),
  `apply-gtk-theme.sh:994`, `niri-config.py:1376,1441`
- `scripts/test-local-distribution.sh:26-32,202-211` invariants, made
  conditional on the predicate instead of the distro

Status: proposed