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
  jq

  # Default wallpaper backend
  awww

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
  libspa-bluetooth
)

# Toolkit: input, desktop, backlight, bluetooth, OCR, KDE integration
VOID_TOOLKIT_PACKAGES=(
  curl
  cmake
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
  bluez
  blueman

  # KDE integration (kwriteconfig6)
  kf6-kconfig

  # Desktop applications delivered through maintained Flatpaks
  flatpak

  # OCR
  tesseract-ocr
  tesseract-ocr-eng
  tesseract-ocr-spa
  tesseract-ocr-rus
  tesseract-ocr-jpn
  tesseract-ocr-chi_sim
  tesseract-ocr-chi_tra

  # Cloudflare WARP upstream provider extraction
  binutils
  dbus-libs
  libpcap
  nss
  tpm2-tss

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
  curl
  unzip
  dejavu-fonts-ttf
  twemoji
  qt6ct
  kvantum
  breeze
  plasma-integration
  # adw-gtk3, capitaine-cursors, and whitesur-icon-theme are not in Void repos.
  noto-fonts-emoji
)

YDOTOOL_VERSION="1.0.4"
YDOTOOL_SOURCE_SHA256="ba075a43aa6ead51940e892ecffa4d0b8b40c241e4e2bc4bd9bd26b61fde23bd"
WARP_VERSION="2026.7.1377.0"
WARP_DEB_SHA256="95d33c2b4fc42f21c204981c51470a6a679d618fb0b78ee64bdd0db142230c55"
WARP_DEB_URL="https://pkg.cloudflareclient.com/pool/bookworm/main/c/cloudflare-warp/cloudflare-warp_${WARP_VERSION}_amd64.deb"
TESSDATA_FAST_COMMIT="87416418657359cb625c412a48b6e1d6d41c29bd"
ADW_GTK3_VERSION="6.5"
ADW_GTK3_SHA256="a81780fadfc432be0fc3d89c4ebb41aa28e4f032d42c36f9789c57dd10cfa41c"
ADW_GTK3_URL="https://github.com/lassekongo83/adw-gtk3/releases/download/v${ADW_GTK3_VERSION}/adw-gtk3v${ADW_GTK3_VERSION}.tar.xz"
WHITESUR_ICON_VERSION="2026-09-10"
WHITESUR_ICON_SHA256="406c9cd59705583f1754b0eaca96cc48bafda042b88ef143f16d8ae1820ecd95"
WHITESUR_ICON_URL="https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/tags/${WHITESUR_ICON_VERSION}.tar.gz"
CAPITAINE_VERSION="r5"
CAPITAINE_SHA256="60114cf857902a9907780bdcfa995d600618cf14b37f90776565c9de7e5add6c"
CAPITAINE_URL="https://github.com/sainnhe/capitaine-cursors/releases/download/${CAPITAINE_VERSION}/Linux.zip"

declare -A VOID_OCR_MODEL_SHA256=(
  [jpn_vert]="bf1e2640954691797e2dc14f38533e601b59ee37958698ae0f0b81dc6f09c71b"
  [chi_sim_vert]="20590de84725bab69cde93bd6e8ed360a13cc5421a7e7364ddeb93e9af53d6da"
  [chi_tra_vert]="1df02a4b210e5c217b783819538b63e9dfe6904e2b5e53b62664f1b9f7a989d0"
)

install_void_ocr_models() {
  local data_home tessdata_dir lang expected_sha target tmp url
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  tessdata_dir="${INIR_TESSDATA_DIR:-$data_home/inir/tessdata}"

  mkdir -p "$tessdata_dir" || {
    log_warning "Could not create OCR model directory: $tessdata_dir"
    return 1
  }

  for lang in "$@"; do
    expected_sha="${VOID_OCR_MODEL_SHA256[$lang]:-}"
    if [[ -z "$expected_sha" ]]; then
      log_warning "No verified Void OCR fallback is defined for $lang"
      return 1
    fi

    target="$tessdata_dir/$lang.traineddata"
    if [[ -s "$target" ]] \
        && printf '%s  %s\n' "$expected_sha" "$target" | sha256sum -c - >/dev/null 2>&1; then
      continue
    fi

    tmp="$target.part.$$"
    url="https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/${TESSDATA_FAST_COMMIT}/${lang}.traineddata"
    if ! curl -fsSL --max-time 90 -o "$tmp" "$url" \
        || ! printf '%s  %s\n' "$expected_sha" "$tmp" | sha256sum -c - >/dev/null 2>&1 \
        || ! mv -f "$tmp" "$target"; then
      rm -f "$tmp"
      log_warning "Could not provision verified OCR model: $lang"
      return 1
    fi
  done

  log_success "Void OCR language models are ready"
}

