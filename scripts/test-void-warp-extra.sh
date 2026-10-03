#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

metadata="$tmp/Packages"
cat > "$metadata" <<'EOF'
Package: unrelated
Version: 1.0
Filename: pool/unrelated.deb
SHA256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

Package: cloudflare-warp
Version: 2099.4.3.2
Architecture: amd64
Filename: pool/bookworm/main/c/cloudflare-warp/cloudflare-warp_2099.4.3.2_amd64.deb
SHA256: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
EOF

export INIR_WARP_PACKAGES_FILE="$metadata"
export XDG_STATE_HOME="$tmp/state"
export HOME="$tmp/home"
mkdir -p "$HOME"

# shellcheck source=/dev/null
source "$repo_root/sdata/lib/extras.sh"

# Debian payload extraction must preserve explicit compression handling. GNU
# tar does not auto-detect compressed streams read from stdin, which is exactly
# how `ar p data.tar.* | tar ...` is used by the provider.
mkdir -p "$tmp/deb-src/usr/bin" "$tmp/deb-out" "$tmp/deb-build"
printf '#!/bin/sh\nprintf "fixture\\n"\n' > "$tmp/deb-src/usr/bin/warp-cli"
printf '2.0\n' > "$tmp/deb-build/debian-binary"
tar -czf "$tmp/deb-build/control.tar.gz" --files-from /dev/null
tar -cJf "$tmp/deb-build/data.tar.xz" -C "$tmp/deb-src" .
( cd "$tmp/deb-build" && ar r "$tmp/fixture.deb" debian-binary control.tar.gz data.tar.xz >/dev/null )
extras_void_warp_extract_payload "$tmp/fixture.deb" "$tmp/deb-out"
[[ -f "$tmp/deb-out/usr/bin/warp-cli" ]] || {
  printf 'FAIL: WARP provider could not extract an xz-compressed Debian payload\n' >&2
  exit 1
}

expected=$'2099.4.3.2\tpool/bookworm/main/c/cloudflare-warp/cloudflare-warp_2099.4.3.2_amd64.deb\tbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
actual="$(extras_void_warp_release_info)"
[[ "$actual" == "$expected" ]] || {
  printf 'FAIL: WARP metadata parser mismatch\nexpected: %s\nactual:   %s\n' "$expected" "$actual" >&2
  exit 1
}

# Metadata outage falls back to the last release whose artifact/hash is kept in
# tree. Override curl instead of touching the network.
unset INIR_WARP_PACKAGES_FILE
curl() { return 1; }
fallback="$(extras_void_warp_release_info)"
[[ "$fallback" == "$INIR_WARP_FALLBACK_VERSION"$'\t'"$INIR_WARP_FALLBACK_FILENAME"$'\t'"$INIR_WARP_FALLBACK_SHA256" ]] || {
  printf 'FAIL: WARP offline fallback is not deterministic\n' >&2
  exit 1
}
unset -f curl

# A newer local install must never be replaced by older provider metadata.
export INIR_WARP_PACKAGES_FILE="$metadata"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/warp-cli" <<'EOF'
#!/bin/sh
printf '%s\n' 'warp-cli 9999.1.0.0'
EOF
chmod +x "$tmp/bin/warp-cli"
old_path="$PATH"
export PATH="$tmp/bin:$PATH"
OS_GROUP_ID=void
log_warning() { :; }
log_success() { :; }
log_info() { :; }
tui_info() { :; }
if ! extras_install_void_warp; then
  printf 'FAIL: WARP provider rejected a newer installed version\n' >&2
  exit 1
fi
state_file="$(extras_void_warp_state_file)"
[[ ! -e "$state_file" ]] || {
  printf 'FAIL: WARP provider claimed ownership metadata for an unverified newer local version\n' >&2
  exit 1
}

# The provider is intentionally glibc-only. Simulate musl at the ldd seam and
# make sure it fails before provisioning anything.
cat > "$tmp/bin/ldd" <<'EOF'
#!/bin/sh
printf '%s\n' 'musl libc (x86_64)'
EOF
chmod +x "$tmp/bin/ldd"
rm -f "$state_file"
if extras_install_void_warp; then
  printf 'FAIL: WARP provider accepted a simulated Void musl host\n' >&2
  exit 1
fi
[[ ! -e "$state_file" ]] || { printf 'FAIL: musl rejection wrote provider state\n' >&2; exit 1; }

export PATH="$old_path"
printf 'Void WARP optional-extra checks passed\n'
