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
- Network: libvirt `default` network, VirtIO NIC, guest address observed as
  `192.168.122.141`.
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

All local tests pass (13 suites including new: rsync failure propagation,
supervisor reconciliation, Void profile, turnstile not used in fallback).
VM re-test pending.

## What remains

- Test iNiR/QuickShell from a local VM Niri session (not SSH).
- PR3.0: validate the implemented runsvdir fallback — installer, KDL injection,
  migrations, `scripts/inir` sv controls, idempotency.
- PR3.1: enable turnstile + elogind profile — confirmed elevation, D-Bus user
  service, envdir propagation, `manage_rundir=no`, remove runsvdir KDL block.
- PR3.2: non-systemd runtime adapters — UI/services zero systemctl calls.
- PR3.3: optional systemd adapters — classify and degrade/adapt Awww, GameMode,
  Warp, captures.
- Run shellcheck and `make test-local` before each PR.

`make test-local` is currently blocked by the pre-existing
`schema/wizard defaults: schema wallhaven tab` check. ShellCheck was not
available in the host environment. No upstream PR has been opened; the Void
port remains a fork progress branch until the complete VM integration gate
passes.