configure_void_tesseract_command() {
  local wrapper_dir wrapper_path wrapper

  if command -v tesseract >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v tesseract-ocr >/dev/null 2>&1; then
    log_warning "Void Tesseract binary is unavailable"
    return 1
  fi

  wrapper_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
  wrapper_path="$wrapper_dir/tesseract"
  wrapper="$(mktemp)" || return 1
  printf '%s\n' '#!/bin/sh' 'exec tesseract-ocr "$@"' > "$wrapper"
  if ! install -Dm755 "$wrapper" "$wrapper_path"; then
    rm -f "$wrapper"
    log_warning "Could not install the Void Tesseract command adapter"
    return 1
  fi
  rm -f "$wrapper"

  if [[ ":$PATH:" != *":${wrapper_dir}:"* ]]; then
    export PATH="$wrapper_dir:$PATH"
  fi
  command -v tesseract >/dev/null 2>&1 || return 1
}

install_void_adw_gtk3() {
  local data_home theme_dir marker_dir marker temp_dir archive
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  theme_dir="$data_home/themes"
  marker_dir="$data_home/inir/providers"
  marker="$marker_dir/adw-gtk3"

  if [[ -d "$theme_dir/adw-gtk3" && -d "$theme_dir/adw-gtk3-dark" ]] \
      && [[ "$(cat "$marker" 2>/dev/null || true)" == "${ADW_GTK3_VERSION}:${ADW_GTK3_SHA256}" ]]; then
    return 0
  fi

  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/adw-gtk3.tar.xz"
  if ! curl -fsSL --max-time 90 -o "$archive" "$ADW_GTK3_URL" \
      || ! printf '%s  %s\n' "$ADW_GTK3_SHA256" "$archive" | sha256sum -c - >/dev/null \
      || ! mkdir -p "$temp_dir/extract" \
      || ! tar -xJf "$archive" -C "$temp_dir/extract" \
      || [[ ! -d "$temp_dir/extract/adw-gtk3" || ! -d "$temp_dir/extract/adw-gtk3-dark" ]]; then
    rm -rf "$temp_dir"
    log_warning "Could not provision verified adw-gtk3 v${ADW_GTK3_VERSION}"
    return 1
  fi

  mkdir -p "$theme_dir" "$marker_dir"
  rm -rf "$theme_dir/adw-gtk3" "$theme_dir/adw-gtk3-dark"
  if ! cp -a "$temp_dir/extract/adw-gtk3" "$temp_dir/extract/adw-gtk3-dark" "$theme_dir/"; then
    rm -rf "$temp_dir"
    return 1
  fi
  printf '%s\n' "${ADW_GTK3_VERSION}:${ADW_GTK3_SHA256}" > "$marker"
  rm -rf "$temp_dir"
}

install_void_whitesur_icons() {
  local data_home icon_dir marker_dir marker temp_dir archive source_dir stage
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  icon_dir="$data_home/icons"
  marker_dir="$data_home/inir/providers"
  marker="$marker_dir/whitesur-icons"

  if [[ -d "$icon_dir/WhiteSur-dark" ]] \
      && [[ "$(cat "$marker" 2>/dev/null || true)" == "${WHITESUR_ICON_VERSION}:${WHITESUR_ICON_SHA256}" ]]; then
    return 0
  fi

  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/whitesur-icons.tar.gz"
  source_dir="$temp_dir/WhiteSur-icon-theme-${WHITESUR_ICON_VERSION}"
  stage="$temp_dir/stage"
  if ! curl -fsSL --max-time 90 -o "$archive" "$WHITESUR_ICON_URL" \
      || ! printf '%s  %s\n' "$WHITESUR_ICON_SHA256" "$archive" | sha256sum -c - >/dev/null \
      || ! tar -xzf "$archive" -C "$temp_dir" \
      || [[ ! -x "$source_dir/install.sh" ]] \
      || ! mkdir -p "$stage" \
      || ! (cd "$source_dir" && ./install.sh -d "$stage" -t default >/dev/null 2>&1) \
      || [[ ! -d "$stage/WhiteSur-dark" ]]; then
    rm -rf "$temp_dir"
    log_warning "Could not provision verified WhiteSur icons ${WHITESUR_ICON_VERSION}"
    return 1
  fi

  mkdir -p "$icon_dir" "$marker_dir"
  rm -rf "$icon_dir/WhiteSur" "$icon_dir/WhiteSur-dark" "$icon_dir/WhiteSur-light"
  if ! cp -a "$stage/WhiteSur" "$stage/WhiteSur-dark" "$stage/WhiteSur-light" "$icon_dir/"; then
    rm -rf "$temp_dir"
    return 1
  fi
  printf '%s\n' "${WHITESUR_ICON_VERSION}:${WHITESUR_ICON_SHA256}" > "$marker"
  rm -rf "$temp_dir"
}

