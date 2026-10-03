# Autostart and Session

How iNiR starts, how apps autostart, and how sessions end.

## Shell startup

iNiR is started by the session supervisor selected for the current machine. On
a normal Arch/systemd-user session that is `inir.service`; on the supported
Void runit path it is a Turnstile-managed user service or the guarded runsvdir
fallback. The goal is the same in every tier: exactly one shell, tied to the
Niri session, with the compositor's authoritative environment and crash
recovery owned by a supervisor.

On the systemd tier, the service connects to the compositor via a wants link:

```
~/.config/systemd/user/niri.service.wants/inir.service
```

When Niri starts, `inir.service` waits for the `Type=notify` compositor service to report ready, so it inherits Niri's authoritative `DISPLAY`, `WAYLAND_DISPLAY` and `NIRI_SOCKET`. When Niri stops, iNiR stops. Manage the link with:

```bash
inir service enable     # create wants link
inir service disable    # remove it
inir service status     # check state
```

On Void without a usable systemd user manager, setup renders
`~/.config/service/inir/run`. Turnstile provides the user-session lifecycle and
environment directory when available; otherwise Niri owns a single runsvdir
fallback. Do not add a second handwritten `spawn-at-startup` shell entry on top
of that. `inir restart`, `inir logs`, `inir doctor` and the other normal CLI
operations select the active supervisor for you.

For the full boot sequence, see [Runtime and Boot Pipeline](RUNTIME.md).

## App autostart

There are two layers of autostart in a typical iNiR setup:

### Compositor level (spawn-at-startup)

These are defined in `~/.config/niri/config.d/50-startup.kdl` and managed by the compositor:

- `wl-paste --no-newline --type text --watch ~/.config/quickshell/inir/scripts/clipboard-store.py` (clipboard text history; avoids synthetic trailing newlines and strips browser markup)
- `wl-paste --type image --watch ~/.config/quickshell/inir/scripts/clipboard-image-store.sh` (clipboard image history; internal preview frames are filtered)
- the detected external polkit agent (GNOME on the supported Void profile;
  KDE/MATE/LXQt/lxpolkit are accepted where installed)
- `kbuildsycoca6` (KDE desktop entry cache)

These run before iNiR starts and are independent of the shell.

### Shell level (Autostart service)

iNiR has its own autostart manager that handles:

- **Desktop entries**: standard `.desktop` files in `~/.config/autostart/`
- **Custom commands**: user-defined commands configured through Settings
- **Systemd units**: user-level systemd services when that user manager exists

Manage autostart entries from Settings > System > Autostart (there is no CLI for this, it is managed through the settings UI, backed by `services/Autostart.qml`).

## Lock screen

The lock screen uses Wayland's session lock protocol (WlSessionLock). This is a security protocol: when active, all other surfaces are hidden and only the lock surface is visible. There's no way to bypass it by switching workspaces or killing processes.

### Authentication

- **Password**: PAM authentication (same as your login password)
- **Fingerprint**: supported if your system has fprintd configured

### Fallback

If the QML lock surface fails to render within 2 seconds, iNiR falls back to swaylock or hyprlock (whichever is installed). This prevents the session from being locked with no visible unlock UI.

### IPC

```bash
inir lock activate     # lock the session
inir lock deactivate   # unlock (requires auth)
inir lock status       # check lock state
```

### Config

Lock settings are in Settings > System > Lock:
- Blur background (on/off)
- Auto-lock on startup
- Unlock GNOME Keyring after authentication

## Session screen

The session screen provides logout, reboot, shutdown, and suspend actions. Access it from:
- Keybind (configurable)
- Power button in the bar/taskbar
- IPC: `inir session open`

Before executing an action, the session screen checks for running package managers and active downloads. If found, it warns you before proceeding.

## Polkit agent

iNiR includes a PolicyKit authentication agent. When a privileged operation
needs authorization (installing a package, mounting a disk), a dialog appears
asking for your password.

On the supported Void Turnstile tier, the shell deliberately starts with
`QS_DISABLE_POLKIT=1` and Niri owns the graphical external agent instead.
Turnstile's per-user service manager belongs to an elogind background session,
so a Quickshell listener registered from that service is not the same subject as
the seat0 graphical session and polkit rejects it. The normal Void dependency
profile installs `polkit-gnome`, and setup writes the detected external agent
into Niri startup. The non-Turnstile tiers keep the shell agent available; its
process detector also recognizes GNOME, KDE, MATE, LXQt and lxpolkit agents.

## Idle management

Idle timeouts are handled by swayidle, configured through Settings or IPC:

- **Screen off**: turn off monitors after inactivity (default: 5 minutes)
- **Lock**: lock the session after inactivity (default: 10 minutes)
- **Suspend**: suspend the system after inactivity (default: off)

Idle timeouts are configured in Settings (backed by `services/Idle.qml`); there is no `inir idle` CLI command.

Fullscreen video players and presentations automatically inhibit idle via the idle-inhibit Wayland protocol.
