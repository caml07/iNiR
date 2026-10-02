# Void Linux port runbook

Operational runbook for continuing and validating the iNiR Void Linux port.
The user-facing/spec document is `docs/VOID.md`; durable architecture decisions
live in `docs/adr/`; capability status lives in
`docs/VOID_CAPABILITIES.md`.

## Current checkpoint

As of 2026-10-01:

- Canonical integration/release-candidate branch: `prerelease`.
- A fresh authoritative fetch resolved Snow `main` and `prerelease` to
  `c08bb928fe71c6a00bfede3e99ef26fb1825ebe2` (`VERSION=2.32.0`). The active
  candidate `feat/void-upstream-2.32` integrates that exact baseline; generated
  IPC/search artifacts were rebuilt from the merged tree rather than choosing
  one side of the merge.
- Supported V1 target: **Void Linux x86_64 glibc + runit +
  elogind/Turnstile**. musl, non-x86_64 and seatd-only sessions are explicitly
  outside the current release gate.
- PR1 through PR7 engineering closure, the 2.31 runtime compatibility fixes,
  clean-VM install, reboot/runtime, privileged Power Profiles activation,
  Web Wallpaper, SDDM graphical-login parity, and the versioned PR3.2-PR7
  checker sweep remain historical validated evidence from the previous closure.
- The external-disk install and post-migration reboot have been performed.
  `nmcli` reported a live connected Wi-Fi device under NetworkManager, runit
  directly supervised the daemon, persistent service ownership was correct,
  and the competing base network services remained disabled. The hardware gate
  is closed.
- A post-closure Void report exposed a partial Darkly provider and stale Foot
  include. The release VM reproduced both states. Darkly was rebuilt and
  installed with KDecoration enabled, `darkly-settings6` passed, and the second
  provider run was idempotent. Foot now has one canonical managed color path,
  `~/.config/foot/inir-colors.ini`.
- The 2.32 physical gate additionally exercised Doctor 27/27, current
  NetworkManager/audio/Bluetooth/Power Profiles/ydotool state, Qt 6.11 family
  switching (`ii -> waffle -> iris -> ii`), TTY/SSH restart + IPC recovery, and
  the optional Kira v3 art pack/companion path. Current v3 lacks the manifest's
  optional JRPG/Codex art lines, so runtime capability-detects those assets and
  falls back to classic art.
- Cloudflare WARP is now a **Void-only optional Extra**, not a toolkit
  dependency. Its provider is metadata-driven and glibc/x86_64-gated; account
  registration and a real tunnel are manual non-gates.
- Packaging iNiR itself as an XBPS package is outside V1.
- The docs verifier is baseline-compared, not waived: on 2026-10-01 both the
  candidate and a detached clean Snow `c08bb928` worktree reported the same
  `SERVICES.md` IPC-documentation drift and the same 1648 missing `kl_GL`
  catalog entries. Treat only additional candidate findings as a Void
  regression.

Do not infer current state from an old feature branch. Check `prerelease` and
`docs/VOID_VM_VALIDATION.md` first.

## Local project skills

Project-specific agent skills live under `.agents/skills/` and are versioned
with the Void port:

- `inir-void-port`: overall roadmap, rules, branching, and implementation flow;
- `inir-void-provider`: provider/provisioning/activation/operation/verification;
- `inir-void-validation`: checkers, idempotency, VM/reboot/hardware closure gates;
- `inir-void-debugging`: live Niri/Quickshell/runit/IPC/session regressions;
- `inir-void-release`: upstream Snow parity, release-candidate closure, final docs,
  PR publication/merge, and the VM -> hardware handoff.

Use the narrowest skill that matches the task. The port skill is the general
entry point; provider/debugging/validation own their focused domains, while the
release skill owns the repeated end-of-cycle `prerelease` closure workflow.

## Non-negotiable rules

### Predicate, not distro

Every systemd-user-sensitive path must use the usable-systemd-user-manager
predicate from ADR-0002:

```text
$XDG_RUNTIME_DIR/systemd/private is a socket
AND
timeout 3s systemctl --user show-environment succeeds
```

Do not substitute:

- `command -v systemctl`;
- `/run/systemd/system`;
- distro-name checks.

Void can run systemd and another distro can lack a usable user manager.

### Provider, not hopeful detection

A Void capability is supported only when all five parts of ADR-0004 exist:

1. provider;
2. provisioning/repair;
3. activation;
4. operation through the existing iNiR surface;
5. repeatable verification.

Provider order:

1. official XBPS package;
2. maintained Flatpak when appropriate;
3. pinned upstream binary/source with provenance, checksum, and update path.

