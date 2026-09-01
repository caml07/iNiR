# Core functions for iNiR installer
# This is NOT a script for execution, but for loading functions

# shellcheck shell=bash

function try { "$@" || sleep 0; }

function v(){
  if ! ${quiet:-false}; then
    echo -e "  ${STY_FAINT}▶${STY_RST} ${STY_GREEN}$*${STY_RST}"
  fi
  local execute=true
  if $ask;then
    while true;do
      echo -e "${STY_BLUE}Execute? ${STY_RST}"
      echo "  y = Yes (default)"
      echo "  e = Exit now"
      echo "  s = Skip this command"
      echo "  yesforall = Yes and don't ask again"
      
      # Read with timeout (60s), default to Yes if timeout
      local p
      if read -t 60 -p "====> " p; then
        :
      else
        echo ""
        echo -e "${STY_YELLOW}Timeout reached, assuming Yes...${STY_RST}"
        p="y"
      fi
      
      case $p in
        [yY] | "") break ;;
        [eE]) echo -e "${STY_BLUE}Exiting...${STY_RST}" ;exit ;break ;;
        [sS]) echo -e "${STY_BLUE}Alright, skipping...${STY_RST}" ;execute=false ;break ;;
        "yesforall") ask=false ;break ;;
        *) echo -e "${STY_RED}Please enter [y/e/s/yesforall].${STY_RST}";;
      esac
    done
  fi
  if $execute;then x "$@";else
    if ! ${quiet:-false}; then
      echo -e "${STY_YELLOW}[$0]: Skipped \"$*\"${STY_RST}"
    fi
  fi
}

function x(){
  if "$@";then local cmdstatus=0;else local cmdstatus=1;fi
  
  # In non-interactive mode, fail immediately on error
  if ! $ask && [ $cmdstatus == 1 ]; then
     echo -e "${STY_RED}[$0]: Command \"${STY_GREEN}$*${STY_RED}\" failed in non-interactive mode. Exiting...${STY_RST}"
     exit 1
  fi

  while [ $cmdstatus == 1 ] ;do
    echo -e "${STY_RED}[$0]: Command \"${STY_GREEN}$*${STY_RED}\" has failed."
    echo -e "You may need to resolve the problem manually.${STY_RST}"
    echo "  r = Repeat this command (DEFAULT)"
    echo "  e = Exit now"
    echo "  i = Ignore this error and continue"
    
    local p
    if read -t 60 -p " [R/e/i]: " p; then
        :
    else
        echo ""
        echo -e "${STY_YELLOW}Timeout reached, exiting to be safe...${STY_RST}"
        p="e"
    fi

    case $p in
      [iI]) echo -e "${STY_BLUE}Alright, ignoring...${STY_RST}";cmdstatus=2;;
      [eE]) echo -e "${STY_BLUE}Exiting...${STY_RST}";break;;
      [rR] | "") echo -e "${STY_BLUE}Repeating...${STY_RST}"
         if "$@";then cmdstatus=0;else cmdstatus=1;fi
         ;;
      *) echo -e "${STY_BLUE}Repeating...${STY_RST}"
         if "$@";then cmdstatus=0;else cmdstatus=1;fi
         ;;
    esac
  done
  case $cmdstatus in
    0) ;;
    1) echo -e "${STY_RED}[$0]: Command \"${STY_GREEN}$*${STY_RED}\" failed. Exiting...${STY_RST}";exit 1;;
    2) echo -e "${STY_RED}[$0]: Command \"${STY_GREEN}$*${STY_RED}\" failed but ignored.${STY_RST}";;
  esac
}

function showfun(){
  if ! ${quiet:-false}; then
    echo -e "\n  ${STY_PURPLE}${STY_BOLD}❯${STY_RST} ${STY_BOLD}$1${STY_RST}"
  fi
}

function pause(){
  if [ ! "$ask" == "false" ];then
    printf "${STY_FAINT}${STY_SLANT}"
    local p; read -p "(Ctrl-C to abort, Enter to proceed)" p
    printf "${STY_RST}"
  fi
}

function prevent_sudo_or_root(){
  case $(whoami) in
    root) echo -e "${STY_RED}[$0]: Do NOT run as root. Aborting...${STY_RST}";exit 1;;
  esac
}

