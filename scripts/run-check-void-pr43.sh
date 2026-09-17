#!/usr/bin/env bash
# Run the PR4.3 Void VM contract without manual session exports.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
branch="${INIR_EXPECTED_BRANCH:-feat/void-ydotool-provider}"
runtime_dir="/run/user/$(id -u)"

exec env \
  XDG_RUNTIME_DIR="$runtime_dir" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
  INIR_VERIFY_IDEMPOTENCY=true \
  INIR_EXPECTED_BRANCH="$branch" \
  INIR_EXPECTED_COMMIT="$(git -C "$repo_root" rev-parse "origin/$branch")" \
  "$repo_root/scripts/check-void-pr43.sh"
