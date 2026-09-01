# Install dependencies for iNiR on Void Linux
# This script is meant to be sourced, not run directly.

# shellcheck shell=bash

#####################################################################################
# Verify we're on Void
#####################################################################################
if ! command -v xbps-install >/dev/null 2>&1; then
  printf "${STY_RED}[$0]: xbps-install not found. This script is for Void Linux only.${STY_RST}\n"
  exit 1
fi

#####################################################################################
# Package definitions per profile (glibc + elogind primary profile)
# Based on docs/VOID.md "Dependencies (XBPS)" section
#####################################################################################

# Base: Niri, Quickshell, Qt6, session services, essential utilities
VOID_BASE_PACKAGES=(
  # Core compositor and shell
  niri
  quickshell
  fish-shell

  # Qt6 (required for Quickshell)
  qt6-base
  qt6-declarative
  qt6-svg
  qt6-wayland
  qt6-qt5compat
  qt6-multimedia
  qt6-imageformats
  qt6-virtualkeyboard

  # Session services (system services enabled separately in setup)
  elogind
  dbus
  polkit
  seatd
  turnstile

  # XDG Portals
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-wlr

  # Polkit agent
  polkit-gnome

  # Network
  NetworkManager

  # Wayland utilities
  wl-clipboard
  cliphist
  grim
  slurp

  # Idle/lock
  swayidle
  swaylock

  # Essential utilities
  gum
  dunst

  # UV (fast Python package manager, in Void repo)
  uv

  # Build/runtime deps for Python native extensions (pycairo, pygobject, opencv)
  rsync
  base-devel
  pkg-config
  cairo-devel
  python3-devel
  glib-devel
  gobject-introspection
  python3-gobject-devel
  libffi-devel
)

# Audio: optional audio stack
VOID_AUDIO_PACKAGES=(
  pipewire
  wireplumber
  playerctl
  pavucontrol
  easyeffects
  mpv
  mpv-mpris
  yt-dlp
  python3-ytmusicapi
  socat
  cava
)

# Toolkit: input, desktop, backlight, bluetooth, OCR, KDE integration
VOID_TOOLKIT_PACKAGES=(
  upower
  wtype
  python3-evdev
  python3-Pillow
  hyprpicker
  translate-shell
  fprintd

  # Backlight control
  brightnessctl
  ddcutil
  geoclue2

  # Bluetooth
  blueman

  # KDE integration (kwriteconfig6)
  kf6-kconfig

  # OCR
  tesseract-ocr
  tesseract-ocr-eng
  tesseract-ocr-spa

  # Note: ydotool is NOT in Void repos; compiling it is a compatibility profile (PR later)
)

# Screencapture: screenshot, recording, annotation
VOID_SCREENCAPTURE_PACKAGES=(
  swappy
  wf-recorder
   ImageMagick
  ffmpeg
)

# Fonts and theming
VOID_FONTS_PACKAGES=(
  dejavu-fonts-ttf
  twemoji
  qt6ct
  kvantum
  breeze
  plasma-integration
  # adw-gtk3, capitaine-cursors, and whitesur-icon-theme are not in Void repos.
  noto-fonts-emoji
)

#####################################################################################
# Optional: install only a specific list of missing deps (update path)
#####################################################################################
if [[ -n "${ONLY_MISSING_DEPS:-}" ]]; then
  tui_info "Installing missing dependencies only..."

  declare -A cmd_to_pkg=(
    [qs]="quickshell"
    [niri]="niri"
    [nmcli]="NetworkManager"
    [wpctl]="wireplumber"
    [jq]="jq"
    [rsync]="rsync"
    [curl]="curl"
    [git]="git"
    [python3]="python3"
    [wlsunset]="wlsunset"
    [dunstify]="dunst"
    [fish]="fish-shell"
    [magick]="ImageMagick"
    [swaylock]="swaylock"
    [swayidle]="swayidle"
    [grim]="grim"
    [mpv]="mpv"
    [cliphist]="cliphist"
    [wl-copy]="wl-clipboard"
    [wl-paste]="wl-clipboard"
    [pkg-config]="pkg-config"
    [cc]="gcc"
    [gcc]="gcc"
    [python3-devel]="python3-devel"
    [cairo-devel]="cairo-devel"
    [gobject-introspection]="gobject-introspection"
    [python3-gobject-devel]="python3-gobject-devel"
    [glib-devel]="glib-devel"
    [libffi-devel]="libffi-devel"
  )

  _miss_installflags=(-S)
  $ask || _miss_installflags+=(-y)

  _miss_pkgs=()
  _miss_cmds=()
  read -r -a _miss_cmds <<<"$ONLY_MISSING_DEPS"
  for cmd in "${_miss_cmds[@]}"; do
    _miss_pkg="${cmd_to_pkg[$cmd]:-$cmd}"
    [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
  done

  if [[ ${#_miss_pkgs[@]} -gt 0 ]]; then
    v pkg_sudo xbps-install "${_miss_installflags[@]}" "${_miss_pkgs[@]}"
  fi

  unset ONLY_MISSING_DEPS
  return 0
fi

#####################################################################################
# System update
#####################################################################################
case ${SKIP_SYSUPDATE:-false} in
  true) sleep 0;;
  *)
    if $ask; then
      v pkg_sudo xbps-install -Su
    else
      v pkg_sudo xbps-install -Su -y
    fi
    ;;
esac

#####################################################################################
# Install base packages
#####################################################################################
tui_info "Installing base packages..."

installflags=(-S)
$ask || installflags+=(-y)

# Filter packages based on flags
_install_base=("${VOID_BASE_PACKAGES[@]}")

v pkg_sudo xbps-install "${installflags[@]}" "${_install_base[@]}"

#####################################################################################
# Install audio packages
#####################################################################################
if ${INSTALL_AUDIO:-true}; then
  tui_info "Installing audio packages..."
  v pkg_sudo xbps-install "${installflags[@]}" "${VOID_AUDIO_PACKAGES[@]}"
fi

#####################################################################################
# Install toolkit packages
#####################################################################################
if ${INSTALL_TOOLKIT:-true}; then
  tui_info "Installing toolkit packages..."
  v pkg_sudo xbps-install "${installflags[@]}" "${VOID_TOOLKIT_PACKAGES[@]}"
fi

#####################################################################################
# Install screencapture packages
#####################################################################################
if ${INSTALL_SCREENCAPTURE:-true}; then
  tui_info "Installing screencapture packages..."
  v pkg_sudo xbps-install "${installflags[@]}" "${VOID_SCREENCAPTURE_PACKAGES[@]}"
fi

#####################################################################################
# Install fonts and theming packages
#####################################################################################
if ${INSTALL_FONTS:-true}; then
  tui_info "Installing fonts and theming packages..."
  v pkg_sudo xbps-install "${installflags[@]}" "${VOID_FONTS_PACKAGES[@]}"
fi

#####################################################################################
# Post-install: Check for Qt/Quickshell ABI mismatch
# Void rebuilds quickshell in lockstep with Qt updates, so this should self-heal.
# But we keep the check for completeness.
#####################################################################################
if command -v qs >/dev/null 2>&1; then
  qs_abi_output="$(timeout 5 env QT_QPA_PLATFORM=offscreen qs --version 2>&1 || true)"
  if echo "$qs_abi_output" | grep -qiE "built against Qt|Qt.*mismatch|incompatible Qt"; then
    log_warning "Qt/Quickshell ABI mismatch detected!"
    log_warning "Void rebuilds quickshell with Qt updates. Run 'sudo xbps-install -Sf quickshell' to force reinstall."
  fi
fi

log_success "Dependencies installed"