A binary being present is not support.

### Preserve user work

Before editing:

```bash
git branch --show-current
git status --short
```

Historical physical-validation sessions sometimes had user-owned dirty files
or parallel worktrees. Treat those as evidence, not scratch space: never stage,
rewrite, reset or repurpose unrelated local work merely to obtain a clean
release checkout. Create a disposable worktree/clone instead.

## Branch and commit workflow

The fork keeps only long-lived refs that still have an active role:

- `main`: upstream baseline, updated from `upstream/main` by fast-forward
  only;
- `prerelease`: canonical Void integration/release candidate;
- unrelated branches/worktrees owned by other work stay untouched.

Use small short-lived branches for new bugs/providers and merge them explicitly
into `prerelease`. GitHub is configured to delete merged branches
automatically. If a historical branch contains a genuinely divergent tip that
must be preserved, create and verify an
`archive/void-preintegration/*` archive tag before deleting the branch. Do not retain a
large set of stale branches merely as history; commits and archive tags serve
that purpose.

For a discovered bug:

1. reproduce it;
2. add a regression test at an agreed public seam;
3. prove RED;
4. make the minimum GREEN change;
5. run local gates;
6. validate in the Void VM;
7. secret-scan staged files;
8. commit/push the small branch;
9. merge with `--no-ff` into `prerelease`;
10. push integration.

Never amend an existing commit unless explicitly requested.

`main` and `prerelease` are protected against deletion and force-push. Do
not weaken those protections to make a workflow convenient.

The 2026-09-19 cleanup preserved the only four superseded divergent port tips as
these archive tags before deleting their branches:

```text
archive/void-preintegration/docs-void
archive/void-preintegration/missioncenter-provider
archive/void-preintegration/font-providers
archive/void-preintegration/darkly-provider
```

## Local validation

Minimum gate for a touched port path:

```bash
bash -n <touched shell files>
git diff --check
make test-local
```

ShellCheck should also be run when available. It was not installed on the host
at the 2026-09-18 checkpoint.

Before every commit, run the available staged-secret scanner for the local
agent/tooling environment (when present) and inspect the staged diff manually.
No commit is allowed when either review reports a secret or unrelated
user-owned data.

## Void VM

Current release-validation VM:

```text
libvirt domain: voidlinux-release-clean
guest address: DHCP; discover it at validation time
user: voidcaml
canonical repo: /home/voidcaml/inir-release-test
```

For a libvirt-managed guest, `virsh domifaddr voidlinux-release-clean` is one
way to discover the current lease when the host exposes it. Do not persist a
DHCP address as release state.

The guest disk is 30 GiB. The initial 20 GiB release clone was insufficient for
the default dependency profile because the Nerd Fonts transaction exhausted
the root filesystem. The installer now performs a dynamic XBPS space preflight
for missing packages plus 2 GiB of download/build headroom. Credentials are
operator-owned and must never be
written to source, docs, shell history, or skills.

A clean audit checkout/worktree is preferred for versioned checkers. Do not
reuse a dirty runtime checkout merely to make a checker pass.

### Graphical session contract

The normal installed Void entry is SDDM. The base profile installs `sddm` and
`xorg-minimal`; after all installer work is complete, `./setup install` offers
to enable the packaged `/etc/sv/sddm` runit service. SDDM then launches the
packaged Niri desktop entry (`Exec=/usr/bin/niri --session`).

Manual recovery entry from a local TTY remains:

```bash
niri --session
```

Expected primary profile:

- runit system;
- elogind;
- turnstile;
- no usable systemd user manager;
- SDDM graphical login for the normal flow (local tty for recovery/debugging);
- Niri Wayland session;
- Quickshell supervised through `~/.config/service/inir`.

Turnstile's backend may itself run `runsvdir`. That is not the Niri fallback
and is not a duplicate supervisor.

## Session environment

Quickshell and user services depend on the live Niri/session environment.
Important variables include:

```text
PATH
INIR_VENV
ILLOGICAL_IMPULSE_VIRTUAL_ENV
WAYLAND_DISPLAY
XDG_RUNTIME_DIR
DBUS_SESSION_BUS_ADDRESS
NIRI_SOCKET
```

The Niri startup block publishes them with
`turnstile-update-runit-env`. After publishing a new `NIRI_SOCKET`, iNiR's
turnstile service is restarted so the Quickshell process inherits the current
socket.

A stale `NIRI_SOCKET` previously caused `Mod+Q` to return success through
IPC while failing to close the window.

Verify the shell process environment, not just the envdir:

