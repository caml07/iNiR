# Void VM validation log

Validation record for the Void Linux port work performed on 2026-08-29. This
is an execution log, not a replacement for the port specification in
`docs/VOID.md`.

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

## What remains

- Test iNiR/QuickShell again after the active-output fix.
- Enable and test the Void session supervisor tiers, starting with the
  `turnstile` per-user service and then the `runsvdir` fallback.
- Implement the Void core changes described in `docs/VOID.md`.
- Test the installer on a fresh Void snapshot.
- Run shellcheck and `make test-local` before opening the implementation PR.

The VM work did not modify repository source code. The only repository-local
working-tree change carried throughout the VM session was the existing local
edit to `AGENTS.md`.
