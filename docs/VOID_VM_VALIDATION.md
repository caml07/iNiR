# Void VM validation log

Validation record for the Void Linux port work performed from 2026-08-29
through 2026-09-18. This is an execution log, not a replacement for the port
specification in `docs/VOID.md`.

## Host and VM

- Host: Linux workstation with KVM available at `/dev/kvm`.
- QEMU: `11.1.1` (`qemu-system-x86_64`, `qemu-img`).
- libvirt client/library: `12.6.0`.
- Domain: `voidlinux` on `qemu:///system`.
- Guest: Void Linux glibc, `x86_64`.
- Firmware: UEFI/OVMF with secure boot enabled.
- Machine: Q35.
- Resources: 4 GiB RAM and 4 vCPUs.
- CPU: `host-passthrough`.
- Storage: VirtIO disk with this active backing chain:
  `voidlinux.qcow2` -> `voidlinux.1788039290` ->
  `voidlinux.1788039614` -> `voidlinux.void-niri-quickshell-installed` ->
  `voidlinux.void-niri-session-baseline`.
- Network: libvirt `default` network, VirtIO NIC, guest address DHCP-assigned
  (observed as `192.168.122.141` in August, `192.168.122.140` on 2026-09-05;
  confirm with `virsh --connect qemu:///system domifaddr voidlinux`).
- Display: SPICE with host GL render node
  `/dev/dri/by-path/pci-0000:00:02.0-render`.

The VM was created as UEFI rather than BIOS. Nothing in the renderer problem
indicated that firmware choice was relevant.

## Guest setup

The XBPS repository metadata was refreshed before package checks. The relevant
packages installed or verified during the test were:

- `niri-26.04_1`
- `quickshell-0.3.0_2`
- `elogind`
- `dbus`
- `polkit`
- `turnstile`
- `openssh`
- `mesa-dri`
- `mesa-vulkan-lavapipe`
- `qt6-qt5compat`
- `vulkan-loader`

Active system services observed through runit were:

- `dbus`
- `elogind`
- `polkitd`
- `sshd`

The `turnstiled` service directory was present but was not enabled during this
baseline. That is a later session-supervisor test, not part of the renderer
fix.

`elogind` created `seat0`; `loginctl seat-status seat0` showed the local
`tty1` session and DRM master ownership for `card0`.

`/etc/locale.conf` was set to:

```text
LANG=en_US.UTF-8
```

One existing SSH environment still reported `LANG=es_NI.UTF-8`, so locale
propagation should be checked again from a fresh login if it matters to the
installer test.

## Initial session test

Void's installed Niri package exposed `/usr/bin/niri` and a desktop entry with
`Exec=/usr/bin/niri --session`. In this VM, `niri-session` was not available,
so the working manual session command was:

```bash
niri --session
```

The session was started from local `tty1`; starting Niri through SSH was not
used because the local TTY/DRM session is required. Before the renderer fix,
Niri started far enough to show a grey background and a black mouse cursor,
but it did not expose an active output to its IPC.

QuickShell also reached its QML startup markers:

```text
shell.qml ready
first frame
```

That did not prove that a usable compositor output existed. Optional runtime
warnings included missing `QtMultimedia`, `swayidle`, `curl`, `wpctl`,
`pw-dump`, UPower, and `xwayland-satellite`; they were not the cause of the
empty Niri output list.

## Renderer failure

The first libvirt video configuration contained:

```xml
<video>
  <model type='virtio' heads='1' primary='yes' device='virtio-vga'>
    <acceleration accel3d='yes'/>
  </model>
</video>
```

The XML claimed 3D acceleration, but the effective QEMU command line used:

```text
-device {"driver":"virtio-vga", ...}
```

The guest kernel confirmed that VirGL was disabled:

```text
[drm] features: -virgl +edid -resource_blob -host_visible
```

Niri's debug log then reported:

```text
failed to initialize renderer, falling back to primary gpu: software EGL renderers are skipped
error adding primary node device, display-only devices may not work: no allocator available for device
```

The corresponding IPC query returned an empty object:

```json
{}
```

The initial `virtio-vga` device was therefore the root cause of the missing
usable Niri output, not the UEFI firmware or the monitor mode list.

## Renderer fix

`virt-xml --edit --video model=virtio,accel3d=yes` made no change because
`accel3d` was already present. The persistent domain XML was changed with a
raw XPath edit:

```bash
virt-xml -c qemu:///system voidlinux \
  --edit \
  --xml './devices/video/model/@device=virtio-vga-gl' \
  --define
```

The VM was shut down and started again. The new effective QEMU command line
confirmed the intended device:

```text
-device {"driver":"virtio-vga-gl","id":"video0", ...}
```

The guest then reported:

```text
[drm] features: +virgl +edid -resource_blob -host_visible
[drm] features: +context_init
[drm] number of cap sets: 2
```

This is the successful VirGL checkpoint. No further VM XML change is needed
for this issue.

## Final Niri verification

Niri was started from `tty1` and remained running. From an SSH session for the
same user, the IPC socket was located explicitly because SSH did not inherit
the compositor environment:

```bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export NIRI_SOCKET="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 \
  -type s -name 'niri.*.sock' -print -quit)"
niri msg --json outputs
```

The command returned a real output instead of `{}`:

```json
{
  "Virtual-1": {
    "name": "Virtual-1",
    "make": "Red Hat, Inc.",
    "model": "QEMU Monitor",
    "modes": [
      {"width": 1280, "height": 800, "refresh_rate": 74994, "is_preferred": true}
    ],
    "current_mode": 0,
    "logical": {
      "x": 0,
      "y": 0,
      "width": 1280,
      "height": 800,
      "scale": 1.0,
      "transform": "Normal"
    }
  }
}
```

The full response also listed the QEMU monitor's additional advertised modes.
The make-or-break VM graphics test is now passed: VirGL is active and Niri
has a usable `Virtual-1` output at `1280x800`.

## Predicate and migration guard validation

On 2026-08-30, the PR 1 branch `feat/void-systemd-predicate` was checked from
an SSH session in the Void guest. The test used the real elogind runtime path,
not a temporary test directory:

```text
runtime=/run/user/1000
socket=/run/user/1000/systemd/private
socket_exists=false
predicate=false
elapsed_ms=2
```

The migration contract was then tested in an isolated temporary home and
configuration directory. A mocked `systemctl` function counted invocations so
the test did not depend on the command merely being absent from `PATH`:

```text
021-systemd-single-instance check_rc=1 apply_rc=0
022-service-compositor-wants check_rc=1 apply_rc=0
systemctl_calls=0
```

This confirms that Void without a usable systemd user manager treats both
migrations as no-ops, returns in under three seconds, and does not call
`systemctl --user`.

The host-side Bash contract suite also passed:

```text
4 suites passed, 0 suites failed
```

## PR 2 dependency validation

On 2026-08-30, the PR 2 branch `feat/void-dependencies` was validated from
the canonical `/home/voidcaml/inir-src` checkout on Void:

```text
branch=feat/void-dependencies
commit=ad00883e feat(install): add Void XBPS dependency installation (PR2)
worktree=clean
```

