#!/usr/bin/env bash
# PR4.3 checks for the Cloudflare WARP provider in a live Void session.
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
expected_branch="${INIR_EXPECTED_BRANCH:-feat/void-ydotool-provider}"
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

deps="$repo_root/sdata/dist-void/install-deps.sh"
functions="$repo_root/sdata/lib/functions.sh"
for needle in \
  'WARP_VERSION="2026.7.1377.0"' \
  'WARP_DEB_SHA256="95d33c2b4fc42f21c204981c51470a6a679d618fb0b78ee64bdd0db142230c55"' \
  'sha256sum -c -' \
  'install_void_warp'; do
  if grep -Fq "$needle" "$deps"; then
    printf 'PASS: provider contains: %s\n' "$needle"
  else
    printf 'FAIL: provider missing: %s\n' "$needle" >&2
    failures=$((failures + 1))
  fi
done
check grep -Fq 'configure_void_warp_service' "$functions"

for package in binutils dbus-libs libpcap nss tpm2-tss; do
  check xbps-query -p pkgver "$package"
done
check command -v warp-cli
check command -v warp-svc
if warp-cli --version 2>/dev/null | grep -Fq 2026.7.1377.0; then
  printf 'PASS: warp-cli version is 2026.7.1377.0\n'
else
  printf 'FAIL: warp-cli version is not 2026.7.1377.0\n' >&2
  failures=$((failures + 1))
fi
check test -x /usr/local/bin/warp-cli
check test -x /usr/local/bin/warp-svc
check test -L /var/service/warp-svc
check grep -Fq '# Managed by iNiR.' /etc/sv/warp-svc/run
check test -x /etc/sv/warp-svc/log/run
check grep -Fq '# Managed by iNiR.' /etc/sv/warp-svc/log/run
check grep -Fq 'exec vlogger -t warp-svc -p daemon' /etc/sv/warp-svc/log/run
if sudo -n true >/dev/null 2>&1; then
  check sudo -n sv status /var/service/warp-svc
else
  printf 'INFO: privileged sv status skipped (sudo -n unavailable); socket/process checks remain authoritative\n'
fi
check test -S /run/cloudflare-warp/warp_service

for warp_toggle in \
  "$repo_root/modules/common/models/quickToggles/CloudflareWarpToggle.qml" \
  "$repo_root/modules/sidebarRight/quickToggles/androidStyle/AndroidCloudflareWarpToggle.qml" \
  "$repo_root/modules/sidebarRight/quickToggles/classicStyle/CloudflareWarp.qml"; do
  if ! grep -Fq 'systemctl start warp-svc' "$warp_toggle" \
      && ! grep -Fq 'registration", "new' "$warp_toggle"; then
    printf 'PASS: toggle requires explicit service/account action: %s\n' "${warp_toggle#"$repo_root/"}"
  else
    printf 'FAIL: toggle auto-starts or auto-registers: %s\n' "${warp_toggle#"$repo_root/"}" >&2
    failures=$((failures + 1))
  fi
done

if [[ "${INIR_VERIFY_IDEMPOTENCY:-false}" == true ]]; then
  before="$(mktemp)"
  after="$(mktemp)"
  provider_snapshot() {
    xbps-query -l | sort
    for path in /usr/local/bin/warp-cli /usr/local/bin/warp-svc /etc/sv/warp-svc/run /etc/sv/warp-svc/log/run /var/service/warp-svc; do
      [[ -f "$path" ]] && sha256sum "$path"
      [[ -L "$path" ]] && readlink "$path"
    done
  }
  provider_snapshot > "$before"
  check "$repo_root/setup" install -y --skip-sysupdate --skip-files
  provider_snapshot > "$after"
  check cmp -s "$before" "$after"
  rm -f "$before" "$after"
else
  printf 'INFO: set INIR_VERIFY_IDEMPOTENCY=true to run the second-install snapshot check\n'
fi

if ((failures > 0)); then
  printf '%d PR4.3 check(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'All PR4.3 checks passed\n'
