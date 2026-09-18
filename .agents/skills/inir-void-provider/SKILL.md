---
name: inir-void-provider
description: Add, repair, or review a concrete Void capability provider for iNiR. Use when mapping an iNiR feature to XBPS, Flatpak, or a pinned upstream artifact; editing Void dependency profiles; creating runit/turnstile activation; or writing provider checkers/idempotency tests.
---

# iNiR Void provider workflow

Use this skill when a Void capability needs a provider or an existing provider
is incomplete.

## Required references

Read:

- `docs/adr/0004-void-capability-providers.md`
- `docs/VOID_CAPABILITIES.md`
- `docs/VOID_PORT_RUNBOOK.md`
- `sdata/dist-void/install-deps.sh`
- `sdata/lib/deps-map.sh`

Read the feature's QML/scripts too; operation must be validated through the
existing iNiR surface, not only by launching a binary manually.

## Provider decision order

Choose the first viable option:

1. official XBPS package;
2. maintained Flatpak when the app model fits;
3. pinned upstream binary/source.

For upstream providers require:

- exact version/commit;
- stable URL/source provenance;
- SHA-256 verification;
- explicit install location;
- repair/update detection;
- no unreviewed distro maintainer scripts;
- repeatable VM verification.

## Five-part contract

Do not mark the capability supported until all are present:

### Provider
Concrete package/Flatpak/artifact is named and obtainable.

### Provisioning
Install/repair path is deterministic and idempotent.

### Activation
Use the correct model:

- runit system service for root-owned Void daemons;
- turnstile/runsvdir user service for session daemons;
- direct process for one-shot tools;
- systemd user unit only when ADR-0002 predicate holds.

### Operation
The existing iNiR UI/action works without embedding distro-specific behavior in
the UI layer.

### Verification
Create or extend a versioned checker and execute it in the Void VM.

## Dependency profile rules

Profiles mirror the existing installer model: base, audio, toolkit,
screencapture, fonts/theme.

Selecting a profile must provision every provider required by that profile.
Do not leave a visible control that depends on a package the selected profile
does not install.

Important validated Void naming differences are recorded in
`docs/VOID_PORT_RUNBOOK.md`. Re-query XBPS when adding a new package rather
than guessing.

## TDD and idempotency

For every provider change:

1. add a regression/provider contract first;
2. prove RED;
3. implement the minimum GREEN path;
4. run `bash -n`, `git diff --check`, and `make test-local`;
5. run the provider checker in a clean VM audit checkout;
6. run its idempotency mode or an equivalent before/after snapshot.

A successful second command with changed provider files is not idempotent.

## Documentation

Update `docs/VOID_CAPABILITIES.md` only after the five-part contract is
satisfied. Record actual VM evidence in `docs/VOID_VM_VALIDATION.md`.
