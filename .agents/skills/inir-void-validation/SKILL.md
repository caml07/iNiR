---
name: inir-void-validation
description: Validate or fat-check the iNiR Void Linux port in the QEMU/libvirt release VM or physical external-disk install. Use for PR closure, checker runs, idempotency, reboot/session gates, Niri/Quickshell runtime validation, runit/Turnstile verification, or deciding whether a Void change is actually complete.
---

# iNiR Void validation

Use this skill for repeatable validation, not implementation guesses.

## Read first

Read:

- `AGENTS.md`
- `docs/VOID_PORT_RUNBOOK.md`
- `docs/VOID_VM_VALIDATION.md`
- `docs/VOID_CAPABILITIES.md`
- the checker for the capability/PR being validated

Use a clean audit checkout/worktree whenever a checker enforces branch or
cleanliness contracts.

## Local gate

Run:

```bash
bash -n <touched shell files>
git diff --check
make test-local
```

Run Python compile checks for touched Python and ShellCheck when available.
State explicitly when ShellCheck is unavailable.

## Canonical release VM

The current release-validation domain is:

```text
voidlinux-release-clean
```

The canonical guest user is `voidcaml`, with the audit checkout normally under
`/home/voidcaml/inir-release-test`.

Do **not** hard-code a DHCP address. Discover it from libvirt/DHCP leases each
session. Pull/fetch the current fork `prerelease` before overlaying a candidate.
Use `INIR_EXPECTED_BRANCH=prerelease` instead of editing historical checker
defaults. Use `INIR_ALLOW_DIRTY=true` only for a known temporary audit overlay.

When supported, enable:

```bash
INIR_VERIFY_IDEMPOTENCY=true
```

## What PASS means

A checker PASS is not enough if runtime state is part of the capability
contract. Validate the relevant layers:

- package/provider;
- managed file/checksum;
- service activation and persistent ownership;
- live process/socket/D-Bus state;
- real iNiR UI/action path;
- second-run convergence;
- reboot persistence when claimed.

## Non-systemd session gate

Require:

- no usable `$XDG_RUNTIME_DIR/systemd/private` user manager;
- a real session D-Bus bus;
- correct Turnstile/runit supervisor tier;
- valid Niri config;
- exactly one supervised Quickshell shell;
- Quickshell's `NIRI_SOCKET` equals the current live Niri socket.

Count the `qs -n -p .../quickshell/inir` shell specifically. Short-lived `qs`
IPC clients do not count as duplicate shells. For the historical helper leak,
also count `swayidle` and `keyboard_lock_state_daemon.py` separately.

## Automation/SSH caveat

An automation shell may not inherit `WAYLAND_DISPLAY`, `DBUS_SESSION_BUS_ADDRESS`
or `NIRI_SOCKET`. A Doctor/Niri failure in that context is not enough to claim
the desktop is broken. Inspect the real graphical process environment and SDDM
session ownership first.

## Reboot gate

For integrated lifecycle/service closure:

1. capture the guest boot ID;
2. request graceful reboot;
3. prove the boot ID changed;
4. use libvirt reset only when graceful reboot fails and disruptive VM testing
   is already authorized;
5. verify SDDM -> packaged `niri --session`;
6. verify the selected supervisor tier and exactly one Quickshell shell;
7. recheck helper counts;
8. validate Niri config and current socket ownership;
9. toggle representative shell actions/sidebars;
10. inject a real keybind through ydotool/uinput when that path changed;
11. verify audio/ydotool as relevant;
12. verify representative fonts, Darkly/KDE integration, and distro assets;
13. scan the current Quickshell log for missing modules/stale socket/component
    load failures;
14. verify NetworkManager, BlueZ, Power Profiles, and other touched services;
15. rerun the relevant checker/idempotency gate after final fixes.

## Physical hardware gate

Use the external-disk Void installation only after VM closure for facts that
need real hardware. The 2.31 closure proved:

- NetworkManager survives reboot and owns live Wi-Fi under runit;
- competing `dhcpcd`/standalone `wpa_supplicant`/`wicd` service links stay off;
- SDDM launches `niri --session`;
- Quickshell, `swayidle`, and the keyboard-lock daemon converge to one each;
- Power Profiles exposes normal profiles on the laptop;
- the physical BlueZ controller is detected and powered.

Do not modify/reset a dirty physical-validation checkout just to make a clean
release branch. Publish from a clean clone/worktree instead.

## Docs verifier baseline

`scripts/verify-docs.sh` has known repository-wide non-Void findings. When it is
non-zero, compare the exact output with a detached clean `origin/prerelease`
worktree. Only call it a regression when the candidate adds a new finding.

## Evidence vocabulary

Use these words precisely:

- **validated** — requested behavior was exercised;
- **mechanical check** — file/config/process state matched but behavior was not
  directly exercised;
- **not verified** — hardware, credentials, visual inspection, or environment
  prevented the check.

Never turn historical evidence into a claim that a current rerun passed.
