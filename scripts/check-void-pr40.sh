#!/usr/bin/env bash
# Read-only PR4.0 checks for a live Void session (NetworkManager provider).
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

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
expected_branch="${INIR_EXPECTED_BRANCH:-feat/void-networkmanager-provider}"
expected_commit="${INIR_EXPECTED_COMMIT:-}"

actual_branch="$(git -C "$repo_root" branch --show-current 2>/dev/null || true)"
actual_commit="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || true)"
check test "$actual_branch" = "$expected_branch"
if [[ -n "$expected_commit" ]]; then
  check test "$actual_commit" = "$expected_commit"
else
  printf 'INFO: commit=%s (not pinned; set INIR_EXPECTED_COMMIT to pin it)\n' "$actual_commit"
fi
check test -z "$(git -C "$repo_root" status --porcelain 2>/dev/null)"

# Provider is installed via the base profile.
check xbps-query -p pkgver NetworkManager
check command -v nmcli

# Installer provisions the provider and guards activation.
setups="$repo_root/sdata/subcmd-install/2.setups.sh"
for needle in 'ln -sfn /etc/sv/NetworkManager /var/service/NetworkManager' \
  'dhcpcd' 'wpa_supplicant' 'skipping NetworkManager activation' \
  'video,i2c,input,network'; do
  if grep -Fq "$needle" "$setups"; then
    printf 'PASS: setup contains: %s\n' "$needle"
  else
    printf 'FAIL: setup missing: %s\n' "$needle" >&2
    failures=$((failures + 1))
  fi
done

# Competing managers must not be enabled alongside NetworkManager.
for competitor in dhcpcd wpa_supplicant wicd; do
  if [[ -L "/var/service/$competitor" ]]; then
    printf 'FAIL: competing service enabled: %s\n' "$competitor" >&2
    failures=$((failures + 1))
  else
    printf 'PASS: no competing service: %s\n' "$competitor"
  fi
done

# Activation: runit symlink + live service.
check test -L /var/service/NetworkManager
check sudo sv status NetworkManager >/dev/null 2>&1
check sudo sv status dbus >/dev/null 2>&1

# Operation: nmcli answers and the user may manage networks.
check nmcli -t -f STATE g
if id -nG "$(whoami)" | tr ' ' '\n' | grep -qx network; then
  printf 'PASS: user in network group\n'
else
  printf 'FAIL: user not in network group\n' >&2
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  printf '%d PR4.0 check(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'All PR4.0 checks passed\n'