```bash
qpid=$(pgrep -u "$USER" -af '/usr/bin/qs -n -p .*/quickshell/inir' |
  awk 'NR==1{print $1}')
tr '\0' '\n' < "/proc/$qpid/environ" | grep NIRI_SOCKET
```

It must match the current socket in `/run/user/$UID`.

## Supervisor tiers

ADR-0001 defines three tiers:

1. usable systemd user manager -> `inir.service`;
2. active turnstile -> `~/.config/service/inir/run`;
3. otherwise Niri starts a fallback `runsvdir ~/.config/service`.

Exactly one tier owns iNiR at a time.

Under turnstile, iNiR-owned user services include:

```text
inir
pipewire
wireplumber
pipewire-pulse
ydotool
```

Only files carrying `# Managed by iNiR.` may be replaced automatically.

## System services on Void

System-service activation is a separate confirmed-elevation step.

Validated runit services include:

```text
dbus
elogind
polkitd
turnstiled
NetworkManager
bluetoothd
power-profiles-daemon
```

`warp-svc` joins that list only after the user explicitly installs the
Cloudflare WARP Extra. It is not part of a normal Void install or Doctor's
required dependency set.

NetworkManager must not run alongside a competing network service such as
`dhcpcd`, standalone `wpa_supplicant`, or `wicd`. On an interactive Void
install, the final installer stage offers a controlled migration: it removes
the enabled competing runit links, enables NetworkManager, and restores the
previous links if NetworkManager activation cannot be wired. The migration is
deferred until all package/config work is complete because switching network
managers can briefly interrupt connectivity.

When the optional WARP Extra is installed, its iNiR-owned service also owns a
runit logger:

```text
/etc/sv/warp-svc/log/run
exec vlogger -t warp-svc -p daemon
```

Do not send WARP daemon output directly to tty1.

## Package/provider facts already validated

Keep Void package names literal. Important examples:

```text
fish executable        -> fish-shell
Qt 6 Qt5 compatibility -> qt6-qt5compat
Quickshell              -> quickshell
Python Pillow           -> python3-Pillow
ImageMagick             -> ImageMagick
syntax highlighting     -> kf6-syntax-highlighting
Kirigami runtime        -> kf6-kirigami
KDE Qt integration      -> plasma-integration
Power Profiles          -> power-profiles-daemon
```

`kf6-syntax-highlighting` is required in the base profile because both
sidebars use `org.kde.syntaxhighlighting`.

Important non-XBPS providers:

- ydotool v1.0.4: pinned upstream source;
- Cloudflare WARP (optional, Void x86_64 glibc only): latest artifact/version/
  SHA-256 resolved from Cloudflare's official APT metadata, with the last
  verified artifact kept as an offline metadata fallback; Debian maintainer
  scripts are never executed;
- Mission Center: maintained Flathub application;
- adw-gtk3 / WhiteSur / Capitaine: pinned upstream providers;
- Darkly v0.5.39: pinned upstream source, Qt6-only build;
- vertical OCR models: pinned `tessdata_fast` artifacts;
- selected UI fonts: pinned upstream files where Void has no suitable package.

Use the executable provider as the source of truth: normal profile providers
live in `sdata/dist-void/install-deps.sh`; optional WARP metadata/fallback
logic lives in `sdata/lib/extras.sh`.

## Notification conflict rule

Void intentionally installs `dunst` because iNiR uses the `dunstify` client.
The package itself is not an installer conflict.

A running `dunst` notification daemon is still a runtime conflict and remains
covered by `ConflictKiller`/Doctor.

## PR checkers

Versioned VM checkers currently include:

```text
scripts/check-void-pr32.sh
scripts/check-void-pr33.sh
scripts/check-void-pr40.sh
scripts/check-void-pr41.sh
scripts/check-void-pr42.sh
scripts/check-void-pr43.sh
scripts/check-void-pr50.sh
scripts/check-void-pr51.sh
scripts/check-void-pr52.sh
scripts/check-void-pr53.sh
scripts/check-void-pr54.sh
scripts/check-void-pr55.sh
scripts/check-void-pr6.sh
scripts/check-void-pr7.sh
```

For an integration/audit branch, use `INIR_EXPECTED_BRANCH` rather than
editing historical checker defaults.

`check-void-pr43.sh` now reflects WARP's optional-provider contract. Its default
mode checks the provider shape, metadata/fallback fixtures, no-downgrade rule,
musl rejection and QML non-escalation **without requiring WARP to be installed**.
Only a tester who explicitly opts in should run the live daemon path:

```bash
INIR_VERIFY_WARP_LIVE=true ./scripts/check-void-pr43.sh
```