The dependency route was run twice with setup and file installation skipped:

```bash
cd /home/voidcaml/inir-src
./setup install -y --skip-sysupdate --skip-setups --skip-files
xbps-query -l | sort > /tmp/inir-pr2-packages-1.txt
./setup install -y --skip-sysupdate --skip-setups --skip-files
xbps-query -l | sort > /tmp/inir-pr2-packages-2.txt
diff -u /tmp/inir-pr2-packages-1.txt /tmp/inir-pr2-packages-2.txt
```

Both runs completed successfully. The final `diff` was empty, confirming
package-install idempotency. XBPS prefixes already-installed package notices
with `ERROR`, but both transactions completed and the installer reported:

```text
Dependencies installed
Installation complete
```

All five groups passed: base, audio, toolkit, screencapture, and fonts/theme.
Void-specific names validated by the VM include `python3-Pillow`, `geoclue2`,
`tesseract-ocr`, `tesseract-ocr-eng`, `tesseract-ocr-spa`, and `ImageMagick`.
The unavailable `adw-gtk3`, `capitaine-cursors`, and `whitesur-icon-theme`
packages were excluded from the XBPS group.

Host-side PR 2 validation also passed:

```text
5 suites passed, 0 suites failed
27 tests passed, 0 tests failed
```

PR 2 is complete on the fork and ready for PR 3, `feat/void-runsvdir-supervisor`.

## Turnstile contract validation (2026-08-31)

On 2026-08-31, the installed turnstile package was inspected from the Void
guest. Key findings that affect the PR3 plan:

```text
xbps-query -p pkgver turnstile elogind dbus niri
```

This query failed because this `xbps-query` accepts one package name per
invocation, so package versions were not recorded by this probe.

```text
ERROR: xbps-query: too many arguments
```

`/usr/share/examples/turnstile` contains the expected `dbus.run` and
`dbus.check` examples for the user D-Bus service.

```text
grep -RIn 'manage_rundir\|TURNSTILE_ENV_DIR\|turnstile-ready' \
  /usr/share/doc/turnstile /etc/turnstile 2>/dev/null
```

```
/usr/share/doc/turnstile/README.voidlinux:6:these services can be listed in ~/.config/service/turnstile-ready/conf, for
/usr/share/doc/turnstile/README.voidlinux:11:The turnstile-ready service is created by turnstile on first login.
/usr/share/doc/turnstile/README.voidlinux:21:	+ exec chpst -e "$TURNSTILE_ENV_DIR" foo
/usr/share/doc/turnstile/README.voidlinux:23:Inside user services, the convenience variable "$TURNSTILE_ENV_DIR" can be used
/usr/share/doc/turnstile/README.voidlinux:47:  (manage_rundir = no)
/etc/turnstile/backend/runit.conf:10:ready_sv="turnstile-ready"
/etc/turnstile/turnstiled.conf:48:# Note that lingering is disabled when manage_rundir is
/etc/turnstile/turnstiled.conf:81:manage_rundir = yes
```

Observations:

- The installed turnstile version remains unverified; the multi-package
  `xbps-query` probe failed with "too many arguments".
- The documentation explicitly recommends `manage_rundir = no` with elogind
  (README line 47), but the default config ships with `manage_rundir = yes`.
  PR3.1 must resolve this explicitly.
- User services must wrap their exec with `chpst -e "$TURNSTILE_ENV_DIR"` to
  receive the session environment (README line 21).
- The session D-Bus bus is **not** started automatically by
  `core_services="dbus"`; the user must install the example `dbus.run` and
  `dbus.check` into `~/.config/service/dbus/` and then list `dbus` in
  `turnstile-ready/conf`.
- The `turnstile-ready` service is created by turnstile on first login; it is
  not present before that.

Service status check:

```text
sudo sv status /var/service/elogind
run: /var/service/elogind: (pid 625) 14488s; run: log: (pid 624) 14488s
```

```text
sudo sv status /etc/sv/turnstiled
warning: /etc/sv/turnstiled: unable to open supervise/ok: file does not exist
```

`elogind` is active and providing `/run/user/1000`. `turnstiled` is installed
but not enabled (no supervise directory). This confirms the starting state for
PR3.1: turnstile activation is a clean transition, not a migration.

## PR3.0 implementation fixes (2026-08-31)

The following blockers were identified and fixed before VM re-test:

1. **Missing build deps in Void profile** — `sdata/dist-void/install-deps.sh` lacked
   `rsync`, `base-devel`, `pkg-config`, `cairo-devel`, `python3-devel`,
   `glib-devel`, `gobject-introspection`, `python3-gobject-devel`, `libffi-devel`.
   Added to `VOID_BASE_PACKAGES` (PR2 fix `3444ccbd`).

2. **rsync failure masked by `rsync | awk` pipeline** — `rsync_dir` and
   `rsync_dir__sync` in `sdata/lib/functions.sh` now write rsync output to a
   temp file, check its exit code, and only then process with awk. On failure,
   the manifest is not updated and the function returns the rsync error code.

3. **`systemctl --user` calls without predicate** — All user-systemd calls in
   `sdata/lib/functions.sh` (`ensure_launcher_path_in_shells`,
   `inir_user_service_is_masked`, `repair_legacy_quickshell_malloc_environment`)
   and `setup` (`sync_user_inir_service_from_repo_if_present`,
   `ensure_user_inir_service_enabled`, package-managed update restart) now
   gate on `has_usable_systemd_user_manager` instead of `command -v systemctl`.

4. **Supervisor logic duplicated and turnstile leaked into PR3.0** — Extracted
   `reconcile_inir_supervisor()` shared helper to `sdata/lib/functions.sh`.
   PR3.0 now always selects `runsvdir` when predicate is false; turnstile
   detection removed from both `3.files.sh` and `setup` (turnstile is PR3.1 scope).

5. **`setup update` used different rsync excludes than install** — Update now
   calls `rsync_dir__sync` with full `RUNTIME_EXCLUDES` and propagates failures.

6. **`ONLY_MISSING_DEPS` implemented for Void** — Update path no longer
   installs full package matrix when doctor reports missing commands.

7. **KDL idempotency** — `update_inir_startup_supervisor` now removes both
   systemd and runsvdir comment variants, preventing duplicate comments on
   repeated renders.

8. **Void Fish package name** — Void provides the `fish` executable through the
   `fish-shell` package, not a package named `fish`. Added `fish-shell` to the
   base profile and changed the `ONLY_MISSING_DEPS` command map accordingly.

All local tests pass (13 suites including new: rsync failure propagation,
supervisor reconciliation, Void profile, turnstile not used in fallback).

## PR3.0 VM checkpoint (2026-08-31)

The fresh install completed successfully at version `2.29.3`:

- File verification passed for critical QML, Niri, iNiR, theming, Fuzzel and
  generated color files.
- `fish-shell` was installed manually after the first terminal launch exposed
  the Void package-name mismatch; Kitty then launched Fish successfully.