function command_exists() {
  command -v "$1" >/dev/null 2>&1
}

function log_info() {
  if ! ${quiet:-false}; then
    echo -e "  ${STY_BLUE}→${STY_RST} $1"
  fi
}

function log_success() {
  if ! ${quiet:-false}; then
    echo -e "  ${STY_GREEN}✓${STY_RST} $1"
  fi
}

function log_warning() {
  echo -e "  ${STY_YELLOW}⚠${STY_RST} $1"
}

function log_error() {
  echo -e "  ${STY_RED}✗${STY_RST} $1" >&2
}

function log_header() {
  if ! ${quiet:-false}; then
    echo -e "\n  ${STY_PURPLE}${STY_BOLD}$1${STY_RST}"
  fi
}

# File operations for 3.files.sh
cp_file(){
  # $1 = source, $2 = target
  local src="$1"
  local dst="$2"

  x mkdir -p "$(dirname "$dst")"

  # Avoid failing when source and destination are the same file
  # (e.g. when ~/.config/quickshell/inir points into the repo).
  if [[ -e "$dst" ]]; then
    local src_real dst_real
    src_real="$(realpath -se "$src" 2>/dev/null || echo "$src")"
    dst_real="$(realpath -se "$dst" 2>/dev/null || echo "$dst")"

    if [[ "$src_real" == "$dst_real" ]]; then
      echo -e "${STY_BLUE}[$0]: cp_file: '$src' and '$dst' are the same file, skipping copy.${STY_RST}"
    else
      x cp -f "$src" "$dst"
    fi
  else
    x cp -f "$src" "$dst"
  fi

  x mkdir -p "$(dirname "${INSTALLED_LISTFILE}")"
  realpath -se "$dst" >> "${INSTALLED_LISTFILE}"
}

# Never distributed. The payload is copied one directory at a time, so every
# pattern here is matched against a path relative to that directory — an entry
# like 'assets/images/mascot/*.png' would never fire while copying assets/.
# Bare names match at any depth; each one below is unique across the payload.
RUNTIME_EXCLUDES=(
  # Agent harness
  --exclude='AGENTS.md' --exclude='CLAUDE.md' --exclude='CODEX.md' --exclude='PI.md'
  --exclude='codemap.md' --exclude='.mcp.json' --exclude='opencode.json'
  --exclude='skills-lock.json'
  --exclude='.agents/' --exclude='.claude/' --exclude='.codex/' --exclude='.factory/'
  --exclude='.opencode/' --exclude='.codebase-memory/' --exclude='.impeccable/'
  --exclude='.pi-subagents/'
  # Maintainer and development tooling. Anchored with a leading slash so these
  # common names only ever match at the top of a payload directory, never a
  # future modules/…/tools/ that has every right to ship.
  --exclude='/agents/' --exclude='/tools/' --exclude='/l10n/'
  --exclude='/release.sh' --exclude='/wiki-sync.sh' --exclude='/verify-docs.sh'
  --exclude='/qml-check.fish' --exclude='/test-local-distribution.sh'
  --exclude='/test-mascot-pack-flow.sh'
  # Local art work files — the manifest always ships, the art does not
  --exclude='graphify-out/'
  --exclude='images/mascot/*.png' --exclude='images/mascot/*.gif'
  --exclude='images/mascot/frames/' --exclude='images/mascot/PROMPTS.md'
)

rsync_dir(){
  x mkdir -p "$2"
  local dest="$(realpath -se $2)"
  x mkdir -p "$(dirname ${INSTALLED_LISTFILE})"
  local _rsync_tmp
  _rsync_tmp="$(mktemp)"
  rsync -a "${RUNTIME_EXCLUDES[@]}" --out-format='%i %n' "$1"/ "$2"/ > "$_rsync_tmp" || {
    local _rsync_rc=$?
    rm -f "$_rsync_tmp"
    return $_rsync_rc
  }
  awk -v d="$dest" '$1 ~ /^>/{ sub(/^[^ ]+ /,""); printf d "/" $0 "\n" }' "$_rsync_tmp" >> "${INSTALLED_LISTFILE}"
  rm -f "$_rsync_tmp"
}

