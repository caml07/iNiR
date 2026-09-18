---
name: inir-void-port
description: Continue or modify the iNiR Void Linux port. Use for any task involving Void/runit/XBPS support, port roadmap work, session supervision, systemd predicates, PR1-PR7 scope, or general Void implementation decisions in this repository.
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
capability, and `docs/VOID_VM_VALIDATION.md` when interpreting prior VM
evidence.

## Load-bearing rules

- Predicate, not distro: every systemd-user-sensitive path uses ADR-0002's
  usable-systemd-user-manager predicate.
- Provider, not hopeful detection: a supported capability needs provider,
  provisioning, activation, operation, and repeatable verification.
- Prefer XBPS, then maintained Flatpak, then pinned upstream artifacts.
- Preserve user-owned dirty files and unrelated work.
- Never touch the separate `/home/caml/inir` / `inir-fix` work.
- Do not invent Arch package names for Void.
- Do not add a second shell supervisor or hand-written Niri startup entry.

## Workflow

1. Inspect branch/status and the current integration tip.
2. Identify the PR/batch that owns the change.
3. For a bug, reproduce it before editing.
4. Use TDD at the public seam when behavior changes.
5. Keep the branch small and specific.
6. Run local gates.
7. Validate on the Void VM when the path is Void-specific.
8. Verify idempotency for installers/providers.
9. Update only the docs whose claims changed.
10. Secret-scan before commit.
11. Commit/push the small branch and merge explicitly into the current
    integration branch when the user has authorized that workflow.

## Current roadmap

At the 2026-09-18 checkpoint:

- PR1-PR5.5 are implemented and fat-checked.
- Integration branch is `feat/void-pr5`.
- PR6 owns XBPS UI.
- PR7 owns final closure/release validation.

Verify these facts against Git and the runbook before relying on them in a
later session.