- The graphical session ran Niri 26.04 on Wayland with QuickShell 0.3.0.
- `runsvdir /home/voidcaml/.config/service` was running under the Niri session.
- `sv status ~/.config/service/inir` reported `run:` with QuickShell alive.
- `pgrep` confirmed `runsv inir`, QuickShell, clipboard watchers and `swayidle`.
- `grep -c 'BEGIN inir-runsvdir-fallback' ~/.config/niri/config.d/50-startup.kdl`
  returned `1`, confirming no duplicate startup block.

This validates the PR3.0 installer and runsvdir fallback in the VM.

## PR3.1 VM checkpoint (2026-09-01)

The `feat/void-turnstile-session` branch was installed from the canonical
`/home/voidcaml/inir-src` checkout. The system-service symlinks and elogind
configuration were then explicitly enabled with root confirmation.

The Void system services were active after enabling their `/var/service`
symlinks:

```text
run: /var/service/dbus
run: /var/service/elogind
run: /var/service/polkitd
run: /var/service/turnstiled
```

The resulting profile was verified as:

```text
/etc/turnstile/turnstiled.conf: manage_rundir = no
~/.config/service/turnstile-ready/conf: core_services="dbus"
~/.config/service/inir/run: exec chpst -e "$TURNSTILE_ENV_DIR" ... run --session
```

After the next tty login, turnstile created and supervised `dbus`, `inir`, and
`turnstile-ready` under `~/.config/service`. The Niri startup file contained
only the turnstile ownership comment and no `inir-runsvdir-fallback` block.
The `runsvdir` process observed after login belongs to turnstile's runit
backend, not Niri's fallback; exactly one supervisor owns the iNiR service.

From Kitty in the Niri session, the environment was correct:

```text
WAYLAND_DISPLAY=wayland-1
XDG_SESSION_TYPE=wayland
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
```

The VM's SPICE agent channel and `spice-vdagentd` daemon were present, but
`spice-vdagent` exits with status 1 because the session has no X11 `DISPLAY`.
This is an X11-agent limitation in the Wayland-only Niri session and is not a
turnstile or iNiR failure.

## What remains

- PR3.0 validation is complete: installer, KDL injection, migrations,
  `scripts/inir` sv controls, service liveness and idempotency all passed.
- PR3.1 validation is complete: confirmed elevation, D-Bus user service,
  envdir propagation, `manage_rundir = no`, and removal of the Niri runsvdir
  block all passed.
- PR3.2 implementation and VM validation are complete on
  `feat/void-nonsystemd-runtime` (2026-09-02). The versioned checker passed over
  SSH from the host:

  ```bash
  ssh voidcaml@192.168.122.140 '
  cd ~/inir-src && git fetch origin &&
  git checkout feat/void-nonsystemd-runtime && git pull --ff-only &&
  export XDG_RUNTIME_DIR=/run/user/$(id -u) &&
  export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus &&
  INIR_EXPECTED_COMMIT="$(git rev-parse origin/feat/void-nonsystemd-runtime)" \
    ./scripts/check-void-pr32.sh
  '
  ```

  The checker requires a false usable-systemd-user-manager predicate, a real
  user bus, clean branch state, iNiR `sv` supervision, and supported
  `loginctl` power verbs. It skips XEmbed service checks when
  `xembedsniproxy` is not installed.
- Observed result: branch `feat/void-nonsystemd-runtime`, commit `a5ca5d7e`,
  clean checkout, `/run/user/1000`, and
  `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`. All required checks
  passed; `xembedsniproxy` was not installed and was reported as optional.
- PR3.3 was validated on 2026-09-05 from a clean clone of commit `bd0925cd`.
  `scripts/check-void-pr33.sh` passed with the usable-systemd-user-manager
  predicate false, official XBPS `awww`, `jq`, and `pipewire` providers, and
  managed `pipewire`, `wireplumber`, and `pipewire-pulse` turnstile services.
  `pactl info` reported PulseAudio on PipeWire 1.6.7. The clipboard fallback
  round-tripped through `wl-paste`; `awww-daemon`, `awww query`, and `awww img`
  succeeded on `wayland-1`. The undefined `discover-overlay` integration is
  removed. WARP provider/lifecycle validation remains in PR4 and its toggle does
  not issue a systemd command on Void meanwhile.
- PR4.0 was exercised on 2026-09-08 from commit `7d5a0ead`. The first checker
  run correctly found active `dhcpcd` and did not activate NetworkManager.
  After the operator explicitly stopped and removed the `dhcpcd` service link,
  added the user to the `network` group, and enabled `/etc/sv/NetworkManager`,
  `nmcli -t -f STATE g` reported `connected`. The remaining two failures were
  checker-only permission errors reading system runit supervision as an
  unprivileged user. Commit `3dd0b9db` makes the existing `sudo sv status`
  checks report their full results. This is a historical checkpoint; the
  integrated PR4 fat-check later in this document supersedes the pending
  checker status.
- PR4.1 was checked on 2026-09-08 from clean commit `e112c416` after installing
  `libspa-bluetooth-1.6.8_1` and enabling `/etc/sv/bluetoothd`. The versioned
  `scripts/check-void-pr41.sh` contract passed: XBPS `bluez-5.86_2`,
  `blueman-2.4.6_2`, and `libspa-bluetooth-1.6.8_1`; `bluetoothctl` and
  `blueman-manager`; live `bluetoothd` and `dbus` runit services; acquired
  `org.bluez` system D-Bus ownership; and `bluetooth` group membership. The VM
  exposes no Bluetooth adapter, so hardware discovery, pairing, and audio
  operation remain pending. A second dependency/setup run at version `2.30.0`
  found every selected package already installed, made no package changes, and
  produced an empty sorted `xbps-query -l` snapshot diff.
- PR4.2 was checked on 2026-09-09 from clean commit `d0b0da14`. It pins ydotool
  v1.0.4 to the verified upstream source
  archive SHA-256
  `ba075a43aa6ead51940e892ecffa4d0b8b40c241e4e2bc4bd9bd26b61fde23bd`.
  The toolkit path builds only `ydotool` and `ydotoold`, installs them under
  `/usr/local/bin`, configures `/dev/uinput` for the `input` group, and renders
  a user service selected by the usable-systemd predicate. Turnstile and
  runsvdir use `~/.config/service/ydotool`; all tiers retain upstream's
  `$XDG_RUNTIME_DIR/.ydotool_socket` contract. `setup update` detects missing
  or stale provider versions and service reconciliation restarts only a
  version-changed daemon. The versioned checker passed provider binaries and
  version, `input` group, `/dev/uinput` ownership/mode, the supervised user
  service, socket, direct `ydotool key` injection, and full-install idempotency
  (package plus provider-file snapshot). The on-screen keyboard was exercised
  in the lock screen and typed successfully. Superpaste was not separately
  exercised; it shares the validated ydotool path.
- PR4.3 WARP provider gate passed on 2026-09-10. Void had no XBPS
  `cloudflare-warp` provider, so the verified upstream Bookworm artifact
  `cloudflare-warp_2026.7.1377.0_amd64.deb` (SHA-256
  `95d33c2b4fc42f21c204981c51470a6a679d618fb0b78ee64bdd0db142230c55`) was
  extracted without executing Debian scripts. `warp-cli` and `warp-svc` ran on
  Void's glibc loader with XBPS-provided `tpm2-tss`, `dbus-libs`, `nss`, and
  `libpcap`. A temporary root runit service opened
  `/run/cloudflare-warp/warp_service`; `warp-cli status` reached it and asked
  for explicit TOS acceptance. No account was available, so registration,
  connection, and `warp=on` trace validation remain pending.
