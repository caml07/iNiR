#!/usr/bin/env bash
# Read-only PR3.2 checks for a live Void session.
set -u

failures=0
check() {
  if "$@"; then
    printf 'PASS: %s\n' "$*"
  else
    printf 'FAIL: %s\n' "$*" >&2
    failures=$((failures + 1))
  fi
}

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
service_root="${XDG_CONFIG_HOME:-$HOME/.config}/service"

check command -v loginctl
check command -v sv
check command -v dbus-update-activation-environment
check loginctl --help
printf 'INFO: can-suspend: '
loginctl can-suspend 2>&1 || true
printf 'INFO: can-hibernate: '
loginctl can-hibernate 2>&1 || true

if [[ -S "$runtime_dir/systemd/private" ]] &&
   timeout 3s systemctl --user show-environment >/dev/null 2>&1; then
  printf 'INFO: usable systemd user manager detected; non-systemd branch is not active\n'
else
  printf 'PASS: usable systemd user manager predicate is false\n'
  check test -x "$service_root/inir/run"
  check test -x "$service_root/inir-xembedsniproxy/run"
  check sv status "$service_root/inir"
  if command -v xembedsniproxy >/dev/null 2>&1; then
    check sv status "$service_root/inir-xembedsniproxy"
  else
    printf 'INFO: xembedsniproxy is not installed; service remains dormant\n'
  fi
fi

printf 'INFO: session=%s bus=%s runtime=%s\n' \
  "${XDG_SESSION_ID:-unknown}" \
  "${DBUS_SESSION_BUS_ADDRESS:-missing}" \
  "$runtime_dir"

if ((failures > 0)); then
  printf '%d PR3.2 check(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'All PR3.2 checks passed\n'
