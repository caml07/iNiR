---
name: inir-void-debugging
description: Diagnose runtime regressions in the iNiR Void Linux port. Use when Niri/Quickshell keybinds, IPC, sidebars, user services, session environment, QML modules, audio, ydotool, or runit-backed providers work intermittently or fail after restart/reboot.
---

# iNiR Void runtime debugging

Use this skill for live-session failures. Prefer evidence from the active Void
session over assumptions from package presence or a clean config file.

## Read first

Read:

- `AGENTS.md`
- `docs/VOID_PORT_RUNBOOK.md`
- `docs/VOID_VM_VALIDATION.md`
- ADR-0001, ADR-0002, and ADR-0003 when the failure touches startup,
  supervision, or systemd-sensitive behavior

Use the generic `diagnosing-bugs` skill for the RED/reproduction loop.

## First split: config, transport, or action

For a broken keybind/IPC action, separate these layers:

1. the physical/input event reaches Niri;
2. Niri resolves the expected bind;
3. `spawn` executes;
4. the `inir` launcher reaches Quickshell IPC;
5. the QML target executes;
6. any nested `niri msg`, D-Bus, socket, or service action succeeds.

Do not jump from "the key does nothing" to editing the KDL.

A useful pattern is to compare:

- the normal iNiR action;
- a temporary native Niri action;
- a temporary generic `spawn sh -c ...` action;
- direct QML IPC.

Use ydotool/uinput when possible so the test crosses the real compositor bind
path instead of calling the final script directly.

## Session environment

On the primary Void profile, the shell is supervised by turnstile/runit and
must inherit the live Niri session environment.

Inspect the actual Quickshell process:

```bash
qpid=$(pgrep -u "$USER" -af '/usr/bin/qs -n -p .*/quickshell/inir' |
  awk 'NR==1{print $1}')
tr '\0' '\n' < "/proc/$qpid/environ" |
  grep -E '^(PATH|WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|NIRI_SOCKET|INIR_VENV)='
```

Compare `NIRI_SOCKET` to the current socket under `/run/user/$UID`.

A stale Quickshell `NIRI_SOCKET` can make an IPC call return success while a
nested `niri msg` fails. The startup handoff must publish the new environment
with `turnstile-update-runit-env` and restart only the iNiR user service so
the shell inherits it.

## SSH is not the graphical session

An SSH shell commonly lacks `WAYLAND_DISPLAY` and may make `qs` report:

```text
No running instances ... on the current display "unk"
```

That does not prove Quickshell is down. Confirm the process and use the active
display/runtime explicitly when invoking IPC:

```bash
export WAYLAND_DISPLAY=wayland-1
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
qs -p "$HOME/.config/quickshell/inir" ipc call <target> <function>
```

Use the live process environment instead of hard-coding `wayland-1` when
testing a machine where the display number is not already known.

## Supervisor checks

For user services:

```bash
sv status ~/.config/service/inir
sv status ~/.config/service/pipewire
sv status ~/.config/service/wireplumber
sv status ~/.config/service/pipewire-pulse
sv status ~/.config/service/ydotool
```

For root-owned runit services, verify the `/var/service/<name>` symlink,
`runsv` process, daemon process, and the provider's operational signal. Do not
treat inability to run a privileged `sv status` over SSH as proof the daemon
is down.

## QML/runtime failures

When panels or sidebars vanish:

1. inspect the current Quickshell log;
2. search for missing QML modules, component load failures, TypeError/
   ReferenceError, and stale socket errors;
3. verify the required package is in the selected Void dependency profile;
4. reproduce after a shell restart;
5. add a local-distribution regression guard if the dependency is mandatory.

The sidebars require `kf6-syntax-highlighting`; binary detection alone is not
enough when a QML import is load-bearing.

## Keybind regression gate

For a close-window regression:

1. validate Niri config;
2. focus a disposable Foot window;
3. inject Super+Q via ydotool/uinput;
4. require the window to disappear;
5. if it fails, compare native `close-window`, generic spawn, and
   `inir close-window` separately.

Keep `Mod+Q` non-inhibitable unless the product behavior intentionally
changes.

## Logging regressions

Root-owned daemons must not spray stdout/stderr onto tty1. A managed runit
service that logs continuously should own a runit log subservice. WARP uses
`vlogger -t warp-svc -p daemon`.

After changing logging, verify both daemon liveness and logger liveness. A
quiet tty is not enough if the service died.

## Claims

Distinguish:

- **validated**: behavior was exercised in the live session;
- **mechanical check**: config/files/process state matched;
- **not verified**: hardware, credentials, or visual observation were absent.

Do not call an icon visually correct because its asset/mapping exists, and do
not call Bluetooth hardware operation validated in the current VM.