- PR5.0-PR5.5 desktop parity was validated cumulatively through 2026-09-18.
  Mission Center installs from Flathub with a stable launcher; OCR uses Void
  Tesseract packages plus pinned vertical tessdata models; adw-gtk3, WhiteSur,
  Capitaine, the required fonts, and Darkly are provisioned by explicit
  providers with repeat-install checks. Qt uses KDE platform integration on
  Void and Darkly loads as a real Qt6 KStyle. Rubik resolves natively and the
  stale `Google Sans Flex` default resolves to the guaranteed `Roboto Flex`
  family through a Void-only Fontconfig alias.
- The live Niri/Quickshell closure found and fixed two runtime gaps. First,
  `kf6-syntax-highlighting` was missing from the Void base profile; without it
  `SidebarHost` failed because `org.kde.syntaxhighlighting` could not load.
  After installing the package, both `sidebarLeft toggle` and
  `sidebarRight toggle` succeeded over the real shell IPC.
- The intermittent `Mod+Q` failure was traced to stale compositor IPC state,
  not the physical key or Niri binding parser. `ydotool` reproduced the bug
  end to end: native `Mod+Q { close-window; }` worked, while
  `spawn "inir" "close-window"` returned success without closing the test
  window. Quickshell still held the previous Niri socket after a compositor
  restart. The Turnstile startup handoff now publishes the current
  `NIRI_SOCKET` and restarts only `~/.config/service/inir`, so Quickshell
  inherits the refreshed socket. `Mod+Q` is also marked
  `allow-inhibiting=false`. Final injected Super+Q validation closed the
  focused temporary Foot window (`MOD_Q_END_TO_END=PASS`).
- WARP's runit service now owns a `vlogger` subservice instead of writing
  daemon DEBUG/INFO output directly to tty1. The WARP socket remained live and
  a second service reconciliation left the managed run/log files unchanged.
- The VM disk was expanded online from 20 GiB to 30 GiB with libvirt
  `blockresize`, `growpart /dev/vda 2`, and `resize2fs /dev/vda2`; the root
  filesystem then reported roughly 29 GiB total with about 11 GiB free.
- PR6 implements the remaining XBPS UI recorded in
  `docs/VOID_CAPABILITIES.md`.
- PR7 is the mandatory closure gate: doctor/versioning, the final ADR-0002
  sweep, clean VM installation, and the external-disk validation.
- Run shellcheck and `make test-local` before each PR.

`make test-local`, `bash -n`, JSON parsing, and `git diff --check` passed after
the PR5 runtime closure and Mod+Q lifecycle fix. ShellCheck was not available
in the host environment. No upstream PR has been opened; the Void port remains
a fork progress branch.

## PR1-PR5 fat-check and reboot checkpoint (2026-09-18)

The integrated branch was audited in batches before starting PR6.

### PR1-PR3

The local/VM sweep rechecked the usable-systemd-user-manager predicate, XBPS
dependency routing, runsvdir/turnstile ownership, session environment, Niri
startup, PipeWire user services, and optional runtime adapters. Remaining
predicate-sensitive paths found during the sweep were fixed before continuing.
Night Light uses the Void `wlsunset` provider and Doctor/runtime checks remain
predicate-safe.

### PR4 providers

NetworkManager, BlueZ, ydotool, and WARP were re-exercised in the live VM.
Observed results included:

- NetworkManager and system D-Bus were supervised by runit and
  `nmcli -t -f STATE g` returned `connected`.
- `bluetoothd` was alive and `org.bluez` owned the system D-Bus name. The VM
  still exposes no Bluetooth adapter, so pairing/audio hardware operation is
  not claimed.
- ydotool v1.0.4 had a live user service/socket and a direct uinput key
  injection passed.
- WARP's runit service, socket, and `vlogger -t warp-svc -p daemon` logger were
  alive. Account registration, TOS acceptance, and a real tunnel remain
  intentionally outside this validation.

An interactive privileged run confirmed the root-owned runit service status
checks. A later attempt to rerun the full PR4.2/PR4.3 installer-idempotency
path was blocked only by the test harness being unable to supply a new sudo
credential non-interactively; the provider snapshots/reconcile paths passed,
and the earlier versioned PR4 idempotency evidence above remains the recorded
full-install proof.

The fat-check also fixed two installer presentation/contract gaps: Void now
reports an automated dependency path instead of the generic compatibility
warning, and the installed `dunst` package is no longer treated as a package
conflict merely because iNiR uses its `dunstify` client. A running dunst daemon
remains covered by runtime conflict handling.

### PR5.0-PR5.5

A clean VM audit worktree at integration commit `3763698d` ran all six PR5
checkers with `INIR_VERIFY_IDEMPOTENCY=true`:

- PR5.0 Mission Center: Flatpak/provider wrapper and second-install snapshot
  passed.
- PR5.1 OCR: horizontal language packages, pinned vertical models, model-load
  smoke tests, user-local `tesseract` adapter, and second-install snapshot
  passed. The checker was hardened to add the user-local bin directory to its
  own PATH so SSH transport does not create a false failure.
- PR5.2 visual providers: adw-gtk3, WhiteSur, Capitaine, provenance checks,
  and second-install snapshot passed.
- PR5.3 fonts: required XBPS/pinned fonts, checksums, Fontconfig resolution,
  and second-install snapshot passed.
- PR5.4 Darkly: Qt6/KF6 build dependencies, plugin presence, Qt style loading,
  KDE platform theme, and second-install snapshot passed.
- PR5.5 closure: Rubik, Google Sans Flex -> Roboto Flex alias,
  `plasma-integration`, Niri KDE platform theme, and closure snapshot passed.

### Integrated reboot gate

`virsh reboot voidlinux` did not produce a new guest boot ID, so the final
gate used `virsh reset voidlinux` to force an actual VM reboot without changing
snapshots or disk contents. The boot ID changed from
`19c45771-09ab-4e2b-8562-c1567a0335f1` to
`6b6df81a-0c24-414f-9446-8a7f9c0dbaca`.

After the new boot:

- `loginctl` showed an active local `login` session on tty1, type Wayland.
  `niri --session` was a child of the tty1 shell and exactly one supervised
  Quickshell shell was running.
- `/run/user/1000/systemd/private` was absent, so the non-systemd predicate
  remained active.
- Quickshell's `NIRI_SOCKET` exactly matched the new live Niri socket.
- `niri validate` passed.
- left and right sidebar IPC toggles passed.
- a temporary Foot window was focused and a real Super+Q sequence was injected
  through ydotool/uinput; the window closed (`MOD_Q_END_TO_END=PASS`).
- iNiR, PipeWire, WirePlumber, PipeWire Pulse, and ydotool user services were
  running; `pactl info` and the ydotool socket checks passed.