rsync_dir__sync(){
  x mkdir -p "$2"
  local dest="$(realpath -se $2)"
  x mkdir -p "$(dirname ${INSTALLED_LISTFILE})"
  local _rsync_tmp
  _rsync_tmp="$(mktemp)"
  rsync -a --delete "${RUNTIME_EXCLUDES[@]}" --out-format='%i %n' "$1"/ "$2"/ > "$_rsync_tmp" || {
    local _rsync_rc=$?
    rm -f "$_rsync_tmp"
    return $_rsync_rc
  }
  awk -v d="$dest" '$1 ~ /^>/{ sub(/^[^ ]+ /,""); printf d "/" $0 "\n" }' "$_rsync_tmp" >> "${INSTALLED_LISTFILE}"
  rm -f "$_rsync_tmp"
}

function install_file(){
  local s="$1"
  local t="$2"
  if [ -f "$t" ] && ! ${quiet:-false}; then
    echo -e "${STY_YELLOW}[$0]: \"$t\" will be overwritten.${STY_RST}"
  fi
  v cp_file "$s" "$t"
}

function install_file__auto_backup(){
  local s="$1"
  local t="$2"
  if [ -f "$t" ];then
    if ! ${quiet:-false}; then
      echo -e "${STY_YELLOW}[$0]: \"$t\" exists.${STY_RST}"
    fi
    if ${INSTALL_FIRSTRUN};then
      if ! ${quiet:-false}; then
        echo -e "${STY_BLUE}[$0]: First run - backing up.${STY_RST}"
      fi
      v mv "$t" "$t.old"
      v cp_file "$s" "$t"
    else
      if ! ${quiet:-false}; then
        echo -e "${STY_BLUE}[$0]: Not first run - preserving existing file${STY_RST}"
      fi
    fi
  else
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}[$0]: \"$t\" does not exist.${STY_RST}"
    fi
    v cp_file "$s" "$t"
  fi
}

function install_dir(){
  local s="$1"
  local t="$2"
  if [ -d "$t" ] && ! ${quiet:-false}; then
    echo -e "${STY_YELLOW}[$0]: \"$t\" will be merged.${STY_RST}"
  fi
  rsync_dir "$s" "$t"
}

function install_dir__sync(){
  local s="$1"
  local t="$2"
  if [ -d "$t" ] && ! ${quiet:-false}; then
    echo -e "${STY_YELLOW}[$0]: \"$t\" will be synced (--delete).${STY_RST}"
  fi
  rsync_dir__sync "$s" "$t"
}

function install_dir__skip_existed(){
  local s="$1"
  local t="$2"
  if [ -d "$t" ];then
    if ! ${quiet:-false}; then
      echo -e "${STY_BLUE}[$0]: \"$t\" exists, skipping.${STY_RST}"
    fi
  else
    if ! ${quiet:-false}; then
      echo -e "${STY_YELLOW}[$0]: \"$t\" does not exist.${STY_RST}"
    fi
    v rsync_dir "$s" "$t"
  fi
}

function ensure_launcher_path_in_shells(){
  local launcher_dir="$1"
  [[ -n "$launcher_dir" ]] || return 0

  local marker="# iNiR launcher PATH"
  local end_marker="# end iNiR launcher PATH"
  local sh_block="
${marker}
case \":\$PATH:\" in
  *:\"${launcher_dir}\":*) ;;
  *) export PATH=\"${launcher_dir}:\$PATH\" ;;
esac
${end_marker}
"
  local shell_file=""

  for shell_file in "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc" \
                    "$HOME/.zprofile" "$HOME/.zshrc"; do
    touch "$shell_file"
    sed -i "/${marker}/,/${end_marker}/d" "$shell_file" 2>/dev/null || true
    printf '%s\n' "$sh_block" >> "$shell_file"
  done

  local fish_conf_dir="${XDG_CONFIG_HOME}/fish/conf.d"
  mkdir -p "$fish_conf_dir"
  cat > "${fish_conf_dir}/inir-path.fish" << EOF
if not contains -- "${launcher_dir}" \$PATH
    set -gx PATH "${launcher_dir}" \$PATH