install_void_capitaine_cursors() {
  local data_home icon_dir marker_dir marker temp_dir archive extract_dir dark light
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  icon_dir="$data_home/icons"
  marker_dir="$data_home/inir/providers"
  marker="$marker_dir/capitaine-cursors"
  dark="Capitaine Cursors"
  light="Capitaine Cursors - White"

  if [[ -d "$icon_dir/$dark" && -d "$icon_dir/$light" \
      && -L "$icon_dir/capitaine-cursors-light" ]] \
      && [[ "$(cat "$marker" 2>/dev/null || true)" == "${CAPITAINE_VERSION}:${CAPITAINE_SHA256}" ]]; then
    return 0
  fi

  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/capitaine.zip"
  extract_dir="$temp_dir/extract"
  if ! curl -fsSL --max-time 90 -o "$archive" "$CAPITAINE_URL" \
      || ! printf '%s  %s\n' "$CAPITAINE_SHA256" "$archive" | sha256sum -c - >/dev/null \
      || ! mkdir -p "$extract_dir" \
      || ! unzip -q "$archive" -d "$extract_dir" \
      || [[ ! -d "$extract_dir/$dark" || ! -d "$extract_dir/$light" ]]; then
    rm -rf "$temp_dir"
    log_warning "Could not provision verified Capitaine cursors ${CAPITAINE_VERSION}"
    return 1
  fi

  mkdir -p "$icon_dir" "$marker_dir"
  rm -rf "$icon_dir/$dark" "$icon_dir/$light" \
    "$icon_dir/capitaine-cursors" "$icon_dir/capitaine-cursors-light"
  if ! cp -a "$extract_dir/$dark" "$extract_dir/$light" "$icon_dir/" \
      || ! ln -s "$dark" "$icon_dir/capitaine-cursors" \
      || ! ln -s "$light" "$icon_dir/capitaine-cursors-light"; then
    rm -rf "$temp_dir"
    return 1
  fi
  printf '%s\n' "${CAPITAINE_VERSION}:${CAPITAINE_SHA256}" > "$marker"
  rm -rf "$temp_dir"
}

install_void_visual_providers() {
  install_void_adw_gtk3 || return 1
  install_void_whitesur_icons || return 1
  install_void_capitaine_cursors || return 1
  log_success "Void visual theme providers are ready"
}

install_void_missioncenter() {
  local app_id="io.missioncenter.MissionCenter"
  local wrapper_dir wrapper_path wrapper

  wrapper_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
  wrapper_path="$wrapper_dir/missioncenter"

  if command -v flatpak >/dev/null 2>&1 \
      && flatpak info --user "$app_id" >/dev/null 2>&1 \
      && [[ -x "$wrapper_path" ]] \
      && grep -Fq 'exec flatpak run io.missioncenter.MissionCenter "$@"' "$wrapper_path"; then
    log_success "Mission Center already installed"
    return 0
  fi

  if ! command -v flatpak >/dev/null 2>&1; then
    log_warning "Mission Center requires Flatpak on Void"
    return 1
  fi

  tui_info "Installing Mission Center from Flathub..."
  if ! flatpak remote-add --if-not-exists --user flathub \
      https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 \
      || ! flatpak install -y --user flathub "$app_id" >/dev/null 2>&1; then
    log_warning "Mission Center Flatpak installation failed"
    return 1
  fi

  wrapper="$(mktemp)" || return 1
  printf '%s\n' '#!/bin/sh' 'exec flatpak run io.missioncenter.MissionCenter "$@"' > "$wrapper"
  if ! install -Dm755 "$wrapper" "$wrapper_path"; then
    rm -f "$wrapper"
    log_warning "Could not install the Mission Center launcher"
    return 1
  fi
  rm -f "$wrapper"

  if ! command -v missioncenter >/dev/null 2>&1 && [[ ":$PATH:" != *":${wrapper_dir}:"* ]]; then
    log_warning "Mission Center installed, but $wrapper_dir is not on PATH"
    return 1
  fi

  log_success "Mission Center installed"
}