- Rubik, the Google Sans Flex alias, Material Symbols, Darkly, KDE platform
  integration, and the vendored Void icon asset/mapping passed mechanical
  checks.
- the latest Quickshell log contained no missing-module, stale-Niri-socket,
  failed-component-load, or equivalent severe errors.
- NetworkManager returned `connected`, BlueZ owned `org.bluez`, the WARP socket
  existed, and the WARP `vlogger` process was alive after boot.
- GameMode was exercised through the real `globalActions` IPC. Manual toggle
  changed `inactive (off)` to `active (manual)` and back to `inactive (off)`,
  while no `discover-overlay` process appeared. The effective Void config had
  `suppressNotifications=true` and `disableNiriAnimations=false`, matching the
  repository default. Notification-policy wiring was therefore checked
  mechanically; this gate does not claim Niri animations were disabled in a
  profile where that option is off.

The rendered top-bar Void icon was not separately visually inspected during
this automated gate, and tty1 was not screen-captured to prove absence of log
spam. The runtime asset/mapping and WARP logger path were verified instead.

With these limits recorded, PR1 through PR5.5 are considered fat-checked.

## PR6 XBPS UI validation (2026-09-18)

PR6 was implemented on `feat/void-xbps-ui` from integration tip
`3ce80fe5`. VM validation used a separate audit worktree based on the same
tip so the canonical checkout and older dirty audit worktrees were left
untouched.

The initial PR6 spec used `xbps-remove -Rns`. A direct VM dry-run proved that
this is invalid XBPS syntax: `-n` means dry-run and XBPS has no `-s` remove
flag. The implemented and documented remove command is therefore:

```bash
sudo xbps-remove -R -- "<pkg>"
```

The versioned `scripts/check-void-pr6.sh` then passed in the Void VM. It
verified:

- `xbps-install -nu` update checking (zero pending updates at this checkpoint);
- repository search with `xbps-query -Rs firefox`;
- installed search with `xbps-query -s firefox`;
- every one of the 34 curated `targets.xbps` entries against the live
  configured repository;
- exact package names whose capitalization differs from common distro names,
  including `Signal-Desktop`, `MangoHud`, and `Thunar`;
- a real XBPS install/query/remove transaction for `sl`.

The VM does not permit non-interactive `sudo -n`. Rather than claim an
interactive password was supplied, the checker created a temporary user-owned
XBPS root under `/tmp`, copied the system repository signing keys, installed
`sl` plus its dependencies from the live Void repository, queried the
installed package, dry-ran recursive removal, removed it for real, and
confirmed that it was absent afterward. The temporary root was deleted at the
end of the check.

Quickshell was also loaded offscreen against the PR6 files. Runtime results
were:

```text
PR6_QMLCHECK_PM xbps
PR6_QMLCHECK_SEARCH xbps true Mozilla Firefox web browser
PR6_QMLCHECK_CATALOG xbps firefox true
PR6_QMLCHECK_UPDATES true 0
```

A second harness replaced the configured terminal with a temporary logger and
called the real service methods. `PackageSearch.installPackage`,
`PackageSearch.removePackage`, `AppCatalog.installApp`, and
`AppCatalog.removeApp` all returned true. The captured terminal invocations
contained the expected XBPS actions:

```text
sudo xbps-install -S -- "$1"
sudo xbps-remove -R -- "$1"
```

This separates two claims precisely: the QML operation path to the terminal was
exercised, and XBPS install/remove semantics were exercised with a real
transaction. The system-root interactive sudo password prompt itself was not
automated.

After the `-Rns` correction, host-side `make test-local`, PR6 static checks,
`bash -n scripts/check-void-pr6.sh`, and `git diff --check` passed.
ShellCheck is not installed on the host. The host `qmllint` binary returns
255 without diagnostics even for unchanged repository QML, so it is not
counted as validation evidence; the successful Quickshell loads above are the
runtime QML evidence.

## PR7 engineering-closure sweep (2026-09-18)

The final side-by-side sweep compared the Void port against iNiR's shared
runtime surfaces and Arch dependency-profile contracts instead of relying only
on the historical PR checkers. It found and closed several real parity gaps:

- package UI surfaces still containing Arch-only `yay -Syu`, `paccache`,
  and persisted `arch-update` defaults now delegate to the package-manager
  backend; Void emits `sudo xbps-install -Su` and `sudo xbps-remove -O`;
- migrations 012 and 029 now have explicit XBPS install paths;
- uninstall analysis/guidance now uses `xbps-query -X` and
  `xbps-remove -R`;
- `kf6-kirigami`, `kdialog`, `breeze-icons`, and `qt6ct` are guaranteed
  by the base profile instead of arriving accidentally through optional theme
  work;
- OCR is owned by a shared Void OCR profile and is provisioned whenever either
  toolkit or screencapture is selected, eliminating the previous cross-profile
  dependency;
- the stale nonexistent `font-jetbrains-mono-nerd` Void mapping was replaced
  by the validated `nerd-fonts-ttf` provider;
- the redundant distro `python3-ytmusicapi` package was removed so the managed
  iNiR Python runtime remains the single owner;
- audio gained the official `alsa-pipewire` and `libdbusmenu-gtk3`
  providers, and toolkit now owns ImageMagick independently of screencapture;
- wallpaper dependency recovery and optional SDDM guidance no longer assume
  pacman/yay on Void.

The sweep also exposed Power Profiles as a visible shell capability without a
declared Void provider. The port now installs XBPS
`power-profiles-daemon`, maps `powerprofilesctl` for selective repair, and
activates `/etc/sv/power-profiles-daemon` through the existing
confirmed-elevation runit setup. Repository metadata on the live VM verified
`power-profiles-daemon-0.30_1`, the runit service, the
`org.freedesktop.UPower.PowerProfiles` D-Bus activation file, and its polkit
policy. A system-root XBPS dry-run also produced the expected transaction plan
for `power-profiles-daemon-0.30_1 install x86_64` from the configured Void
mirror.

The VM has no non-interactive sudo authorization and the package was not
already installed, so the closure does **not** claim a live root installation
or service activation. An attempted isolated-root full install was stopped
after the configured mirror delivered glibc at roughly tens of KiB/s; no
partial root was retained. Provider availability and package contents were
verified from the signed repository metadata instead. This is an explicit
operator-elevation validation limit, not a hidden code path.

The final PR7 checker was copied to the clean audit worktree and passed in full:

- every newly required XBPS provider resolved from the live configured repo;
- Power Profiles runit/D-Bus/polkit package contents passed;
- Quickshell/Qt ABI repair was a clean no-op;
- the VM remained on the non-systemd user-manager path;
- `make test-local`, PR7 static checks, shell syntax, JSON parsing, and
  `git diff --check` passed on the host.

`scripts/verify-docs.sh` still exits non-zero for two repository-wide baseline
issues: `customWidgets` is documented without a matching service IPC endpoint,
and the canonical English translation catalog is missing 296 runtime literals.
The verifier was run again at the PR7 base commit `152511db`; it reported the
same `customWidgets` finding and the same 296 missing canonical strings. The
closure sweep therefore introduces no new docs/i18n verifier regression.

