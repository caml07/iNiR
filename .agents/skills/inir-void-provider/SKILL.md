---
name: inir-void-provider
description: Add, repair, or review a concrete Void capability provider for iNiR. Use when mapping an iNiR feature to XBPS, Flatpak, or a pinned upstream artifact; editing Void dependency profiles; creating runit/Turnstile activation; or writing provider checkers/idempotency tests.
---

# iNiR Void provider workflow

Use this skill when a Void capability needs a provider or an existing provider
is incomplete.

## Required references

Read:

- `AGENTS.md`
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

For upstream providers require exact version/commit, provenance, SHA-256,
explicit install location, deterministic repair/update detection, no unreviewed
distro maintainer scripts, and repeatable VM verification.

## Five-part contract

A capability is not supported until all five are true:

1. **Provider** — exact package/Flatpak/artifact is obtainable.
2. **Provisioning** — install/repair is deterministic and idempotent.
3. **Activation** — correct ownership model is used.
4. **Operation** — the real iNiR UI/action works.
5. **Verification** — repeatable checker + live runtime evidence exist.

Activation choices:

- root-owned Void daemon -> runit system service;
- user/session daemon -> Turnstile/runsvdir user service;
- one-shot tool -> direct process;
- systemd user unit -> only when ADR-0002's usable-user-manager predicate holds.

## TDD and idempotency

For every provider repair:

1. capture the incomplete/broken state;
2. add a regression/provider contract and prove RED;
3. implement the minimum GREEN path;
4. run `bash -n`, `git diff --check`, and `make test-local`;
5. run the provider checker in `voidlinux-release-clean`;
6. run its idempotency mode or compare explicit before/after snapshots;
7. if persistence is part of the provider, reboot and prove ownership again.

A second command that exits zero while changing provider files is not
idempotent.

## Provider completeness lessons from the port

- **NetworkManager:** package presence is not enough. Void may still have
  `dhcpcd`/standalone `wpa_supplicant` owning the network. Migration must be
  interactive, rollback-safe, and deferred until the rest of installation is
  complete. Validate live `nmcli`, persistent runit links, daemon/runsv
  ancestry, and absence of competing service links.
- **SDDM:** enable late, confirm explicitly, verify the packaged Niri desktop
  entry, and refuse to trample another display manager.
- **Darkly:** `darkly6.so` alone is a partial install. Require the Qt style plus
  `org.kde.kdecoration3.kcm/kcm_darklydecoration.so`; verify `ldd`,
  `darkly-settings6`, and second-run convergence. Void needs
  `kf6-kdecoration-devel` and decorations enabled.
- **Foot theming:** installer, shipped config, generator, repair, and uninstall
  must agree on `~/.config/foot/inir-colors.ini`; migrate the old `colors.ini`
  include instead of accepting two competing contracts.
- **Root runit services:** unprivileged `sv status` can report access denied even
  for a healthy service. Verify symlink + `runsv` parent + daemon + D-Bus/socket
  or feature CLI.
- **Fonts/large profiles:** keep the dynamic free-space preflight; a successful
  provider design includes enough disk headroom for the real XBPS transaction.

## Dependency profile rules

Profiles mirror the installer model: base, audio, toolkit, screencapture,
fonts/theme. Selecting a profile must provision every provider required by that
profile. Re-query XBPS when adding a package; do not guess from Arch naming.

## Documentation

After the five-part contract passes:

- update `docs/VOID_CAPABILITIES.md` with exact current state;
- append actual VM/hardware evidence to `docs/VOID_VM_VALIDATION.md`;
- update `docs/VOID.md` / runbook when installer/service semantics changed;
- never upgrade a mechanical file check into a live/visual/hardware claim.