end
EOF

  if has_usable_systemd_user_manager; then
    local manager_path
    manager_path="$(systemctl --user show-environment 2>/dev/null \
      | sed -n 's/^PATH=//p' | head -1)"
    if [[ -n "$manager_path" ]]; then
      case ":${manager_path}:" in
        *":${launcher_dir}:"*) ;;
        *) systemctl --user set-environment "PATH=${launcher_dir}:${manager_path}" 2>/dev/null || true ;;
      esac
    fi
  fi
}

function niri_can_resolve_launcher_dir(){
  local launcher_dir="$1"
  local niri_pid=""
  local niri_path=""

  command -v pgrep >/dev/null 2>&1 || return 1
  niri_pid="$(pgrep -xo niri 2>/dev/null || true)"
  [[ -n "$niri_pid" ]] || return 0
  [[ -r "/proc/${niri_pid}/environ" ]] || return 1

  niri_path="$(tr '\0' '\n' < "/proc/${niri_pid}/environ" \
    | sed -n 's/^PATH=//p' | head -1)"
  [[ -n "$niri_path" ]] || return 1

  case ":${niri_path}:" in
    *":${launcher_dir}:"*) return 0 ;;
    *) return 1 ;;
  esac
}

function backup_clashing_targets(){
  local source_dir="$1"
  local target_dir="$2"
  local backup_dir="$3"
  local -a ignored_list=("${@:4}")

  local clash_list=()
  local source_list=($(ls -A "$source_dir" 2>/dev/null))
  local target_list=($(ls -A "$target_dir" 2>/dev/null))
  local -A target_map
  for i in "${target_list[@]}"; do
    target_map["$i"]=1
  done
  for i in "${source_list[@]}"; do
    if [[ -n "${target_map[$i]}" ]]; then
      clash_list+=("$i")
    fi
  done

  local args_includes=()
  for i in "${clash_list[@]}"; do
    if [[ -d "$target_dir/$i" ]]; then
      args_includes+=(--include="/$i/")
      args_includes+=(--include="/$i/**")
    else
      args_includes+=(--include="/$i")
    fi
  done
  args_includes+=(--exclude='*')

  if [ ${#clash_list[@]} -gt 0 ]; then
    x mkdir -p $backup_dir
    x rsync -av --progress "${args_includes[@]}" "$target_dir/" "$backup_dir/"
  fi
}

function dedup_and_sort_listfile(){
  if ! test -f "$1"; then
    echo "File not found: $1" >&2; return 2
  else
    temp="$(mktemp)"
    sort -u -- "$1" > "$temp"
    mv -f -- "$temp" "$2"
  fi
}

# Intelligent privilege escalation: sudo for terminal, pkexec for graphical/IPC mode
# Usage: elevate command [args...]
# Returns: exit code of the elevated command
function elevate() {
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    # Interactive terminal available — use sudo
    sudo "$@"
  elif command -v pkexec &>/dev/null; then
    # No terminal but pkexec available — use graphical auth dialog
    pkexec "$@"
  else
    # Fallback to sudo (will likely fail without terminal, but try anyway)
    sudo "$@"
  fi
}

# Check if we can elevate privileges (either via terminal sudo or pkexec)
# Returns: 0 if elevation is possible, 1 otherwise
function can_elevate() {
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    return 0  # Terminal available for sudo
  elif command -v pkexec &>/dev/null && [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
    return 0  # Graphical session with pkexec available
  else
    return 1  # No way to elevate
  fi
}

inir_user_service_is_masked() {
  local service_path="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/inir.service"
  local state

  if [[ -L "$service_path" ]] && [[ "$(readlink -f "$service_path" 2>/dev/null || true)" == "/dev/null" ]]; then
    return 0
  fi

  has_usable_systemd_user_manager || return 1
  state="$(systemctl --user is-enabled inir.service 2>/dev/null || true)"
  [[ "$state" == "masked" || "$state" == "masked-runtime" ]]
}

repair_legacy_quickshell_malloc_environment() {
  local conf="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/quickshell-mem.conf"
  local repaired=0
  local legacy_owned=false

  INIR_LEGACY_MALLOC_ENV_REPAIRED=0

  if [[ -f "$conf" ]] && grep -Eq \
      '^[[:space:]]*MALLOC_ARENA_MAX=2[[:space:]]*$|^[[:space:]]*MALLOC_MMAP_THRESHOLD_=131072[[:space:]]*$' \
      "$conf" 2>/dev/null; then
    legacy_owned=true
    local tmp="${conf}.inir-repair.$$"

    if ! grep -Ev \
        '^[[:space:]]*MALLOC_ARENA_MAX=2[[:space:]]*$|^[[:space:]]*MALLOC_MMAP_THRESHOLD_=131072[[:space:]]*$|^# Quickshell/iNiR memory optimization[[:space:]]*$|^# Prevents glibc malloc arenas from retaining freed wallpaper textures\.[[:space:]]*$|^# See: scripts/quickshell-env\.sh for details\.[[:space:]]*$' \
        "$conf" > "$tmp"; then
      rm -f "$tmp"
      return 1
    fi

    if grep -q '[^[:space:]]' "$tmp" 2>/dev/null; then
      mv "$tmp" "$conf"
    else
      rm -f "$tmp" "$conf"
    fi
    repaired=1
  fi

  if $legacy_owned; then
    [[ "${MALLOC_ARENA_MAX:-}" == "2" ]] && unset MALLOC_ARENA_MAX
    [[ "${MALLOC_MMAP_THRESHOLD_:-}" == "131072" ]] && unset MALLOC_MMAP_THRESHOLD_

    if has_usable_systemd_user_manager; then
      local manager_env=""
      manager_env="$(systemctl --user show-environment 2>/dev/null || true)"
      if grep -qx 'MALLOC_ARENA_MAX=2' <<< "$manager_env"; then
        systemctl --user unset-environment MALLOC_ARENA_MAX >/dev/null 2>&1 || true
      fi
      if grep -qx 'MALLOC_MMAP_THRESHOLD_=131072' <<< "$manager_env"; then
        systemctl --user unset-environment MALLOC_MMAP_THRESHOLD_ >/dev/null 2>&1 || true
      fi
    fi
  fi

  INIR_LEGACY_MALLOC_ENV_REPAIRED=$repaired
  return 0
}

# Check if a usable systemd user manager is available.
# Returns 0 if the socket exists AND systemctl --user responds within 3s.
# This is the predicate from ADR-0002, gating all systemd-sensitive paths.
# Does NOT check distro name or mere presence of systemctl binary.
function has_usable_systemd_user_manager() {
  [[ -S "${XDG_RUNTIME_DIR:-}/systemd/private" ]] &&
    timeout 3s systemctl --user show-environment >/dev/null 2>&1
}

has_active_turnstile() {
  local service_path="${INIR_TURNSTILED_SERVICE_PATH:-/var/service/turnstiled}"
  [[ -e "$service_path" ]] || return 1
  if command -v sv >/dev/null 2>&1 && sv status "$service_path" 2>/dev/null | grep -q '^run:'; then
    return 0
  fi
  pgrep -x turnstiled >/dev/null 2>&1
}

configure_turnstile_user_services() {
  local service_root="${XDG_CONFIG_HOME:-$HOME/.config}/service"
  local examples="/usr/share/examples/turnstile"
  local target

  mkdir -p "$service_root/dbus" "$service_root/turnstile-ready"
  for target in run check; do
    [[ -f "$examples/dbus.$target" ]] || continue
    install -m 755 "$examples/dbus.$target" "$service_root/dbus/$target"
  done

  local ready_conf="$service_root/turnstile-ready/conf"
  touch "$ready_conf"
  if ! grep -Eq '^core_services=.*dbus' "$ready_conf"; then
    if grep -q '^core_services=' "$ready_conf"; then
      sed -i -E 's/^core_services="([^"]*)"/core_services="\1 dbus"/' "$ready_conf"
    else
      printf 'core_services="dbus"\n' >> "$ready_conf"
    fi
  fi
}

inir_supervisor() {
  if has_usable_systemd_user_manager; then
    printf 'systemd\n'
  elif has_active_turnstile; then
    printf 'turnstile\n'
  else
    printf 'runsvdir\n'
  fi
}

# Reconcile supervisor state for iNiR (shared by install and update).
# Creates/updates runit service, renders startup KDL block.
# Args: (none - uses XDG_CONFIG_HOME, XDG_BIN_HOME)
# Returns: 0 on success, prints the selected supervisor on stdout.
reconcile_inir_supervisor() {
  local launcher_path="${XDG_BIN_HOME:-$HOME/.local/bin}/inir"
  local runit_service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/service/inir"
  local runit_run_file="${runit_service_dir}/run"
  local startup_target="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/50-startup.kdl"
  [[ -f "$startup_target" ]] || startup_target="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"

  local supervisor
  supervisor="$(inir_supervisor)"

  # Ensure runit service exists (used by both runsvdir and turnstile tiers).
  if [[ -x "$launcher_path" ]]; then
    mkdir -p "$runit_service_dir"
    local launcher_quoted
    launcher_quoted="$(printf '%s' "$launcher_path" | sed "s/'/'\\\\''/g")"
    if [[ "$supervisor" == turnstile ]]; then
      printf "#!/bin/sh\nexec chpst -e \"\$TURNSTILE_ENV_DIR\" '%s' run --session\n" "$launcher_quoted" > "$runit_run_file"
    else
      printf "#!/bin/sh\nexec '%s' run --session\n" "$launcher_quoted" > "$runit_run_file"
    fi
    chmod +x "$runit_run_file"
  fi
  [[ "$supervisor" == turnstile ]] && configure_turnstile_user_services

  update_inir_startup_supervisor() {
    local file="$1"
    local supervisor="$2"
    python3 - "$file" "$supervisor" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
supervisor = sys.argv[2]
text = path.read_text()

text = re.sub(
    r'(?ms)^[ \t]*// BEGIN inir-(?:systemd-environment|runsvdir-fallback)\n'
    r'.*?^[ \t]*// END inir-(?:systemd-environment|runsvdir-fallback)\n?',
    '',
    text,
)
text = re.sub(r'(?m)^[ \t]*spawn-sh-at-startup.*runsvdir.*\n?', '', text)
text = re.sub(
    r'(?m)^[ \t]*spawn-at-startup "bash" "-c" '
    r'"systemctl --user import-environment XDG_MENU_PREFIX && kbuildsycoca6"\n?',
    '',
    text,
)
# Remove all supervisor comment variants.
text = re.sub(
    r'(?m)^[ \t]*// iNiR is managed by the (?:user systemd service \(inir\.service\)|runit user service \(service/inir\)|turnstile user service \(service/inir\))\.\n'
    r'^[ \t]*// Do not add a compositor startup entry here or you\'ll get two shells\.\n?',
    '',
    text,
)

if supervisor == "systemd":
    supervisor_comment = '''// iNiR is managed by the user systemd service (inir.service).
// Do not add a compositor startup entry here or you'll get two shells.'''
    block = '''// BEGIN inir-systemd-environment
// Export XDG_MENU_PREFIX into the systemd user session and rebuild the
// sycoca database so KDE/Qt apps see the correct .desktop entries.
spawn-at-startup "bash" "-c" "systemctl --user import-environment XDG_MENU_PREFIX && kbuildsycoca6"
// END inir-systemd-environment'''
elif supervisor == "runsvdir":
    supervisor_comment = '''// iNiR is managed by the runit user service (service/inir).
// Do not add a compositor startup entry here or you'll get two shells.'''
    block = '''// BEGIN inir-runsvdir-fallback
// iNiR shell supervisor (runsvdir fallback for non-systemd).
// Do not add a compositor startup entry here or you'll get two shells.
spawn-sh-at-startup "exec runsvdir ~/.config/service"
// END inir-runsvdir-fallback'''
else:
    supervisor_comment = '''// iNiR is managed by the turnstile user service (service/inir).
// Do not add a compositor startup entry here or you'll get two shells.'''
    block = ''

suffix = f"\n\n{supervisor_comment}\n"
if block:
    suffix += f"\n{block}\n"
path.write_text(text.rstrip() + suffix)
PY
  }

  [[ -f "$startup_target" ]] && update_inir_startup_supervisor "$startup_target" "$supervisor"
  printf '%s\n' "$supervisor"
  return 0
}