Runtime QML validation loaded `ToolsView`, `SoftwareView`, and the Waffle
updates button on the VM's real Niri Wayland session with no missing-module,
type-unavailable, syntax, or component-load errors. A terminal-capture harness
also proved that the new UI operations route to:

```text
sudo xbps-install -Su
sudo xbps-remove -O
```

The only QML/runtime warnings observed were the already-known missing
AccountsService avatar and unavailable Power Profiles daemon on the pre-provider
VM image. The latter is exactly the capability closed by the new provider.

With this sweep, no open **code** finding remains from the Arch-to-Void parity
or technical-debt review. Remaining release evidence is intentionally
operational: live privileged Power Profiles activation and the external-disk
validation.

## 2.31 clean release-VM closure (2026-09-19)

Snow's runtime prerelease was merged through `7bf10565` and the Void closure
fixes were validated at `212bb3ae` (`VERSION=2.31.0`) on the disposable
`voidlinux-release-clean` VM. The release checkout was clean and tracked the
exact commit under test. Snow subsequently advanced prerelease through
`9574fa42`; those four commits touch README/screenshots, release tooling,
changelog/readmes, and the Arch dependency installer only. They were merged
after the VM runtime gate and passed the local suite without changing a Void
runtime surface.

### Fresh-install and disk-space evidence

The clean VM initially had a 20 GiB root disk. The first normal
`./setup install -y` reached the default font profile and failed while unpacking
`nerd-fonts-ttf` with `No space left on device`. XBPS rolled its package DB back
cleanly, but the failed unpack left a large unowned font tree; that tree was
removed after ownership/package-DB checks. The disposable VM disk was then
expanded to 30 GiB and `resize2fs` grew the root filesystem.

After the resize, the normal installer completed with `RC=0`. The code now
performs a preflight using `xbps-install -n` for only packages still missing,
summing installed bytes plus download bytes and adding 2 GiB of download/build
headroom. A later full idempotent install at the same 2.31 candidate passed
with roughly 7.2 GiB free, proving the preflight does not impose a fixed disk
size once dependencies are already satisfied.

### System services and reboot

The confirmed-elevation activation path was exercised for `dbus`, `elogind`,
`polkitd`, `turnstiled`, `power-profiles-daemon`, and `bluetoothd`.
NetworkManager replaced the pre-existing `dhcpcd` service under a timed rollback
guard; `nmcli` reported `connected`. After subsequent reboots all service links
persisted, NetworkManager restored the DHCP lease, and Turnstile owned the
per-user `runsvdir`.

Power Profiles is now live-validated rather than metadata-only:

- `/var/service/power-profiles-daemon` remained active after reboot;
- `powerprofilesctl list` returned the available profiles;
- `org.freedesktop.UPower.PowerProfiles` owned its system D-Bus name;
- the PR7 provider/package checks passed.

BlueZ likewise owned `org.bluez`; no physical Bluetooth adapter is exposed by
the VM, so radio operation remains a hardware limitation rather than a port
failure.

The final reboot changed boot ID from
`9e3f0aec-9317-481e-829a-7224cd58e874` to
`577312c8-b440-46be-9a83-f8df9d4190ce`. Kernel `6.18.52_1` booted normally,
NetworkManager returned `connected`, and the 30 GiB root remained healthy.

### Niri, Turnstile, Doctor, and interaction

The local tty1 login launched `niri --session` on seat0. Niri exposed
`Virtual-1` at 1280x800 and exactly one supervised iNiR Quickshell process.
Quickshell inherited the new live `NIRI_SOCKET`, `WAYLAND_DISPLAY`, runtime
directory, session bus, and iNiR virtualenv through Turnstile. The usable
systemd-user-manager predicate remained false.

`niri validate` passed. `inir doctor` completed with `Passed 27`, `Fixed 0`,
`Failed 0`. Left and right sidebar IPC toggles passed. PipeWire, WirePlumber,
PipeWire Pulse, and ydotool user services were active; `pactl info` reported
PipeWire 1.6.8 with default sink/source. A temporary Kitty window was focused
through Niri and a real Meta+Q sequence was injected through ydotool/uinput;
the focused window closed (`MODQ_FINAL=PASS`).

### Web Wallpaper and 2.31 runtime compatibility

The earlier Quickshell-host fallback for Web Wallpaper reproduced a real
QtWebEngine crash (`base::CommandLine cannot be properly initialized`) in the
clean VM. Void ships the Qt runner at `/usr/lib/qt6/bin/qml`, outside the
default PATH. The host was changed to pure Qt QML and the service now prefers
`qml6`/`qml`, falling back to that Void path instead of using `qs`.

The final host probe returned `RC=0`; a live local HTML Web Wallpaper remained
alive without module-load, renderer-termination, fatal, or crash errors and was
captured successfully with `grim`.

Snow 2.31 also added `inir logs --issues` and `inir logs -n`. The existing Void
runit adapter originally intercepted every `inir logs` invocation with
`sv status`, making those new options unreachable. The adapter now uses
`sv status` only for a bare `inir logs`; the option forms continue to
Quickshell. A local regression test and the live post-reboot command both pass.

The final `inir logs --issues` run returned `RC=0`. It reported only non-fatal
environment/UI warnings in this VM (the unused Hyprland signature and a missing
AccountsService avatar). A separate severe scan found no missing QML module,
`ReferenceError`, `TypeError`, stale Niri socket, failed component load, fatal,
crash, or segmentation pattern. One `SidebarProfileHeader` binding loop is
pre-existing and identical in upstream `main`; it is not introduced by the
Void port.

### Optional Super-tap and versioned checker sweep

`II_ENABLE_SUPER_DAEMON=1` was exercised through the real installer. It created
the Turnstile-managed `inir-super-overview` service, whose Python daemon ran
under the session supervisor. A normal reinstall without the variable removed
the managed service and helper and left no daemon process, confirming the
default-off cleanup path.

With `INIR_EXPECTED_BRANCH=fix/void-final-fatcheck` and
`INIR_EXPECTED_COMMIT=212bb3ae4cfd68fa17e256f8b15a07edc074f8d4`, every
versioned checker from PR3.2 through PR7 passed on the final boot. This includes
the PR6 isolated real XBPS install/query/remove transaction and the PR7
Quickshell/Qt ABI no-op/provider sweep. Host `make test-local`, shell syntax,
IPC registry freshness, iRiS style/default/performance tests, and
`git diff --check` also passed.

`scripts/verify-docs.sh` remains non-zero on the 2.31 tree. Running it in a
separate clean worktree at `212bb3ae` produced the same `customWidgets` IPC
finding and the same runtime-locale missing counts as the documented tree;
there is no new verifier regression from this closure documentation.

At this 2026-09-19 checkpoint, the remaining release gate was the
external-disk/hardware test. That test must
prepare the machine's own GPU driver/firmware/Mesa stack before iNiR: the port
installs the shell and userland capability providers, not hardware-specific
graphics drivers.

## Post-closure branch/checker hygiene (2026-09-19)

This is repository-maintenance evidence, not a new VM runtime validation.