install_void_ydotool() {
  local installed_version
  installed_version="$(ydotoold --version 2>/dev/null || true)"
  if command -v ydotool >/dev/null 2>&1 && [[ "$installed_version" == "v${YDOTOOL_VERSION}" ]]; then
    log_success "ydotool v${YDOTOOL_VERSION} already installed"
    return 0
  fi

  tui_info "Installing ydotool v${YDOTOOL_VERSION} from verified upstream source..."
  local temp_dir archive source_dir build_dir
  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/ydotool.tar.gz"
  source_dir="$temp_dir/ydotool-${YDOTOOL_VERSION}"
  build_dir="$temp_dir/build"

  if ! curl -fsSL --max-time 90 -o "$archive" \
      "https://github.com/ReimuNotMoe/ydotool/archive/refs/tags/v${YDOTOOL_VERSION}.tar.gz" \
      || ! printf '%s  %s\n' "$YDOTOOL_SOURCE_SHA256" "$archive" | sha256sum -c - >/dev/null \
      || ! tar -xzf "$archive" -C "$temp_dir" \
      || ! (cd "$source_dir" && cmake -S . -B "$build_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        "-DCMAKE_C_FLAGS=-DVERSION=\\\"v${YDOTOOL_VERSION}\\\"" \
        && cmake --build "$build_dir" --target ydotool ydotoold -j"$(nproc)") \
      || ! pkg_sudo install -Dm755 "$build_dir/ydotool" "$build_dir/ydotoold" /usr/local/bin/; then
    rm -rf "$temp_dir"
    log_warning "ydotool v${YDOTOOL_VERSION} source installation failed"
    return 1
  fi

  rm -rf "$temp_dir"
  log_success "ydotool v${YDOTOOL_VERSION} installed"
}

