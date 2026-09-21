---
name: inir-void-release
description: Close or refresh an iNiR Void release candidate. Use when checking Snow upstream parity, preparing/merging a prerelease PR, doing the final VM and hardware gates, updating closure documentation, or deciding that the Void port is ready to hand to another user.
---

# iNiR Void release / closure workflow

Use this skill for the repeated end-of-cycle work around `prerelease`.

## 1. Refresh upstream and fork state

Fetch both remotes and record:

- `origin/main`
- `origin/prerelease`
- `upstream/main`
- `upstream/prerelease`

Compare both directions. Do not say "up to date with Snow" unless the current
upstream refs were actually fetched in this session.

`main` is the upstream baseline. Void release work targets the fork's
`prerelease`.

## 2. Protect live/dirty checkouts

The physical Void installation may contain useful dirty validation changes. Do
not reset, stash, or repurpose that checkout. If the current tree is not clean,
create a disposable clone/worktree from `origin/prerelease` and publish from
there.

## 3. Make the release delta small

Create a short-lived branch from `origin/prerelease`. Keep code/test work
separate from large docs-only sweeps when that improves reviewability.

Typical commit shape:

```text
fix(void): <provider/runtime fix>
docs(void): <validated behavior or closure update>
```

## 4. Run local gates

At minimum:

```bash
bash -n <touched shell files>
git diff --check
make test-local
```

Add Python compile, versioned checker, and ShellCheck where relevant. If
ShellCheck is unavailable, record that fact rather than claiming it passed.

## 5. Validate in `voidlinux-release-clean`

Discover the VM's current address dynamically. Pull the latest fork
`prerelease`, overlay the candidate, then run:

- the relevant versioned checker;
- idempotency mode when supported;
- real provider/runtime operation;
- `make test-local` inside Void.

For lifecycle changes, reboot and re-run the session/service checks.

## 6. Use physical Void for the final unvirtualized facts

Only after VM closure, use the external-disk install for hardware facts such as
real Wi-Fi ownership, Bluetooth controller, laptop power profiles, SDDM login,
and helper convergence. Preserve the physical checkout if dirty.

## 7. Update closure documentation

Review at least:

- `AGENTS.md`
- `docs/VOID.md`
- `docs/VOID_CAPABILITIES.md`
- `docs/VOID_PORT_RUNBOOK.md`
- `docs/VOID_VM_VALIDATION.md`

Record exact observed evidence and explicitly distinguish historical checkpoint
text from current closure state.

If public installer/runtime behavior changed, also review README, INSTALL,
SETUP, PACKAGES, RUNTIME, AUTOSTART, PROJECT_MAP, sidebar/index, and localized
README distro notes.

## 8. Baseline the docs verifier

Run `scripts/verify-docs.sh`. If it is non-zero, run the same verifier in a
detached clean `origin/prerelease` worktree and compare the findings. Known
repository-wide baseline failures are not automatically caused by the Void
change.

## 9. Review, scan, publish

Before committing:

- inspect `git status` and the final diff;
- ensure no unrelated user files are staged;
- run the staged secret scan when available.

Then push the short-lived branch, open a PR against **fork `prerelease`**, put
the exact validation evidence in the PR body, merge explicitly after gates
pass, and delete the merged branch.

Do not merge Void work into `main` as part of this closure flow.

## 10. Final release statement

A Void release candidate can be called closed only when:

- current Snow delta is known;
- local suite passes;
- relevant provider/checker/idempotency passes in Void;
- reboot/session persistence is proven where required;
- any necessary physical hardware gate is complete;
- docs match the actual current state;
- remaining exclusions are intentional scope limits, not untested blockers.

For the 2.31.0 closure, WARP account/tunnel operation and pairing an external
Bluetooth device were intentional non-gates; the external-disk network/session
hardware gate itself was completed.