After the release-VM closure, the fork was audited against its canonical
`prerelease` tip. The fork had 41 remote heads even though the completed Void
work was already integrated. Every port branch scheduled for deletion was
verified either as an ancestor of `prerelease` or, for four superseded
divergent historical tips, preserved first under
`archive/void-preintegration/*` tags. The remote branch set was then reduced
to `main`, `prerelease`, and the unrelated `fix/window-identity-rules`
branch. `main` was fast-forwarded to Snow's `9574fa42` baseline.

The branch cleanup exposed one stale release-checker contract:
`scripts/check-void-pr7.sh` still defaulted to the historical
`feat/void-port-closure` branch. A host regression test was added at the
public checker seam:

1. **RED:** run the current PR7 static checker from a checkout named
   `prerelease`; it failed with
   `FAIL: test prerelease = feat/void-port-closure`.
2. **GREEN:** change only the checker's default expected branch to
   `prerelease`; the same static checker completed with
   `All PR7 static checks passed`.

The `INIR_EXPECTED_BRANCH` override remains available for replaying historical
checkpoints. This maintenance step does not claim a fresh VM or external-disk
run; the runtime evidence above remains the release-VM source of truth.

The host documentation verifier was also rerun after this maintenance change and
compared with a clean checkout of the exact `5c13b6c4` baseline. Both runs
returned the same non-zero result: the pre-existing `customWidgets` service
documentation mismatch, 498 runtime literals missing from the canonical locale,
194 missing keys in most translated locales (19 in the canonical English
catalog), and generated CLI-registry drift. The filtered verifier outputs were
identical, so this branch/checker maintenance introduced no new documentation or
locale verifier regression.

## SDDM graphical-login parity closure (2026-09-19)

The post-closure review found that the validated VM flow still required a local
tty login followed by `niri --session`. That was a valid Niri session test but
not parity with the normal iNiR graphical-login experience.

The Void base profile now includes `sddm` and `xorg-minimal`. The installer
keeps SDDM disabled while dependencies, system setup, configs, theming, and
version tracking are being written. Only after the installation completion
screen does it offer to enable the packaged `/etc/sv/sddm` runit service. The
provider verifies the packaged Niri desktop entry and an enabled/running D-Bus
service first, treats an already-correct SDDM link idempotently, and refuses to
replace another enabled display manager such as LightDM.

Host TDD evidence for this slice:

1. **RED:** the new public distribution fixture failed because the Void base
   profile did not install the SDDM graphical-login provider.
2. **GREEN:** after adding the provider, the same fixture passed both initial
   enablement and reinstall/idempotence, and a competing LightDM fixture was
   preserved without creating an SDDM link.
3. The PR7 static checker now carries the same SDDM/base-package invariants.

The candidate was also overlaid onto the running `voidlinux-release-clean`
checkout without changing the remote branch. Inside Void itself:

- `scripts/check-void-pr7.sh` passed in static mode with the new SDDM/base
  package invariants;
- XBPS resolved `sddm-0.21.0_2` and `xorg-minimal-1.2_2` from the configured
  repository, and an `xbps-install -n sddm xorg-minimal` transaction plan
  resolved successfully;
- `make test-local` passed completely on Void after making the canonical-branch
  fixture tolerant of an already-existing local `prerelease` branch and
  replacing the fixture's accidental call to the host `sv` binary with a
  deterministic fake supervisor response.

The live root/reboot gate then passed on the same VM:

- `sddm-0.21.0_2` and `xorg-minimal-1.2_2` were installed through XBPS;
- the `ii-pixel` theme was installed and configured successfully;
- the first real provider run exposed one Void-specific false negative:
  unprivileged `sv status /var/service/dbus` returns `access denied` even while
  the system D-Bus daemon and `/run/dbus/system_bus_socket` are healthy. The
  provider predicate was corrected to accept the live system-bus socket as the
  primary runtime proof and retain `sv` as a fallback. A regression fixture now
  covers that exact access-denied case;
- `/var/service/sddm -> /etc/sv/sddm` was created by the provider and SDDM,
  Xorg, and `sddm-greeter-qt6` started with the `ii-pixel` theme;
- rerunning the real provider with the correct link already present returned
  `SDDM runit service already enabled` without prompting or elevation and left
  the link unchanged, closing the live idempotency gate;
- after a real reboot at 17:44 local VM time, runit restored SDDM automatically
  and the VM returned to the graphical greeter without `niri --session` being
  typed manually;
- a temporary validation-only SDDM autologin was used to exercise the complete
  display-manager path. SDDM launched `/usr/bin/niri --session` through
  `sddm-helper`; `loginctl` reported a local seat0 Wayland user session; exactly
  one Quickshell process started; `niri msg outputs` returned the active
  `Virtual-1` output; and Doctor finished `Passed 27 / Fixed 0 / Failed 0`;
- `inir logs --issues` contained only the already-known Hyprland-signature and
  missing AccountsService avatar warnings, with no new severe runtime error;
- the temporary autologin file was deleted. After recovering one VM-only ACPI
  shutdown/network hang with a libvirt hardware reset, the final clean boot at
  17:49 local VM time returned to the SDDM greeter with no Niri process before
  login, NetworkManager `connected/full`, and the D-Bus system socket healthy;
- `make test-local` passed again inside Void after the final provider changes.

This closes the VM graphical-login parity gate. `niri --session` remains the
documented local-TTY recovery/debug path, not the normal installed startup
flow. At this point the remaining release gate was the external-disk/hardware
test; the following section records that later hardware run.

## External-disk NetworkManager and runit lifecycle closure (2026-09-20)

The first real external-disk install used prerelease commit `6eec87b2` on a
Dell laptop with Intel Tiger Lake/Iris Xe graphics and AX201 Wi-Fi. The
graphical-login path passed on hardware: runit reported both `dbus` and
`sddm` running, and SDDM launched the packaged `/usr/bin/niri --session`
entry into the user session.

The hardware pass exposed a provider gap that the prepared VM image had hidden.
`NetworkManager-1.56.0_1` and `nmcli` were installed, but
`/var/service/NetworkManager` was absent while `dhcpcd` and standalone
`wpa_supplicant` were enabled and owned the working Wi-Fi connection.
`nmcli` therefore returned `NetworkManager is not running`, so the iNiR Wi-Fi
surface correctly appeared disabled even though the machine had Internet
access. Doctor still reported 27 passed / 0 failed because its non-systemd
service step did not verify the Void NetworkManager runtime.

The external-disk fix closes that path with TDD:

1. **RED:** the local distribution contract required an interactive migration
   from enabled `dhcpcd`/`wpa_supplicant` to NetworkManager, rollback after
   activation failure, idempotence after a successful handoff, and a Doctor
   failure when `nmcli` cannot talk to NetworkManager.
2. **GREEN:** `configure_void_networkmanager_service` now performs that
   confirmed migration only after the rest of installation has completed.
   Non-interactive installs leave networking unchanged. Failure to create the
   NetworkManager service link restores the previous runit links.
3. `setup doctor` now detects the distro before distro-specific checks, so the
   Void NetworkManager runtime check actually executes.

