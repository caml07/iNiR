---
name: inir-void-validation
description: Validate or fat-check the iNiR Void Linux port in the QEMU/libvirt VM. Use for PR/batch closure, checker runs, idempotency, reboot/session gates, Niri/Quickshell runtime validation, runit/turnstile verification, or deciding whether a Void PR is actually complete.
---

# iNiR Void validation

Use this skill for repeatable validation, not implementation guesses.

## Read first

Read:

- `docs/VOID_PORT_RUNBOOK.md`
- `docs/VOID_VM_VALIDATION.md`
- `docs/VOID_CAPABILITIES.md`
- the checker for the PR being validated

Use a clean VM audit checkout/worktree whenever the checker enforces branch or
cleanliness contracts.

## Local gate

Run:

```bash
bash -n <touched shell files>
git diff --check
make test-local
```

Run ShellCheck when available.

Do not stage or modify unrelated dirty files.

## VM checker pattern

The VM checkpoint uses:

```text
domain: voidlinux
guest: 192.168.122.140
user: voidcaml
```

Never record credentials.

For integration branches, pass `INIR_EXPECTED_BRANCH` rather than editing the
historical default inside a checker.

When supported, enable:

```bash
INIR_VERIFY_IDEMPOTENCY=true
```

Use `INIR_ALLOW_DIRTY=true` only for a known temporary audit modification.
Prefer a clean worktree instead.

## What PASS means

A checker PASS is not enough if the capability contract includes runtime state
that the checker does not exercise.

Validate the relevant layers:

- package/provider;
- managed file/checksum;
- service activation;
- live process/socket/D-Bus ownership;
- UI/action path;
- second-run convergence.

Record hardware/account limitations rather than treating them as success.

## Non-systemd session gate

Require:

- no usable `$XDG_RUNTIME_DIR/systemd/private` user manager;
- a real session D-Bus bus;
- correct supervisor tier;
- valid Niri config;
- exactly one supervised Quickshell shell;
- Quickshell's `NIRI_SOCKET` equals the current live Niri socket.

The `qs` process list may also contain short-lived IPC clients. Count the
`qs -n -p .../quickshell/inir` shell process specifically.

## Reboot gate

For integrated closure:

1. capture boot ID;
2. request graceful reboot;
3. prove the boot ID changed;
4. if graceful reboot is ignored, use a libvirt reset only when the user has
   explicitly authorized reboot/disruptive VM testing;
5. verify tty/login/session ownership;
6. repeat Niri/Quickshell/service checks;
7. toggle both sidebars;
8. focus a disposable Foot window and inject Super+Q through ydotool/uinput;
9. require that the window closes;
10. verify audio/ydotool;
11. verify representative fonts, Darkly/KDE integration, and Void asset mapping;
12. scan the current Quickshell log for missing modules, stale Niri socket
    errors, and component-load failures;
13. verify NetworkManager, BlueZ, and WARP operational signals.

Do not call the rendered UI visually verified unless it was actually inspected.

## Evidence

Write exact observed results to `docs/VOID_VM_VALIDATION.md`.

Use these words precisely:

- validated: the requested behavior was exercised;
- mechanical check: files/config/runtime state matched, but visual/hardware
  behavior was not observed;
- pending/not verified: the environment or credentials prevented the check.

Never turn historical evidence into a claim that a current rerun passed.