Add `INIR_VERIFY_IDEMPOTENCY=true` only when that same tester is willing to let
the optional provider execute a second install/update pass. Neither flag
registers or connects a Cloudflare account automatically.

Where supported:

```bash
INIR_VERIFY_IDEMPOTENCY=true ./scripts/check-void-prXX.sh
```

Do not waive a dirty-check merely to hide unrelated changes. Use a clean audit
worktree; `INIR_ALLOW_DIRTY=true` is acceptable only when the deliberate
temporary change is understood and recorded.

PR5.1 is intentionally self-contained: it exposes the user-local bin directory
on PATH before testing the `tesseract` adapter so SSH transport does not create
a false negative.

PR6 validates update/search/catalog operations against the live Void
repositories. For install/remove it prefers a real system-root transaction when
`sudo -n` is available. Otherwise it creates a user-owned temporary XBPS root,
copies the repository signing keys, and performs a real install/query/remove
transaction there. The latter proves XBPS transaction semantics without
pretending that an interactive sudo password was supplied.

PR7 is the closure checker. In addition to Doctor/versioning/ABI and the
usable-systemd predicate, it guards the final Arch-to-Void parity sweep:

- base runtime providers such as Kirigami, kdialog, breeze-icons, qt6ct, and
  power-profiles-daemon;
- independent OCR provisioning for toolkit or screencapture selections;
- audio parity providers (`alsa-pipewire`, `libdbusmenu-gtk3`);
- XBPS-aware mandatory migrations, uninstall guidance, update/cache-clean UI,
  wallpaper dependency recovery, and SDDM guidance;
- Power Profiles package metadata for the runit service, D-Bus activation file,
  and polkit policy.

The checker intentionally does not claim that a privileged system-service
activation happened when `sudo -n` is unavailable. That final operator action
is evidence collection, not a reason to bypass the elevation boundary.

## Idempotency

Every provider/installer path must converge.

For package providers:

1. snapshot sorted `xbps-query -l`;
2. run the relevant install/repair path;
3. snapshot again;
4. require an empty diff unless an expected provider version changed.

For pinned files/services, snapshot checksums, symlink targets, and managed run
files before and after the second run.

A second run that merely exits zero is not sufficient evidence.

## Reboot gate

Before declaring a batch closed:

1. record the current guest boot ID;
2. reboot the VM;
3. require a new boot ID;
4. verify tty/login/session ownership;
5. verify the usable-systemd predicate;
6. validate Niri config;
7. require exactly one supervised Quickshell shell;
8. compare Quickshell's `NIRI_SOCKET` with the current Niri socket;
9. test sidebars;
10. inject a real Super+Q through ydotool/uinput into a disposable Foot window;
11. verify audio and ydotool services;
12. verify representative fonts, Darkly/KDE integration, and Void asset mapping;
13. scan the current Quickshell log for missing QML modules, stale socket errors,
    or failed component loads;
14. verify NetworkManager, BlueZ, and WARP operational signals.

On the 2026-09-18 VM, `virsh reboot voidlinux` did not produce a new boot ID.
`virsh reset voidlinux` was used for the test after explicit permission to
reboot the VM. Prefer a graceful reboot first.

## Known residual limits

These are not evidence of a broken provider unless scope changes:

- the VM exposes no Bluetooth adapter, so pairing/audio hardware operation is
  not testable there;
- WARP registration/TOS/tunnel operation requires user account state and is not
  part of the automated port gate;
- SPICE clipboard is unavailable in the Wayland-only session because Void's
  current `spice-vdagent` expects X11;
- rendered top-bar Void icon visual confirmation is separate from mechanical
  asset/mapping validation;
- PR6's system-root sudo password prompt was not automated in the VM;
  QML action wiring and a real isolated-root XBPS install/remove transaction
  were validated separately;
- PR7 engineering, release-VM closure, and the external-disk hardware gate are
  implemented and validated. The final post-migration NetworkManager/runit
  capture is recorded in `docs/VOID_VM_VALIDATION.md`.

## Documentation update rules

After changing the port:

- `AGENTS.md`: current agent-facing state and load-bearing rules;
- `docs/VOID.md`: spec, roadmap, supported flow;
- `docs/VOID_CAPABILITIES.md`: provider contract/status;
- `docs/VOID_VM_VALIDATION.md`: commands/evidence actually observed;
- `docs/adr/`: only durable architectural decisions;
- `CONTEXT.md`: only stable domain vocabulary;
- this runbook: operational procedure.

Never document a command as passing unless it was actually run. Mark hardware,
credential, or visual gaps explicitly instead of inferring success.