The same hardware session also exposed a non-systemd restart leak. Repeated
Quickshell restarts had left three `swayidle` processes and three
`keyboard_lock_state_daemon.py` processes reparented to PID 1. The existing
orphan cleanup only recognized systemd cgroup ownership. The runit path now
recognizes only iNiR-owned helpers by their installed runtime paths, and the
supervised session boot cleans those orphans before starting the next shell.
On the real external install, two consecutive runit restarts killed the old
helper PIDs and converged to exactly one Quickshell, one `swayidle`, and one
keyboard-lock daemon; `inir logs --issues` then reported no warnings or
errors for the new shell instance.

The same runit inspection showed the generated `inir-xembedsniproxy` service
passing a literal `$TURNSTILE_ENV_DIR` path to `chpst -e`, which produced a
repeating "unable to switch to directory" failure. The Turnstile service
renderer now expands the real environment-directory path and waits harmlessly
when no Xwayland `DISPLAY` is available instead of entering a crash loop. The
local distribution contract generates and inspects this service explicitly so
the escaped-variable regression cannot return.

After the operator accepted the NetworkManager migration and reconnected Wi-Fi,
the Codexify tunnel dropped before a live post-migration capture could be made.
With the external root mounted read-only from the host afterward, the persistent
runit configuration contained
`/etc/runit/runsvdir/default/NetworkManager -> /etc/sv/NetworkManager`, no
`dhcpcd`/`wpa_supplicant`/`wicd` link, and a root-owned mode-0600
NetworkManager connection profile for the reconnected Wi-Fi. At that checkpoint
this was persistent configuration evidence only; the final booted
`nmcli`/service check had not yet been captured. The final hardware-gate
section below records that later live reboot validation.

## Darkly settings and Foot theming post-closure validation (2026-09-20)

A subsequent real-Void report showed `darkly-settings6` opening with:

```text
Could not find plugin org.kde.kdecoration3.kcm/kcm_darklydecoration.so
```

The release-VM baseline reproduced the partial state exactly: the normal
`darkly6.so` KStyle and `/usr/bin/darkly-settings6` executable were installed,
but `kcm_darklydecoration.so` was absent. The original Void provider had
deliberately configured Darkly with `-DWITH_DECORATIONS=OFF`, so its previous
checks proved only style loading, not the settings application's KDecoration
module.

The corrected provider adds Void's `kf6-kdecoration-devel`, configures Darkly
v0.5.39 with `-DWITH_DECORATIONS=ON`, and treats both the style plugin and the
settings KCM as required health state. Doctor also recognizes an older
style-only installation as repairable instead of accepting the provider marker
alone.

Validation was performed on `voidlinux-release-clean` after first fetching the
current fork `prerelease` (`fd6725f2`) and confirming it already contained the
latest Snow baseline (`9574fa42`). The fix was overlaid into the VM checkout,
then exercised through the real iNiR dependency/provider path:

- XBPS installed `kf6-kdecoration-devel-6.7.5_1` from the configured Void
  repository;
- Darkly v0.5.39 rebuilt successfully with Qt6 and KDecoration enabled;
- installation produced `/usr/lib64/qt6/plugins/styles/darkly6.so`,
  `/usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.darkly.so`, and
  `/usr/lib64/qt6/plugins/org.kde.kdecoration3.kcm/kcm_darklydecoration.so`;
- `ldd` on the KCM reported no missing runtime dependency;
- an offscreen `darkly-settings6` smoke no longer emitted the missing-plugin
  error;
- the updated PR5.4 checker passed with `INIR_VERIFY_IDEMPOTENCY=true`, including
  an unchanged second provider install;
- `make test-local` completed with `All local distribution checks passed` in
  the same Void VM.

The screenshot that exposed the Darkly problem also showed Foot reading a
missing `~/.config/foot/colors.ini`. Repository inspection found a split
contract: the installer had already migrated Foot to `inir-colors.ini`, while
the shipped `foot.ini` and the live color generator still used the old
`colors.ini` path. The post-closure fix makes
`~/.config/foot/inir-colors.ini` the single managed path across the shipped
config, generator, installer and uninstall cleanup, with an explicit
distribution regression test to prevent the two names from diverging again.

The same release VM then installed `foot-1.28.0_1` from XBPS for a real parser
check. Running the updated terminal generator against an existing legacy
`include=~/.config/foot/colors.ini` configuration rewrote it to the canonical
`inir-colors.ini` include, generated the managed color file, and
`foot --check-config` returned success. This closes the user-visible startup
warning shown by the real-Void report rather than relying on a static pathname
assertion alone.

At this checkpoint there are no Snow commits waiting to be ported: a fresh
fetch resolved both `upstream/main` and `upstream/prerelease` to `9574fa42`, and
that commit is an ancestor of the fork's current Void `prerelease`.

The documentation verifier was rerun after the Void documentation sweep and
compared with a detached `origin/prerelease` baseline. Both returned the same
pre-existing non-zero findings: the `customWidgets` service-documentation
scanner mismatch, 498 runtime literals missing from the canonical catalog, 194
missing keys in most translated catalogs (19 in `es_AR`), and generated CLI
registry drift. The Void/Foot/Darkly documentation changes introduced no new
verifier finding.

## Final external-disk hardware gate (2026-09-20)

The external Void installation was booted again after the NetworkManager
migration, closing the one live capture that the earlier tunnel drop had left
open. The validation was performed on the real Dell laptop rather than the VM.

NetworkManager owned the live network after reboot:

```text
nmcli general state: connected
Wi-Fi device: connected
default route: through the active Wi-Fi device
```

The service ownership matched the persistent state observed offline:

```text
/var/service/NetworkManager -> /etc/sv/NetworkManager
/etc/runit/runsvdir/default/NetworkManager -> /etc/sv/NetworkManager
runsv NetworkManager
└─ NetworkManager -n
```

The standalone `dhcpcd`, `wpa_supplicant`, and `wicd` service links were absent.
The NetworkManager D-Bus owner was the same live daemon, and `inir doctor`
reported `Void NetworkManager provider running`. An unprivileged direct `sv
status /var/service/NetworkManager` still prints Void's expected `access denied`
warning for the supervise directory; process ancestry, D-Bus ownership, `nmcli`,
and the persistent runit links provide the operational proof.

The same boot also rechecked the other hardware-sensitive closure paths:

- SDDM launched `/usr/bin/niri --session` through `sddm-helper`;
- the supervised desktop had exactly one Quickshell process, one `swayidle`, and
  one `keyboard_lock_state_daemon.py`, confirming the runit orphan cleanup
  remains stable across a real reboot;
- `turnstiled` and the per-user runit services were active;
- Power Profiles exposed `performance`, `balanced`, and `power-saver` without a
  degraded driver;
- the physical Bluetooth controller was detected and powered by BlueZ with the
  expected audio profiles exposed. Pairing an external Bluetooth device was not
  required for the port release gate.

A Doctor invocation from the automation transport reported only `Niri not
detected (run inside Niri session)` because that non-graphical command context
did not inherit the graphical `NIRI_SOCKET`. The process/session inspection
above independently showed the real SDDM-launched Niri session running, so this
is not a desktop failure.

This closes the external-disk hardware gate for the iNiR 2.31.0 Void port.
