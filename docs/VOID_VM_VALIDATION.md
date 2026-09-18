# Void VM validation log

Validation record for the Void Linux port work performed on 2026-08-29,
2026-08-30 and 2026-08-31. This is an execution log, not a replacement for the port
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

With these limits recorded, PR1 through PR5.5 are considered fat-checked and
PR6 is the next implementation phase.