install_void_warp() {
  local installed_version
  installed_version="$(warp-cli --version 2>/dev/null || true)"
  if [[ "$installed_version" == *"$WARP_VERSION"* ]]; then
    log_success "Cloudflare WARP v${WARP_VERSION} already installed"
    return 0
  fi

  tui_info "Installing Cloudflare WARP v${WARP_VERSION} from verified upstream package..."
  local temp_dir archive data_archive payload_dir warp_cli warp_svc tar_flags
  temp_dir="$(mktemp -d)" || return 1
  archive="$temp_dir/cloudflare-warp.deb"
  payload_dir="$temp_dir/payload"

  if ! curl -fsSL --max-time 90 -o "$archive" "$WARP_DEB_URL" \
      || ! printf '%s  %s\n' "$WARP_DEB_SHA256" "$archive" | sha256sum -c - >/dev/null \
      || ! data_archive="$(ar t "$archive" | grep '^data\.tar\.' | head -n1)" \
      || [[ -z "$data_archive" ]] \
      || ! mkdir -p "$payload_dir"; then
    rm -rf "$temp_dir"
    log_warning "Cloudflare WARP v${WARP_VERSION} installation failed"
    return 1
  fi
  local tar_flags=-x
  case "${data_archive##*.}" in
    gz) tar_flags=-xz ;;
    xz) tar_flags=-xJ ;;
    bz2) tar_flags=-xj ;;
  esac
  if ! ar p "$archive" "$data_archive" | tar $tar_flags -C "$payload_dir" \
      || ! warp_cli="$(find "$payload_dir" -type f -name warp-cli -print -quit)" \
      || ! warp_svc="$(find "$payload_dir" -type f -name warp-svc -print -quit)" \
      || [[ -z "$warp_cli" || -z "$warp_svc" ]] \
      || ! pkg_sudo install -Dm755 "$warp_cli" /usr/local/bin/warp-cli \
      || ! pkg_sudo install -Dm755 "$warp_svc" /usr/local/bin/warp-svc \
      || ! /usr/local/bin/warp-cli --version | grep -Fq "$WARP_VERSION"; then
    rm -rf "$temp_dir"
    log_warning "Cloudflare WARP v${WARP_VERSION} installation failed"
    return 1
  fi

  rm -rf "$temp_dir"
  log_success "Cloudflare WARP v${WARP_VERSION} installed"
}

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
    [tesseract]="tesseract-ocr"
    [blueman-manager]="blueman"
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
    [ocr-eng]="tesseract-ocr-eng"
    [ocr-spa]="tesseract-ocr-spa"
    [ocr-rus]="tesseract-ocr-rus"
    [ocr-jpn]="tesseract-ocr-jpn"
    [ocr-chi-sim]="tesseract-ocr-chi_sim"
    [ocr-chi-tra]="tesseract-ocr-chi_tra"
  )

  _miss_installflags=(-S)
  $ask || _miss_installflags+=(-y)

  _miss_pkgs=()
  _miss_cmds=()
  _need_ydotool=false
  _need_warp=false
  _need_missioncenter=false
  _need_tesseract_adapter=false
  _need_visual_providers=false
  _ocr_fallback_models=()
  read -r -a _miss_cmds <<<"$ONLY_MISSING_DEPS"
  for cmd in "${_miss_cmds[@]}"; do
    if [[ "$cmd" == ydotool || "$cmd" == ydotoold ]]; then
      _need_ydotool=true
      for _miss_pkg in curl cmake; do
        [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
      done
      continue
    fi
    if [[ "$cmd" == warp-cli || "$cmd" == warp-svc ]]; then
      _need_warp=true
      for _miss_pkg in binutils curl dbus-libs libpcap nss tpm2-tss; do
        [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
      done
      continue
    fi
    if [[ "$cmd" == missioncenter ]]; then
      _need_missioncenter=true
      [[ " ${_miss_pkgs[*]} " == *" flatpak "* ]] || _miss_pkgs+=(flatpak)
      continue
    fi
    if [[ "$cmd" == tesseract ]]; then
      _need_tesseract_adapter=true
    fi
    if [[ "$cmd" == adw-gtk3 || "$cmd" == whitesur-icon-theme || "$cmd" == capitaine-cursors ]]; then
      _need_visual_providers=true
      for _miss_pkg in curl unzip; do
        [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
      done
      continue
    fi
    case "$cmd" in
      ocr-jpn-vert)
        _ocr_fallback_models+=(jpn_vert)
        continue
        ;;
      ocr-chi-sim-vert)
        _ocr_fallback_models+=(chi_sim_vert)
        continue
        ;;
      ocr-chi-tra-vert)
        _ocr_fallback_models+=(chi_tra_vert)
        continue
        ;;
    esac
    _miss_pkg="${cmd_to_pkg[$cmd]:-$cmd}"
    [[ " ${_miss_pkgs[*]} " == *" ${_miss_pkg} "* ]] || _miss_pkgs+=("$_miss_pkg")
  done

  if [[ ${#_miss_pkgs[@]} -gt 0 ]]; then
    v pkg_sudo xbps-install "${_miss_installflags[@]}" "${_miss_pkgs[@]}"
  fi
  if $_need_ydotool; then
    install_void_ydotool || return 1
  fi
  if $_need_warp; then
    install_void_warp || return 1
  fi
  if $_need_missioncenter; then
    install_void_missioncenter || return 1
  fi
  if $_need_tesseract_adapter; then
    configure_void_tesseract_command || return 1
  fi
  if $_need_visual_providers; then
    install_void_visual_providers || return 1
  fi
  if [[ ${#_ocr_fallback_models[@]} -gt 0 ]]; then
    install_void_ocr_models "${_ocr_fallback_models[@]}" || return 1
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
  install_void_ydotool || return 1
  install_void_warp || return 1
  install_void_missioncenter || return 1
  configure_void_tesseract_command || return 1
  install_void_ocr_models jpn_vert chi_sim_vert chi_tra_vert || return 1
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
  install_void_visual_providers || return 1
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
