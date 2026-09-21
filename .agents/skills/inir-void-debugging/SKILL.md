---
name: inir-void-debugging
description: Diagnose runtime regressions in the iNiR Void Linux port. Use when Niri/Quickshell keybinds, IPC, sidebars, user services, session environment, QML modules, audio, networking, ydotool, Darkly/Foot theming, or runit-backed providers fail after restart/reboot.
---

# iNiR Void runtime debugging

Use this skill for live-session failures. Prefer evidence from the active Void
session over assumptions from package presence or a clean config file.

## Read first

Read:

- `AGENTS.md`
- `docs/VOID_PORT_RUNBOOK.md`
- `docs/VOID_VM_VALIDATION.md`
- ADR-0001, ADR-0002, and ADR-0003 for startup/supervision issues

For a provider failure, also use `inir-void-provider`. For closure/reboot work,
use `inir-void-validation`.

## First split: config, transport, or action

For a broken keybind/IPC action, separate these layers:

1. the physical/input event reaches Niri;
2. Niri resolves the expected bind;
3. `spawn` executes;
4. the `inir` launcher reaches Quickshell IPC;
5. the QML target executes;
6. any nested `niri msg`, D-Bus, socket, or service action succeeds.

Do not jump from "the key does nothing" to editing KDL. Compare the normal iNiR
action, a native Niri action, a generic spawn, and direct QML IPC. Use
ydotool/uinput when possible so the test crosses the real compositor bind path.

Turnstile is not in the hot path of every keypress. It matters when the session
or shell is starting/restarting and the Niri environment must be propagated to
runit.

## Session environment

The primary Void profile uses Turnstile/runit and must inherit the live Niri
session environment. Inspect the actual Quickshell process, not the automation
shell:

```bash
qpid=$(pgrep -u "$USER" -af '/usr/bin/qs -n -p .*/quickshell/inir' |
  awk 'NR==1{print $1}')
tr '\0' '\n' < "/proc/$qpid/environ" |
  grep -E '^(PATH|WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|NIRI_SOCKET|INIR_VENV)='
```

A stale `NIRI_SOCKET` can make outer IPC look successful while a nested
`niri msg` fails. The startup handoff must publish the new environment and
restart only the iNiR service.

## SSH/automation is usually not the graphical session

A non-graphical shell can make Doctor report `Niri not detected` or make `qs`
say no instance exists. That is not enough to diagnose the desktop. Confirm:

- SDDM/Niri process ancestry;
- the live Quickshell process;
- its environment under `/proc/<pid>/environ`;
- the active user runtime dir and D-Bus socket.

## Supervisor and duplicate-process checks

For user services, inspect the active `~/.config/service/*` runit tree. For
root-owned services, combine persistent links with runtime proof.

When checking duplicate shell/helper regressions, use exact counts:

```bash
pgrep -x qs
pgrep -x swayidle
ps -eo pid,comm,args | awk '$2=="python3" && /keyboard_lock_state_daemon.py/'
```

Require one supervised Quickshell shell, one iNiR `swayidle`, and one keyboard
lock daemon after restart/reboot. Do not count the grep/test shell itself.

## Root runit service trap

On Void an unprivileged:

```bash
sv status /var/service/NetworkManager
```

can report `access denied` even while the service is healthy. Cross-check:

- `/var/service/<name>` and persistent default runsvdir links;
- `runsv <name>` process;
- daemon child process;
- D-Bus/socket owner;
- operational CLI (`nmcli`, `powerprofilesctl`, `bluetoothctl`, etc.).

## Network regressions

For NetworkManager failures, determine who actually owns connectivity. Package
presence alone is insufficient. Check:

- `nmcli -t -f STATE general`;
- device connection state;
- default route;
- NetworkManager `runsv`/daemon ancestry;
- `/var/service/NetworkManager` and persistent default link;
- competing `dhcpcd`, standalone `wpa_supplicant`, or `wicd` service links.

Never disable the working network stack silently. The installer migration is
confirmation-gated and rollback-safe.

## QML/runtime failures

When panels or sidebars vanish:

1. inspect the current Quickshell log;
2. search missing QML modules/component-load/TypeError/ReferenceError/stale
   socket errors;
3. verify the required package is in the selected Void profile;
4. reproduce after shell restart;
5. add a local-distribution regression guard for mandatory dependencies.

## Theme/provider regressions

Two historical false positives are worth checking explicitly:

- **Darkly:** style loading can pass while `darkly-settings6` fails. Require
  `darkly6.so` **and** `kcm_darklydecoration.so`, verify `ldd`, then smoke the
  settings app.
- **Foot:** the canonical generated include is
  `~/.config/foot/inir-colors.ini`. If `foot.ini` references legacy
  `colors.ini`, run the generator/repair path and validate with
  `foot --check-config` when Foot is installed.

## Logging regressions

Root-owned daemons must not spray stdout/stderr onto tty1. Managed noisy runit
services should own a log subservice. Verify both daemon and logger liveness;
a quiet tty is not enough if the service died.

## Claims

Distinguish live validation, mechanical checks, and unverified hardware/visual
claims. Never call an icon visually correct because its file exists, and never
infer graphical failure from an SSH shell missing Niri environment variables.
