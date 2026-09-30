---
name: inir-void-port
description: Continue or modify the iNiR Void Linux port. Use for any task involving Void/runit/XBPS support, upstream Snow syncs, session supervision, systemd predicates, provider repairs, or general Void implementation decisions in this repository.
---

# iNiR Void port

Use this skill for general work on the Void Linux port.

## Read first

Before editing, read:

1. `AGENTS.md`
2. `CONTEXT.md`
3. `docs/VOID.md`
4. `docs/VOID_PORT_RUNBOOK.md`
5. the ADRs relevant to the touched area

Use `docs/VOID_CAPABILITIES.md` when the task affects a user-visible
capability, `docs/VOID_VM_VALIDATION.md` when interpreting prior evidence, and
`inir-void-release` when the task is primarily upstream sync/release closure.

## Current state

The 2.31.0 Void port is closed on the fork's `prerelease` branch through:

- full Snow baseline parity at `9574fa42` when the gate was closed;
- PR1-PR7 engineering closure;
- clean release-VM install/reboot/runtime validation;
- SDDM graphical-login parity;
- NetworkManager migration and real post-reboot hardware validation;
- runit orphan-helper cleanup and Turnstile xembed env repair;
- Darkly Qt style + KDecoration settings KCM;
- canonical Foot `~/.config/foot/inir-colors.ini` theming path;
- documentation/installer/XBPS/runit coverage.

Never assume those exact refs are still current. Fetch `origin` and `upstream`
first and compare the current branch tips before making a new parity claim.

## Load-bearing rules

- Predicate, not distro: every systemd-user-sensitive path uses ADR-0002's
  usable-systemd-user-manager predicate.
- Provider, not hopeful detection: a supported capability needs provider,
  provisioning, activation, operation, and repeatable verification.
- Prefer XBPS, then maintained Flatpak, then pinned upstream artifacts.
- Preserve user-owned dirty files and unrelated work.
- A dirty physical-validation checkout is evidence, not a scratch tree. Use a
  clean clone/worktree for edits and publishing.
- Do not invent Arch package names for Void.
- Do not add a second shell supervisor or hand-written Niri startup entry.
- `main` is the upstream baseline; Void work integrates through `prerelease`.

## Standard workflow

1. Fetch `origin` and `upstream` and inspect the exact deltas against
   `origin/prerelease`.
2. Check the active worktree path, branch, and dirty state before touching it.
3. If the live/physical checkout is dirty, create a clean temporary clone or
   worktree from `origin/prerelease`.
4. Create one small `fix/*`, `feat/*`, or `docs/*` branch.
5. For bugs, reproduce the failure before editing.
6. Add the smallest RED regression/checker contract, then implement GREEN.
7. Run local gates.
8. Validate Void-specific behavior in `voidlinux-release-clean`.
9. Verify idempotency for installers/providers.
10. Reboot when persistence/session ownership is part of the claim.
11. Use physical hardware only for facts the VM cannot prove.
12. Update the capability ledger + exact validation evidence.
13. Compare docs-verifier failures with a clean `origin/prerelease` baseline.
14. Review the diff and run the staged secret scan when available.
15. Commit/push the small branch, open a PR to the fork's `prerelease`, merge
    explicitly after the gates pass, and delete the short-lived branch.

## Repeated lessons

- Turnstile/runit is session lifecycle, not a per-keybind hot path.
- SSH/automation shells often lack the graphical `NIRI_SOCKET` even while Niri
  and Quickshell are healthy.
- An unprivileged `sv status` denial on a root runit service does not prove the
  service is dead; inspect `runsv`, daemon ancestry, D-Bus/socket state, and the
  feature's real CLI.
- NetworkManager migration and SDDM activation stay confirmation-gated and late
  in setup.
- Count the supervised `qs -n -p .../quickshell/inir` process specifically;
  short-lived IPC `qs` clients are not duplicate shells.
- Darkly support is incomplete without `kcm_darklydecoration.so`.
- Foot uses `inir-colors.ini`; plain `colors.ini` is legacy migration input.
- Large font/XBPS transactions require free-space headroom.

## Validation shorthand

Before finishing a normal code task:

```bash
bash -n <touched-shell-files>
git diff --check
make test-local
```

Run ShellCheck when available. For Void-specific changes, also run the relevant
versioned checker in the release VM and idempotency mode where supported.

## Documentation contract

At minimum review after a Void behavior change:

- `AGENTS.md`
- `docs/VOID.md`
- `docs/VOID_CAPABILITIES.md`
- `docs/VOID_PORT_RUNBOOK.md`
- `docs/VOID_VM_VALIDATION.md`

If installation/session behavior changed, also review README, INSTALL, SETUP,
PACKAGES, RUNTIME, AUTOSTART, and localized distro-support notes.
