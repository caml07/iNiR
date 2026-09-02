#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_root="$(cd -- "$script_dir/.." && pwd)"
launcher="${INIR_LAUNCHER_PATH:-$runtime_root/scripts/inir}"

# Reuse the production predicate so systemd-only invariants are skipped when
# this script runs in a session without a usable systemd user manager.
source "$runtime_root/sdata/lib/functions.sh"

run_runtime=false
if [[ "${1:-}" == "--with-runtime" ]]; then
    run_runtime=true
fi

step() {
    printf '\n== %s ==\n' "$1"
}

step "shell syntax"
bash -n \
    "$runtime_root/setup" \
    "$runtime_root/scripts/inir" \
    "$runtime_root/sdata/lib/"*.sh \
    "$runtime_root/sdata/subcmd-install/"*.sh \
    "$runtime_root/sdata/migrations/"*.sh

step "session tray ordering"
# This check is conditional on the usable systemd user manager predicate (ADR-0002).
# The service unit is part of the systemd path implementation.
if has_usable_systemd_user_manager; then
    service_unit="$runtime_root/assets/systemd/inir.service"
    if ! grep -qx 'Type=dbus' "$service_unit" \
            || ! grep -qx 'BusName=org.kde.StatusNotifierWatcher' "$service_unit" \
            || ! grep -qx 'Before=graphical-session.target' "$service_unit" \
            || grep -qx 'After=graphical-session.target' "$service_unit" \
            || grep -qx 'Requisite=graphical-session.target' "$service_unit"; then
        printf 'FAIL: inir.service does not gate XDG autostart on the tray watcher\n' >&2
        exit 1
    fi
    if ! grep -Fq 'property var _trayService: TrayService' "$runtime_root/shell.qml"; then
        printf 'FAIL: shell startup does not instantiate the StatusNotifier watcher\n' >&2
        exit 1
    fi
    # MALLOC check for systemd service unit
    if grep -q '^Environment=MALLOC_' "$service_unit" \
            || grep -Eq '^[[:space:]]*export[[:space:]]+MALLOC_' "$runtime_root/scripts/inir" \
            || grep -Eq '^[[:space:]]*export[[:space:]]+MALLOC_' "$runtime_root/scripts/quickshell-env.sh"; then
        printf 'FAIL: iNiR still overrides the glibc allocator at runtime\n' >&2
        exit 1
    fi
else
    printf 'SKIP: systemd user manager predicate false — skipping systemd service unit checks\n'
    # MALLOC check for non-systemd (launcher and env scripts only)
    if grep -Eq '^[[:space:]]*export[[:space:]]+MALLOC_' "$runtime_root/scripts/inir" \
            || grep -Eq '^[[:space:]]*export[[:space:]]+MALLOC_' "$runtime_root/scripts/quickshell-env.sh"; then
        printf 'FAIL: iNiR still overrides the glibc allocator at runtime\n' >&2
        exit 1
    fi
fi

step "service mask handling"
service_mask_root="$(mktemp -d)"
mkdir -p "$service_mask_root/systemd/user" "$service_mask_root/bin"
cat > "$service_mask_root/bin/systemctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${INIR_TEST_SYSTEMCTL_STATE:-disabled}"
SH
chmod +x "$service_mask_root/bin/systemctl"
ln -s /dev/null "$service_mask_root/systemd/user/inir.service"
if ! (
    export XDG_CONFIG_HOME="$service_mask_root"
    export PATH="$service_mask_root/bin:$PATH"
    source "$runtime_root/sdata/lib/functions.sh"
    inir_user_service_is_masked
); then
    printf 'FAIL: user service mask is not detected\n' >&2
    rm -rf "$service_mask_root"
    exit 1
fi
rm -f "$service_mask_root/systemd/user/inir.service"
printf '[Unit]\nDescription=test\n' > "$service_mask_root/systemd/user/inir.service"
if (
    export XDG_CONFIG_HOME="$service_mask_root"
    export PATH="$service_mask_root/bin:$PATH"
    source "$runtime_root/sdata/lib/functions.sh"
    inir_user_service_is_masked
); then
    printf 'FAIL: regular user service is classified as masked\n' >&2
    rm -rf "$service_mask_root"
    exit 1
fi
if ! (
    export XDG_CONFIG_HOME="$service_mask_root"
    export PATH="$service_mask_root/bin:$PATH"
    export INIR_TEST_SYSTEMCTL_STATE=masked-runtime
    source "$runtime_root/sdata/lib/functions.sh"
    inir_user_service_is_masked
); then
    printf 'FAIL: runtime user service mask is not detected\n' >&2
    rm -rf "$service_mask_root"
    exit 1
fi
rm -rf "$service_mask_root"
if ! grep -Fq 'inir_user_service_is_masked && return 2' "$runtime_root/setup" \
        || ! grep -Fq 'User inir.service is masked; leaving it unchanged' "$runtime_root/setup" \
        || ! grep -Fq 'Shell restart skipped: inir.service is masked' "$runtime_root/setup" \
        || ! grep -Fq 'User inir.service is masked' "$runtime_root/sdata/lib/doctor.sh" \
        || ! grep -Fq 'systemctl --user unmask inir.service' "$runtime_root/sdata/subcmd-install/3.files.sh" \
        || ! grep -Fq 'systemctl --user unmask --runtime inir.service' "$runtime_root/scripts/inir"; then
    printf 'FAIL: install/update/doctor do not preserve the service mask contract\n' >&2
    exit 1
fi

step "fresh install defaults"
python3 - "$runtime_root" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
with (root / "defaults/config.json").open(encoding="utf-8") as handle:
    config = json.load(handle)
schema = (root / "modules/common/Config.qml").read_text(encoding="utf-8")
wizard = (root / "welcome.qml").read_text(encoding="utf-8")

checks = {
    "settings rail": config["settingsUi"]["overlayStyle"] == "rail",
    "balanced profile": config["welcomeWizard"]["profile"] == "balanced",
    "iNiR Alt+Tab opt-in": config["modules"]["altSwitcher"] is False,
    "dock enabled": config["dock"]["enable"] is True,
    "dock pinned": config["dock"]["pinnedOnStartup"] is True,
    "dock not hover-only": config["dock"]["hoverToReveal"] is False,
    "right sidebar full height": config["sidebar"]["collapseEmptyNotifications"] is False,
    "left sidebar full height": config["sidebar"]["collapseWidgetsTab"] is False,
    "wallhaven tab": config["sidebar"]["wallhaven"]["enable"] is True,
    "news tab": config["sidebar"]["news"]["enable"] is True,
    "controls widget": config["sidebar"]["widgets"]["controls"] is True,
    "status widget": config["sidebar"]["widgets"]["status"] is True,
}
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: fresh-install defaults: " + ", ".join(failed))

schema_checks = {
    "schema settings rail": 'property string overlayStyle: "rail"' in schema,
    "schema iNiR Alt+Tab opt-in": "property bool altSwitcher: false" in schema.split(
        "property JsonObject modules: JsonObject {", 1)[1].split(
        "property JsonObject appearance: JsonObject {", 1)[0],
    "schema dock enabled": "property bool enable: true" in schema.split(
        "property JsonObject dock: JsonObject {", 1)[1].split(
        "property JsonObject controlPanel: JsonObject {", 1)[0],
    "schema dock pinned": "property bool pinnedOnStartup: true" in schema,
    "schema dock not hover-only": "property bool hoverToReveal: false" in schema,
    "schema right sidebar full height": "property bool collapseEmptyNotifications: false" in schema,
    "schema left sidebar full height": "property bool collapseWidgetsTab: false" in schema,
    # `wallhaven` is the compatibility key; the UI is now the generic
    # Wallpapers tab. Assert the schema contract instead of a stale comment.
    "schema wallhaven compatibility": "property JsonObject wallhaven: JsonObject {" in schema
        and "property bool enable: true" in schema[schema.index("property JsonObject wallhaven: JsonObject {"):],
    "schema news tab": "property JsonObject news: JsonObject {\n                    property bool enable: true" in schema,
    "wizard applies initial profile": "root.applyProfile(root.selectedProfile)" in wizard,
    "wizard dock pinned": '"dock.pinnedOnStartup": true' in wizard,
    "wizard dock not hover-only": '"dock.hoverToReveal": false' in wizard,
    "wizard right sidebar full height": '"sidebar.collapseEmptyNotifications": false' in wizard,
    "wizard left sidebar full height": '"sidebar.collapseWidgetsTab": false' in wizard,
    "wizard preserves Waffle configuration": '"waffles.' not in wizard.split(
        "readonly property var profileEssentials", 1)[1].split(
        "// ─── Entry/exit animation state", 1)[0],
}
failed = [name for name, passed in schema_checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: schema/wizard defaults: " + ", ".join(failed))

binds = (root / "defaults/niri/config.d/70-binds.kdl").read_text(encoding="utf-8")
if 'Alt+Tab { next-window; }' not in binds or 'Alt+Shift+Tab { previous-window; }' not in binds:
    raise SystemExit("FAIL: native Niri Alt+Tab bindings are missing")
if 'spawn "inir" "altSwitcher"' in binds:
    raise SystemExit("FAIL: fresh-install Alt+Tab invokes the iNiR switcher")
PY

arch_installer="$runtime_root/sdata/dist-arch/install-deps.sh"
if ! grep -Fq 'pacman -T "${_all_official[@]}"' "$arch_installer" \
        || ! grep -Fq 'pacman -S $installflags "${_repo_installable[@]}"' "$arch_installer"; then
    printf 'FAIL: Arch package plan is not filtered through the local package database before the batched install\n' >&2
    exit 1
fi
if grep -Fq 'pacman -S $installflags "${_all_official[@]}"' "$arch_installer"; then
    printf 'FAIL: Arch installer can still reinstall or downgrade satisfied dependencies\n' >&2
    exit 1
fi

fedora_installer="$runtime_root/sdata/dist-fedora/install-deps.sh"
if ! grep -Fq 'fedora_quickshell_compatible' "$fedora_installer" \
        || ! grep -Fq 'FEDORA_REPO_PKGS=' "$fedora_installer" \
        || ! grep -Eq '^[[:space:]]+sddm$' "$fedora_installer"; then
    printf 'FAIL: Fedora installer lost repository-first/version-aware package planning or SDDM\n' >&2
    exit 1
fi
if grep -Fq 'rpmfusion-nonfree-release' "$fedora_installer"; then
    printf 'FAIL: Fedora installer enables RPM Fusion Nonfree without an iNiR dependency requiring it\n' >&2
    exit 1
fi
sddm_installer="$runtime_root/scripts/sddm/install-pixel-sddm.sh"
if grep -Eq '^[[:space:]]*DisplayServer=' "$sddm_installer" \
        || grep -Eq '^[[:space:]]*InputMethod=' "$sddm_installer"; then
    printf 'FAIL: ii-pixel theme installer overrides distro-owned SDDM greeter backend/input policy\n' >&2
    exit 1
fi
if ! grep -Fq 'Current=${THEME_NAME}' "$sddm_installer"; then
    printf 'FAIL: ii-pixel theme installer no longer configures the SDDM theme\n' >&2
    exit 1
fi
if grep -Fq '${cmd_to_pkg[$cmd]:-$cmd}' "$fedora_installer"; then
    printf 'FAIL: Fedora Doctor repair can still pass unknown command IDs directly to dnf\n' >&2
    exit 1
fi
for required in \
    '[qalc]="qalculate"' \
    '[nm-connection-editor]="nm-connection-editor"' \
    'install_awww_fedora' \
    'install_gowall_fedora' \
    'install_missioncenter_fedora' \
    'install_songrec_fedora'; do
    if ! grep -Fq "$required" "$fedora_installer"; then
        printf 'FAIL: Fedora dependency repair lost required route: %s\n' "$required" >&2
        exit 1
    fi
done
if ! grep -Fq 'dnf copr enable -y scottames/awww' "$fedora_installer" \
        || ! grep -Fq 'dnf copr enable -y achno/gowall' "$fedora_installer"; then
    printf 'FAIL: Fedora awww/Gowall no longer prefer their focused COPR packages before source fallbacks\n' >&2
    exit 1
fi
if ! grep -Fq '[[ "${OS_GROUP_ID:-unknown}" == "arch" ]]' "$runtime_root/sdata/lib/doctor.sh"; then
    printf 'FAIL: Doctor no longer scopes checkupdates to Arch\n' >&2
    exit 1
fi
if ! grep -Fq 'ocr-jpn:OCR Japanese data' "$runtime_root/sdata/lib/doctor.sh" \
        || ! grep -Fq '[ocr-jpn]="tesseract-data-jpn"' "$arch_installer" \
        || ! grep -Fq '[ocr-jpn]="tesseract-langpack-jpn"' "$fedora_installer"; then
    printf 'FAIL: Doctor/installers no longer repair missing OCR language data\n' >&2
    exit 1
fi

debian_installer="$runtime_root/sdata/dist-debian/install-deps.sh"
if ! grep -Fq 'ensure_debian_backports' "$debian_installer" \
        || ! grep -Fq 'ensure_debian_component "contrib"' "$debian_installer" \
        || ! grep -Fq 'polkit-kde-agent-1' "$debian_installer"; then
    printf 'FAIL: Debian installer lost backports/contrib/Trixie compatibility handling\n' >&2
    exit 1
fi
if grep -Fq 'tui_info "Setting up Rust toolchain..."' "$debian_installer"; then
    printf 'FAIL: Debian installer installs Rust unconditionally instead of only for source fallbacks\n' >&2
    exit 1
fi
if ! grep -Fq '[ocr-jpn]="tesseract-ocr-jpn"' "$debian_installer"; then
    printf 'FAIL: Debian Doctor repair lost Japanese OCR language mapping\n' >&2
    exit 1
fi

# Super+Shift+S is the remembered unified snip entry point; Print remains direct.
if ! grep -Fq 'Mod+Shift+S { spawn "inir" "region" "menu"; }' "$runtime_root/defaults/niri/config.d/70-binds.kdl" \
        || [[ ! -x "$runtime_root/sdata/migrations/037-remembered-super-shift-s.sh" ]]; then
    printf 'FAIL: remembered Super+Shift+S snip flow is incomplete\n' >&2
    exit 1
fi
if grep -Fq '${cmd_to_pkg[$cmd]:-$cmd}' "$debian_installer"; then
    printf 'FAIL: Debian Doctor repair can still pass unknown command IDs directly to apt\n' >&2
    exit 1
fi
for required in \
    '[qalc]="qalc"' \
    '[nm-connection-editor]="network-manager-gnome"' \
    'io.missioncenter.MissionCenter' \
    'golang-go' \
    'cargo install --root "$SONGREC_ROOT" songrec'; do
    if ! grep -Fq "$required" "$debian_installer"; then
        printf 'FAIL: Debian dependency repair/provider route missing: %s\n' "$required" >&2
        exit 1
    fi
done

ocr_runner="$runtime_root/scripts/ocr-runner.sh"
region_selector="$runtime_root/modules/regionSelector/RegionSelection.qml"
if [[ ! -x "$ocr_runner" ]] \
        || ! grep -Fq 'property string ocrLanguage: "auto"' "$runtime_root/modules/common/Config.qml" \
        || ! grep -Fq 'scripts/ocr-runner.sh' "$region_selector"; then
    printf 'FAIL: multilingual OCR runtime/config wiring is incomplete\n' >&2
    exit 1
fi
if grep -Fq 'tesseract --list-langs |' "$region_selector"; then
    printf 'FAIL: region OCR still combines every installed Tesseract language\n' >&2
    exit 1
fi
if ! grep -Fq 'tessdata_fast/main/$lang.traineddata' "$ocr_runner" \
        || ! grep -Fq 'cdn.jsdelivr.net/gh/tesseract-ocr/tessdata_fast' "$ocr_runner" \
        || ! grep -Fq 'INIR_TESSDATA_DIR' "$ocr_runner"; then
    printf 'FAIL: OCR runtime lost user-space language provisioning fallback\n' >&2
    exit 1
fi
if grep -F 'japaneseOcrProc.command' "$region_selector" | grep -Fq 'wl-copy'; then
    printf 'FAIL: Japanese OCR stdout is still consumed by clipboard plumbing before lookup\n' >&2
    exit 1
fi
clipboard_helper="$runtime_root/scripts/clipboard-copy.sh"
if [[ ! -x "$clipboard_helper" ]] \
        || ! grep -Fq 'systemd-run --user' "$clipboard_helper" \
        || grep -R -Fq '/usr/bin/wl-copy' "$runtime_root/modules/regionSelector" \
        || grep -R -Fq 'execDetached(["wl-copy"' "$runtime_root/modules/japaneseLookup"; then
    printf 'FAIL: snipping clipboard ownership can leak wl-copy into inir.service\n' >&2
    exit 1
fi
if grep -A30 -F 'Enable AnkiConnect button' "$runtime_root/modules/settings/ToolsConfig.qml" | grep -Fq 'GridLayout {'; then
    printf 'FAIL: Anki settings reintroduced the MaterialTextField/GridLayout implicitWidth binding loop\n' >&2
    exit 1
fi
if ! grep -Fq 'anki-status' "$runtime_root/services/JapaneseDictionary.qml" \
        || ! grep -Fq 'Anki Desktop not detected' "$runtime_root/services/JapaneseDictionary.qml" \
        || ! grep -Fq 'Open Anki' "$runtime_root/modules/japaneseLookup/JapaneseLookup.qml" \
        || ! grep -Fq 'cardContent.implicitHeight + 28' "$runtime_root/modules/japaneseLookup/JapaneseLookup.qml"; then
    printf 'FAIL: Japanese lookup Anki health/footer sizing regression\n' >&2
    exit 1
fi
if ! grep -Fq 'showAdvancedOcr' "$runtime_root/modules/settings/ToolsConfig.qml" \
        || ! grep -Fq 'showAdvancedAnki' "$runtime_root/modules/settings/ToolsConfig.qml" \
        || ! grep -Fq 'Japanese study assistant' "$runtime_root/modules/settings/ToolsConfig.qml"; then
    printf 'FAIL: OCR/Japanese Settings onboarding regressed into technical-first controls\n' >&2
    exit 1
fi
sidebar_group="$runtime_root/modules/sidebarRight/BottomWidgetGroup.qml"
if grep -A90 -F '// Navigation rail' "$sidebar_group" | grep -Fq 'open_in_full' \
        || ! grep -Fq 'onRequestExpand: root.requestExpand("calendar")' "$sidebar_group" \
        || ! grep -Fq 'onRequestExpand: root.requestExpand("events")' "$sidebar_group" \
        || ! grep -Fq 'onRequestExpand: root.requestExpand("todo")' "$sidebar_group"; then
    printf 'FAIL: right-sidebar organizer expansion leaked back into the navigation rail\n' >&2
    exit 1
fi
for widget in calendar/CalendarWidget.qml events/EventsWidget.qml todo/TodoWidget.qml; do
    grep -Fq 'signal requestExpand()' "$runtime_root/modules/sidebarRight/$widget" || {
        printf 'FAIL: right-sidebar organizer widget lacks contextual expand action: %s\n' "$widget" >&2
        exit 1
    }
done

if ! grep -Fq 'japaneseLookupExpanded' "$runtime_root/modules/japaneseLookup/JapaneseLookup.qml" \
        || ! grep -Fq 'translateCurrent' "$runtime_root/modules/japaneseLookup/JapaneseLookup.qml" \
        || [[ ! -x "$runtime_root/scripts/translate-ocr.sh" ]] \
        || [[ ! -x "$runtime_root/scripts/study-decks.py" ]]; then
    printf 'FAIL: expandable Japanese lookup translation/study tools are incomplete\n' >&2
    exit 1
fi
if ! grep -Fq -- '--psm "$psm"' "$ocr_runner" \
        || ! grep -Fq 'resize 200%' "$ocr_runner"; then
    printf 'FAIL: OCR selection-aware segmentation/preprocessing regressed\n' >&2
    exit 1
fi
python3 "$runtime_root/scripts/study-decks.py" list | grep -Fq '"kaishi"' || {
    printf 'FAIL: study deck catalog is unavailable\n' >&2
    exit 1
}
for pkg in tesseract-data-rus tesseract-data-jpn tesseract-data-jpn_vert tesseract-data-chi_sim tesseract-data-chi_tra; do
    grep -Fq "$pkg" "$runtime_root/sdata/dist-arch/inir-screencapture/PKGBUILD" || {
        printf 'FAIL: Arch screencapture bundle is missing OCR language package %s\n' "$pkg" >&2
        exit 1
    }
done
for pkg in tesseract-langpack-rus tesseract-langpack-jpn tesseract-langpack-jpn_vert tesseract-langpack-chi_sim tesseract-langpack-chi_tra; do
    grep -Fq "$pkg" "$fedora_installer" || {
        printf 'FAIL: Fedora installer is missing OCR language package %s\n' "$pkg" >&2
        exit 1
    }
done
for pkg in tesseract-ocr-rus tesseract-ocr-jpn tesseract-ocr-jpn-vert tesseract-ocr-chi-sim tesseract-ocr-chi-tra; do
    grep -Fq "$pkg" "$debian_installer" || {
        printf 'FAIL: Debian installer is missing OCR language package %s\n' "$pkg" >&2
        exit 1
    }
done

jp_dictionary="$runtime_root/scripts/japanese-dictionary.py"
if [[ ! -x "$jp_dictionary" ]]; then
    printf 'FAIL: Japanese dictionary backend is missing or not executable\n' >&2
    exit 1
fi
if ! grep -Fq 'singleton JapaneseDictionary 1.0 JapaneseDictionary.qml' "$runtime_root/services/qmldir" \
        || ! grep -Fq 'modules/japaneseLookup/JapaneseLookup.qml' "$runtime_root/shell.qml" \
        || ! grep -Fq 'JapaneseDictionary.lookupText' "$runtime_root/modules/regionSelector/RegionSelection.qml" \
        || ! grep -Fq 'Install Japanese dictionary (~37 MB)' "$runtime_root/modules/settings/ToolsConfig.qml"; then
    printf 'FAIL: Japanese OCR dictionary UI/runtime wiring is incomplete\n' >&2
    exit 1
fi
jp_installer="$runtime_root/scripts/install-japanese-dictionary.sh"
if [[ ! -x "$jp_installer" ]] \
        || ! grep -Fq 'releases/latest/download/jitendex-yomitan.zip' "$jp_installer" \
        || ! grep -Fq 'JapaneseDictionary.installRecommended()' "$runtime_root/modules/japaneseLookup/JapaneseLookup.qml"; then
    printf 'FAIL: one-click Jitendex onboarding is incomplete\n' >&2
    exit 1
fi
python3 - "$jp_dictionary" <<'PYTEST'
import json, subprocess, sys, tempfile, zipfile
from pathlib import Path

script = Path(sys.argv[1])
with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    archive = root / "test.zip"
    db = root / "dictionary.sqlite3"
    with zipfile.ZipFile(archive, "w") as z:
        z.writestr("index.json", json.dumps({"title": "iNiR Test", "revision": "1", "format": 3}))
        z.writestr("term_bank_1.json", json.dumps([
            ["食べる", "たべる", "v1", "v1", 10, ["to eat"], 1, "common"],
            ["高い", "たかい", "adj-i", "adj-i", 8, [{"type":"structured-content","content":{"tag":"ul","data":{"content":"glossary"},"content":{"tag":"li","content":"high; expensive"}}}], 2, "common"],
            ["またね", "またね", "", "", 200, ["bye; see you later"], 3, "common"],
            ["ま", "ま", "", "", 97, ["just; now"], 4, ""],
            ["幾ら", "いくら", "", "", 200, ["how much"], 5, "common"],
            ["いくら", "いくら", "", "", 99, ["salted salmon roe"], 6, ""],
            ["何処", "どこ", "", "", 200, ["where"], 7, "common"]
        ], ensure_ascii=False))
        z.writestr("term_meta_bank_1.json", json.dumps([["食べる", "pitch", {"reading": "たべる", "pitches": [{"position": 2}]}]], ensure_ascii=False))
        z.writestr("kanji_bank_1.json", json.dumps([["食", "ショク", "た.べる", "", ["eat"], {}]], ensure_ascii=False))
    def run(*args):
        proc = subprocess.run([sys.executable, str(script), "--db", str(db), *args], check=True, text=True, capture_output=True)
        return json.loads(proc.stdout)
    assert run("import", str(archive))["terms"] == 7
    scanned = run("scan", "食べる猫")
    assert scanned["matched"] == "食べる"
    assert scanned["metadata"]["pitch"][0]["data"]["pitches"][0]["position"] == 2
    polite = run("scan-smart", "食べました")
    assert polite["matched"] == "食べる" and polite["surface"] == "食べました"
    assert polite["reading"] == "たべる" and polite["romaji"] == "taberu"
    adjective = run("scan-smart", "高かった")
    assert adjective["matched"] == "高い"
    assert adjective["terms"][0]["displayDefinitions"] == ["high; expensive"]
    phrase = run("scan-smart", "• またね (Mata ne) — See you later")
    assert phrase["surface"] == "またね" and phrase["terms"][0]["displayDefinitions"][0].startswith("bye")
    spaced_phrase = run("scan-smart", "• ま た ね (Mata ne) — See you later")
    assert spaced_phrase["surface"] == "またね"
    price = run("scan-smart", "いくらですか (Ikura desu ka)")
    assert price["surface"] == "いくら" and price["terms"][0]["expression"] == "幾ら"
    where = run("scan-smart", "どこですか")
    assert where["surface"] == "どこ" and where["terms"][0]["expression"] == "何処"
    assert run("kanji", "食")["kanji"][0]["meanings"] == ["eat"]
PYTEST

python_setup_owners=$(grep -l 'v install-python-packages' \
    "$runtime_root"/sdata/dist-*/install-deps.sh \
    "$runtime_root/sdata/subcmd-install/3.files.sh" 2>/dev/null || true)
if [[ "$python_setup_owners" != "$runtime_root/sdata/subcmd-install/3.files.sh" ]]; then
    printf 'FAIL: Python environment setup has more than one install owner:\n%s\n' "$python_setup_owners" >&2
    exit 1
fi

step "runtime payload manifests"
while IFS= read -r runtime_file; do
    [[ -n "$runtime_file" ]] || continue
    [[ -f "$runtime_root/$runtime_file" ]]
done < "$runtime_root/sdata/runtime-root-files.txt"

while IFS= read -r runtime_dir; do
    [[ -n "$runtime_dir" ]] || continue
    [[ -d "$runtime_root/$runtime_dir" ]]
done < "$runtime_root/sdata/runtime-payload-dirs.txt"

snapshot_lib="$runtime_root/sdata/lib/snapshots.sh"
if ! grep -Fq 'quickshell/user/desktop-items.json' "$snapshot_lib" \
        || ! grep -Fq 'desktop-items.json' "$snapshot_lib"; then
    printf 'FAIL: managed desktop items are absent from update snapshots\n' >&2
    exit 1
fi

step "mascot runtime manifest"
mascot_manifest="$runtime_root/assets/images/mascot/manifest.json"
if [[ ! -f "$mascot_manifest" ]]; then
    printf 'FAIL: mascot runtime manifest is missing: %s\n' "$mascot_manifest" >&2
    exit 1
fi
python3 -m json.tool "$mascot_manifest" >/dev/null
if ! grep -qx 'assets' "$runtime_root/sdata/runtime-payload-dirs.txt"; then
    printf 'FAIL: assets is absent from runtime-payload-dirs.txt\n' >&2
    exit 1
fi
if grep -q -- "--exclude='assets/images/mascot/manifest.json'" "$runtime_root/sdata/lib/functions.sh"; then
    printf 'FAIL: repo-copy sync excludes the mascot runtime manifest\n' >&2
    exit 1
fi
# Payload directories are copied one at a time, so these are relative to
# assets/ — an 'assets/…' prefix here never matches and the art ships.
for local_mascot_path in \
    "images/mascot/*.png" \
    "images/mascot/*.gif" \
    "images/mascot/frames/" \
    "images/mascot/PROMPTS.md"; do
    if ! grep -Fq -- "--exclude='$local_mascot_path'" "$runtime_root/sdata/lib/functions.sh"; then
        printf 'FAIL: repo-copy sync can leak local mascot artifact: %s\n' "$local_mascot_path" >&2
        exit 1
    fi
done
if ! grep -q "inir-mascot-.*\\.png" "$runtime_root/Makefile" \
        || ! grep -q "inir-mascot-.*\\.gif" "$runtime_root/Makefile" \
        || ! grep -q 'PROMPTS.md' "$runtime_root/Makefile" \
        || ! grep -q 'assets/images/mascot/frames' "$runtime_root/Makefile"; then
    printf 'FAIL: make install does not strip local mascot art/tooling\n' >&2
    exit 1
fi

step "mascot pack install and repair"
bash "$runtime_root/scripts/test-mascot-pack-flow.sh"

if [[ -f "$runtime_root/Makefile" ]]; then
    step "make install dry run"
    make -n install PREFIX=/tmp/inir-stage-test -C "$runtime_root" >/dev/null
fi

if [[ -d "$runtime_root/distro/arch" ]]; then
    step "pkgbuild syntax"
    bash -n \
        "$runtime_root/distro/arch/inir-shell/PKGBUILD" \
        "$runtime_root/distro/arch/inir-shell-git/PKGBUILD" \
        "$runtime_root/distro/arch/inir-meta/PKGBUILD"

    step "version consistency"
    version="$(cat "$runtime_root/VERSION")"
    for pkg in inir-shell inir-meta; do
        pkg_ver="$(grep -m1 '^pkgver=' "$runtime_root/distro/arch/$pkg/PKGBUILD" | cut -d= -f2)"
        if [[ "$pkg_ver" != "$version" ]]; then
            printf 'FAIL: %s pkgver=%s != VERSION=%s\n' "$pkg" "$pkg_ver" "$version" >&2
            exit 1
        fi
        srcinfo_ver="$(awk '/^[[:space:]]*pkgver = / {print $3; exit}' "$runtime_root/distro/arch/$pkg/.SRCINFO")"
        if [[ "$srcinfo_ver" != "$version" ]]; then
            printf 'FAIL: %s .SRCINFO pkgver=%s != VERSION=%s\n' "$pkg" "$srcinfo_ver" "$version" >&2
            exit 1
        fi
    done

    deps_ver="$(grep -m1 '^pkgver=' "$runtime_root/sdata/dist-arch/inir-deps/PKGBUILD" | cut -d= -f2)"
    if [[ "$deps_ver" != "$version" ]]; then
        printf 'FAIL: inir-deps pkgver=%s != VERSION=%s\n' "$deps_ver" "$version" >&2
        exit 1
    fi

    if ! grep -Fq "iNiR/${version} (https://github.com/snowarch/inir)" "$runtime_root/scripts/lyrics/lyrics.py"; then
        printf 'FAIL: lyrics User-Agent does not match VERSION=%s\n' "$version" >&2
        exit 1
    fi

    if ! grep -Fq "version-${version}-blue" "$runtime_root/README.md"; then
        printf 'FAIL: README release badge does not match VERSION=%s\n' "$version" >&2
        exit 1
    fi
fi

step "release polish guards"
if ! grep -Fq 'message="$(_tui_expand_newlines "${3:-}")"' "$runtime_root/sdata/lib/tui.sh"; then
    printf 'FAIL: TUI alerts can regress to rendering literal \n sequences\n' >&2
    exit 1
fi
pixel_clock="$runtime_root/modules/background/widgets/clock/PixelClock.qml"
if grep -Eq 'OpacityMask|maskEnabled|maskSource|StyledDropShadow' "$pixel_clock" \
        || ! grep -Fq 'renderType: Text.QtRendering' "$pixel_clock" \
        || ! grep -Fq 'style: root.showShadow ? Text.Raised : Text.Normal' "$pixel_clock" \
        || ! grep -Fq 'root.width * 0.46' "$pixel_clock" \
        || ! grep -Fq 'Compose interlocking digits directly' "$pixel_clock"; then
    printf 'FAIL: Pixel Clock can regress to masked/resampled chromatic edges or shifted geometry\n' >&2
    exit 1
fi

media_overlay="$runtime_root/modules/mediaControls/components/MediaVisualizerOverlay.qml"
media_edge="$runtime_root/modules/mediaControls/components/MediaOrganicEdgeAura.qml"
audio_layer="$runtime_root/modules/common/widgets/AudioVisualizerLayer.qml"
media_widget="$runtime_root/modules/background/widgets/mediaControls/MediaControlsWidget.qml"
if ! grep -Fq 'barsOrigin: root.visualizerPosition === "top" ? "top"' "$media_overlay" \
        || ! grep -Fq 'root.visualizerPosition === "fill" ? "mirror" : "bottom"' "$media_overlay" \
        || ! grep -Fq 'visible: root.visualizerPosition !== "none" && !root.organic' "$media_overlay" \
        || grep -Fq 'organicPresentationMode' "$media_overlay" \
        || [[ ! -f "$media_edge" ]] \
        || ! grep -Fq 'organicPresentationMode: 2.0' "$media_edge" \
        || ! grep -Fq 'organicEdgeDirections: Qt.vector4d(1, 1, 1, 1)' "$media_edge" \
        || grep -Fq 'organicDirection' "$media_edge" \
        || ! grep -Fq 'MediaOrganicEdgeAura {' "$media_widget" \
        || ! grep -Fq 'z: -1' "$media_widget" \
        || ! grep -Fq 'StyledRectangularShadow {' "$media_widget" \
        || ! grep -Fq 'z: -2' "$media_widget" \
        || grep -Fq 'maxVisualizerValue: 1000' "$runtime_root/modules/mediaControls/presets/FullPlayer.qml"; then
    printf 'FAIL: Media Player visualizers can regress to floating Wave/legacy normalization or in-card Organic\n' >&2
    exit 1
fi
if [[ "$(grep -Fc 'property bool organicStretchToHost' "$audio_layer")" -ne 1 ]] \
        || [[ "$(grep -Fc 'property real organicHollowAmount' "$audio_layer")" -ne 1 ]] \
        || ! grep -Fq 'presentationMode: root.organicPresentationMode' "$audio_layer"; then
    printf 'FAIL: shared audio visualizer properties are duplicated or missing\n' >&2
    exit 1
fi
for media_preset in Full Compact Minimal AlbumArt Visualizer Classic Lyrics LyricsSplit ExpandingLyrics; do
    preset_file="$runtime_root/modules/mediaControls/presets/${media_preset}Player.qml"
    if ! grep -Fq 'MediaVisualizerOverlay {' "$preset_file" \
            || ! grep -Fq 'root.vizType === "organic" && root.vizPosition !== "none"' "$preset_file" \
            || grep -Fq 'maxVisualizerValue: 1000' "$preset_file"; then
        printf 'FAIL: media preset %s is not on the shared adaptive visualizer path\n' "$media_preset" >&2
        exit 1
    fi
done

organic_shader="$runtime_root/modules/common/widgets/OrganicAudioBlob.frag"
visualizer_widget="$runtime_root/modules/background/widgets/visualizer/VisualizerWidget.qml"
visualizer_settings="$runtime_root/modules/settings/DesktopWidgetsConfig.qml"
if ! grep -Fq 'bool edgeMode = ubuf.presentationMode > 1.5' "$organic_shader" \
        || ! grep -Fq 'edgeDirections' "$organic_shader" \
        || ! grep -Fq 'edgeReachHalf' "$organic_shader" \
        || ! grep -Fq 'float edgeDistanceNormalized' "$organic_shader" \
        || ! grep -Fq 'float edgeRadialSpan = max(0.18, 0.94 - ubuf.edgeBaseRadius)' "$organic_shader" \
        || ! grep -Fq 'float edgeCornerRadius;' "$organic_shader" \
        || ! grep -Fq 'float baseRadius;' "$organic_shader" \
        || ! grep -Fq 'ubuf.baseRadius + breath + pulsePush' "$organic_shader" \
        || ! grep -Fq 'vec2 perimeterDirection = vec2(' "$organic_shader" \
        || grep -Fq 'bool verticalSide = dx < dy' "$organic_shader" \
        || grep -Fq 'float perimeterPhase' "$organic_shader" \
        || ! grep -Fq 'float r = edgeMode' "$organic_shader" \
        || ! grep -Fq 'presentationMask * sourceAlpha' "$organic_shader" \
        || ! grep -Fq 'outsideMask = smoothstep(-perimeterAA, perimeterAA, cardDistance)' "$organic_shader" \
        || [[ "$(grep -Fc 'fragColor = vec4' "$organic_shader")" -ne 1 ]] \
        || grep -Fq 'smoothstep(-0.012' "$organic_shader" \
        || grep -Fq 'float edgeExtent' "$organic_shader" \
        || grep -Fq 'float extrusion' "$organic_shader" \
        || ! grep -Fq 'geometryMargin: root.reach * 1.08' "$media_edge" \
        || ! grep -Fq 'renderMargin: root.geometryMargin + root.renderPadding' "$media_edge" \
        || ! grep -Fq 'organicOverscan: 1.0' "$media_edge" \
        || ! grep -Fq 'organicEdgeReachHalf:' "$media_edge" \
        || ! grep -Fq 'organicEdgeCornerRadius: root.cardRadius * 2' "$media_edge" \
        || ! grep -Fq 'root.width + root.geometryMargin * 2' "$media_edge" \
        || ! grep -Fq 'root.audioActive ? root.visualizerPoints : root.silentPoints' "$media_edge" \
        || ! grep -Fq 'root.paletteMode === "player"' "$media_edge" \
        || ! grep -Fq 'root.paletteMode === "accent"' "$media_edge" \
        || ! grep -Fq 'root.albumPalette.length > 0' "$media_edge" \
        || ! grep -Fq 'background.widgets.mediaControls.organicSensitivity' "$media_edge" \
        || ! grep -Fq 'background.widgets.mediaControls.organicMotionSpeed' "$media_edge" \
        || ! grep -Fq 'background.widgets.mediaControls.organicGlow' "$media_edge" \
        || ! grep -Fq 'background.widgets.mediaControls.organicRange' "$media_edge" \
        || grep -Fq 'background.widgets.mediaControls.visualizerRange' "$media_edge" \
        || grep -Fq 'background.widgets.visualizer.' "$media_edge" \
        || grep -Fq 'background.widgets.visualizer.organic' "$media_widget" \
        || ! grep -Fq 'background.widgets.mediaControls.organicSensitivity' "$visualizer_settings" \
        || ! grep -Fq 'background.widgets.mediaControls.organicPulse' "$visualizer_settings" \
        || ! grep -Fq 'background.widgets.mediaControls.organicGlow' "$visualizer_settings" \
        || ! grep -Fq 'background.widgets.mediaControls.organicRange' "$visualizer_settings" \
        || ! grep -Fq 'component MediaVizMetric: ColumnLayout' "$media_widget" \
        || ! grep -Fq 'background.widgets.mediaControls.visualizerOpacity' "$media_widget" \
        || ! grep -Fq 'background.widgets.mediaControls.visualizerRange' "$media_widget" \
        || ! grep -Fq 'background.widgets.mediaControls.visualizerSmoothing' "$media_widget" \
        || ! grep -Fq 'background.widgets.mediaControls.visualizerBarCount' "$media_widget" \
        || ! grep -Fq 'background.widgets.mediaControls.visualizerFrequencyProfile' "$media_widget" \
        || ! grep -Fq 'background.widgets.mediaControls.visualizerAccentStrength' "$media_widget" \
        || ! grep -Fq 'organicCoverUnderlap' "$visualizer_widget" \
        || grep -Fq 'organicInnerGap' "$visualizer_widget" \
        || ! grep -Fq 'background.widgets.visualizer.organicCoverSize' "$visualizer_widget" \
        || ! grep -Fq 'background.widgets.visualizer.organicRange' "$visualizer_widget" \
        || ! grep -Fq 'organicBaseRadius: root.organicBaseRadius' "$visualizer_widget" \
        || ! grep -Fq 'root.organicCoverSize / root.organicRenderOverscan + 0.078' "$visualizer_widget" \
        || ! grep -Fq '_organicArtIdentity' "$visualizer_widget" \
        || ! grep -Fq '?inir_art=' "$visualizer_widget" \
        || ! grep -Fq '_organicSilentPoints' "$visualizer_widget" \
        || ! grep -Fq '? root._organicPresent' "$visualizer_widget" \
        || ! grep -Fq 'root.paletteMode === "album"' "$visualizer_widget" \
        || ! grep -Fq 'id: albumArtworkQuantizer' "$visualizer_widget" \
        || ! grep -Fq 'organicSensitivitySetting <= 0.4' "$visualizer_widget" \
        || ! grep -Fq 'text: Translation.tr("Smoothing")' "$visualizer_widget" \
        || ! grep -Fq 'background.widgets.visualizer.smoothing' "$visualizer_widget" \
        || grep -Fq 'background.widgets.mediaControls.' "$visualizer_widget" \
        || ! grep -Fq 'Idle motion' "$visualizer_settings"; then
    printf 'FAIL: Organic visualizer can regress to in-card media geometry or lose cover/motion controls\n' >&2
    exit 1
fi

nightlight_service="$runtime_root/services/Hyprsunset.qml"
if ! grep -Fq 'inir-wlsunset.service' "$nightlight_service" \
        || grep -Fq 'Quickshell.execDetached(["/usr/bin/wlsunset"' "$nightlight_service"; then
    printf 'FAIL: Niri night light can regress to leaking wlsunset inside inir.service\n' >&2
    exit 1
fi

audio_layer="$runtime_root/modules/common/widgets/AudioVisualizerLayer.qml"
media_layer="$runtime_root/modules/mediaControls/components/MediaVisualizerOverlay.qml"
if [[ ! -f "$audio_layer" || ! -f "$media_layer" ]] \
        || ! grep -Fq 'CavaTheme.visualizerColors' "$audio_layer" \
        || ! grep -Fq 'CavaService.normalizationCeiling' "$media_layer" \
        || ! grep -Fq 'visualizerType: root.visualizerType' "$media_layer" \
        || grep -R -Eq 'WaveVisualizer|CavaVisualizer|maxVisualizerValue: 1000' \
            "$runtime_root/modules/mediaControls/presets"; then
    printf 'FAIL: desktop media visualizers are no longer sharing the Cava/Organic renderer contract\n' >&2
    exit 1
fi
organic_qsb="$runtime_root/modules/common/widgets/OrganicAudioBlob.frag.qsb"
if [[ ! -s "$organic_qsb" ]] \
        || ! grep -Fq 'property real pulseStrength' "$runtime_root/modules/common/widgets/OrganicAudioBlob.qml"; then
    printf 'FAIL: Organic visualizer pulse renderer/shader asset is missing\n' >&2
    exit 1
fi

step "launcher resolution"
bash "$launcher" path >/dev/null
bash "$launcher" status >/dev/null

step "runit service controls"
runit_test_root="$(mktemp -d)"
mkdir -p "$runit_test_root/bin" "$runit_test_root/config/service/inir" "$runit_test_root/home"
printf '#!/bin/sh\nexit 0\n' > "$runit_test_root/config/service/inir/run"
cat > "$runit_test_root/bin/sv" <<'SH'
#!/bin/sh
printf '%s\n' "$*" > "$INIR_TEST_SV_LOG"
SH
cat > "$runit_test_root/bin/systemctl" <<'SH'
#!/bin/sh
: > "$INIR_TEST_SYSTEMCTL_CALLED"
exit 1
SH
chmod +x "$runit_test_root/config/service/inir/run" "$runit_test_root/bin/sv" "$runit_test_root/bin/systemctl"
if ! (
    export HOME="$runit_test_root/home"
    export XDG_CONFIG_HOME="$runit_test_root/config"
    export XDG_RUNTIME_DIR="$runit_test_root/runtime"
    export PATH="$runit_test_root/bin:$PATH"
    export INIR_TEST_SV_LOG="$runit_test_root/sv.log"
    export INIR_TEST_SYSTEMCTL_CALLED="$runit_test_root/systemctl.called"
    "$launcher" service restart
); then
    printf 'FAIL: runit service restart command failed\n' >&2
    rm -rf "$runit_test_root"
    exit 1
fi
if [[ "$(<"$runit_test_root/sv.log")" != "restart $runit_test_root/config/service/inir" ]] \
        || [[ -e "$runit_test_root/systemctl.called" ]]; then
    printf 'FAIL: runit service restart did not use sv exclusively\n' >&2
    rm -rf "$runit_test_root"
    exit 1
fi
rm -rf "$runit_test_root"

step "non-systemd runtime adapters"
shell_exec="$runtime_root/modules/common/functions/ShellExec.qml"
memory_service="$runtime_root/services/MemoryPressureService.qml"
tray_service="$runtime_root/services/TrayService.qml"
session_service="$runtime_root/modules/common/functions/Session.qml"
idle_service="$runtime_root/services/Idle.qml"
cursor_helper="$runtime_root/scripts/niri-config.py"
gtk_theme="$runtime_root/scripts/colors/apply-gtk-theme.sh"
if ! grep -Fq 'service", "restart' "$memory_service" \
        || ! grep -Fq 'inir-xembedsniproxy' "$tray_service" \
        || ! grep -Fq 'sv up' "$tray_service" \
        || ! grep -Fq 'xembed_service_dir' "$runtime_root/sdata/lib/functions.sh" \
        || ! grep -Fq 'chpst -e "\$TURNSTILE_ENV_DIR"' "$runtime_root/sdata/lib/functions.sh" \
        || ! grep -Fq -- '--ignore-inhibitors' "$session_service" \
        || ! grep -Fq -- '--ignore-inhibitors suspend' "$idle_service" \
        || grep -Fq 'systemctl", "suspend' "$session_service" \
        || grep -Fq 'systemctl suspend' "$idle_service" \
        || ! grep -Fq 'dbus-update-activation-environment' "$cursor_helper" \
        || ! grep -Fq 'systemd/private' "$gtk_theme"; then
    printf 'FAIL: non-systemd runtime adapters are incomplete\n' >&2
    exit 1
fi
if grep -Fq 'systemctl --user show-environment' "$tray_service" \
        && ! grep -Fq 'systemd/private' "$tray_service"; then
    printf 'FAIL: XEmbed runtime predicate is not socket-gated\n' >&2
    exit 1
fi
if ! grep -Fq 'systemd_user_manager_usable' "$shell_exec" \
        || ! grep -Fq 'systemd_user_manager_usable" = true' "$shell_exec"; then
    printf 'FAIL: application launcher can use systemd-run without a usable manager\n' >&2
    exit 1
fi

step "application launch environment"
# XWayland is not guaranteed to own :0. Preserve live DISPLAY discovery and validation.
# These checks are conditional on the usable systemd user manager predicate (ADR-0002).
# In the reference implementation (systemd path), the predicate holds.
shell_exec="$runtime_root/modules/common/functions/ShellExec.qml"
inir_launcher="$runtime_root/scripts/inir"
if has_usable_systemd_user_manager; then
    if ! grep -Fq 'systemctl --user show-environment' "$shell_exec" \
            || ! grep -Fq '_manager_display="$(manager_value DISPLAY)"' "$shell_exec" \
            || ! grep -Fq 'valid_display "$DISPLAY"' "$shell_exec" \
            || ! grep -Fq 'for _x in /tmp/.X11-unix/X*' "$shell_exec"; then
        printf 'FAIL: application launches do not recover the live XWayland DISPLAY environment\n' >&2
        exit 1
    fi
    if ! grep -Fq 'vars_to_import+=("DISPLAY=$DISPLAY")' "$inir_launcher" \
            || ! grep -Fq 'for _xsock in /tmp/.X11-unix/X*' "$inir_launcher" \
            || ! grep -Fq 'systemctl --user set-environment "${vars_to_import[@]}"' "$inir_launcher"; then
        printf 'FAIL: session environment does not publish the XWayland DISPLAY to the user manager\n' >&2
        exit 1
    fi
else
    printf 'SKIP: systemd user manager predicate false — skipping systemd-specific environment checks\n'
fi
files_stage="$runtime_root/sdata/subcmd-install/3.files.sh"
startup_kdl="$runtime_root/defaults/niri/config.d/50-startup.kdl"
if grep -Fq 'spawn-sh-at-startup "exec runsvdir ~/.config/service"' "$startup_kdl" \
        || ! grep -Fq 'reconcile_inir_supervisor' "$files_stage" \
        || ! grep -Fq 'BEGIN inir-runsvdir-fallback' "$runtime_root/sdata/lib/functions.sh" \
        || ! grep -Fq 'runsvdir ~/.config/service' "$runtime_root/sdata/lib/functions.sh"; then
    printf 'FAIL: startup supervisor template/injection contract is invalid\n' >&2
    exit 1
fi
if ! grep -Fq 'is_using_runit_supervisor && return 0' "$inir_launcher" \
        || ! grep -Fq 'sv up "${XDG_CONFIG_HOME:-$HOME/.config}/service/inir"' "$inir_launcher"; then
    printf 'FAIL: runit paths are not isolated from systemd\n' >&2
    exit 1
fi
if grep -Fq 'MALLOC_ARENA_MAX' "$shell_exec" \
        || grep -Fq 'MALLOC_MMAP_THRESHOLD_' "$shell_exec"; then
    printf 'FAIL: application launch policy still carries retired allocator handling\n' >&2
    exit 1
fi

orbit_stage="$runtime_root/modules/overview/OrbitOrbitalStage.qml"
orbit_stage_view="$runtime_root/modules/overview/OverviewNiriWidget.qml"
orbit_studio="$runtime_root/modules/overview/OrbitStudio.qml"
if ! grep -Fq 'z: isCore ? 100 : 20 + workspaceIndex * 0.01' "$orbit_stage" \
        || [[ "$(grep -c 'NumberAnimation { duration: root.transitionDurationMs; easing.type: root.navigationEasingType }' "$orbit_stage")" -lt 5 ]]; then
    printf 'FAIL: Orbit orbital navigation no longer tracks geometry/depth continuously\n' >&2
    exit 1
fi
if ! grep -Fq 'retainWhileLoading: true' "$orbit_stage" \
        || ! grep -Fq 'retainWhileLoading: true' "$orbit_stage_view" \
        || grep -Fq 'sourceSize.width: Math.max(1, Math.round(width * 2))' "$orbit_stage" \
        || grep -Fq 'sourceSize.width: Math.max(1, Math.round(width * 2))' "$orbit_stage_view"; then
    printf 'FAIL: Orbit preview decoding can reload during animated geometry changes\n' >&2
    exit 1
fi
pill_notifs="$runtime_root/modules/pill/PillNotifs.qml"
if ! grep -Fq 'image://qsimage/' "$pill_notifs"; then
    printf 'FAIL: Pill notification history can reuse expired Quickshell image handles\n' >&2
    exit 1
fi

preview_service="$runtime_root/services/WindowPreviewService.qml"
preview_capture="$runtime_root/scripts/capture-windows.sh"
if ! grep -Fq 'restore_saved_clipboard' "$preview_capture" \
        || ! grep -A8 -F 'screenshot-window --id "$id"' "$preview_capture" | grep -Fq 'restore_saved_clipboard'; then
    printf 'FAIL: window preview capture can leave Niri screenshot PNGs in the user clipboard\n' >&2
    exit 1
fi
preview_image_store="$runtime_root/scripts/clipboard-image-store.sh"
if [[ ! -x "$preview_image_store" ]] \
        || ! grep -Fq 'inir-window-preview-capture-' "$preview_capture" \
        || ! grep -Fq 'inir-window-preview-capture-' "$preview_image_store" \
        || ! grep -Fq 'clipboard-image-store.sh' "$runtime_root/defaults/niri/config.d/50-startup.kdl"; then
    printf 'FAIL: internal window previews can leak into cliphist image history\n' >&2
    exit 1
fi
if ! grep -Fq 'previewRefreshTimer' "$runtime_root/modules/dock/DockPreview.qml" \
        || ! grep -Fq 'pendingPreviewIds' "$runtime_root/modules/dock/DockPreview.qml" \
        || ! grep -Fq 'hoverDelayTimer.stop()' "$runtime_root/modules/dock/DockAppButton.qml"; then
    printf 'FAIL: dock clicks can race window-preview capture and user paste\n' >&2
    exit 1
fi
if ! grep -Fq 'windowPreviewCaptureActive' "$runtime_root/services/Notifications.qml" \
        || ! grep -Fq 'paste the image from the clipboard' "$runtime_root/services/Notifications.qml"; then
    printf 'FAIL: internal Niri preview screenshot notifications are not suppressed safely\n' >&2
    exit 1
fi
if ! grep -Fq 'requestedWindowMaxAgeMs' "$preview_service" \
        || ! grep -Fq 'markPreviewDirty(root.lastFocusedWindowId)' "$preview_service" \
        || ! grep -Fq '"-printf", "%f\\t%T@\\n"' "$preview_service" \
        || ! grep -Fq 'corePreviewFreshnessMs: 10000' "$orbit_stage" \
        || ! grep -Fq 'satellitePreviewFreshnessMs: 45000' "$orbit_stage" \
        || ! grep -Fq 'mipmap: false' "$orbit_stage" \
        || ! grep -Fq 'max_concurrent=1' "$preview_capture"; then
    printf 'FAIL: Orbit preview freshness/quality policy regressed\n' >&2
    exit 1
fi
home_nix_module="$runtime_root/nix/home-module.nix"
if ! grep -Fq 'path="$(command -v "$name" 2>/dev/null || true)"' "$preview_capture" \
        || grep -Fq '[[ ! -x "$bin" ]]' "$preview_capture" \
        || ! grep -Fq 'PATH = lib.makeBinPath ([ cfg.package ] ++ cfg.extraPackages);' "$home_nix_module"; then
    printf 'FAIL: packaged Nix preview dependencies are not resolved through the service PATH\n' >&2
    exit 1
fi
if grep -Fq 'NavigationFineControls { visible: !root.workspaceMode }' "$orbit_studio" \
        || grep -Fq 'PresentationFineControls { visible: !root.workspaceMode }' "$orbit_studio"; then
    printf 'FAIL: Orbit Studio Motion exposes advanced tuning in the primary workflow\n' >&2
    exit 1
fi

terminal_launcher="$runtime_root/scripts/launch-terminal.sh"
browser_launcher_block="$(sed -n '/^launch_configured_browser()/,/^}/p' "$inir_launcher")"
if grep -Fq 'systemd-run --user --scope' "$terminal_launcher" \
        || grep -Fq 'systemd-run --user --scope' <<< "$browser_launcher_block"; then
    printf 'FAIL: Niri terminal/browser launchers create a redundant nested systemd scope\n' >&2
    exit 1
fi

if [[ -e "$runtime_root/sdata/migrations/037-scope-quickshell-malloc-env.sh" ]]; then
    printf 'FAIL: allocator cleanup was added as a second migration instead of update/doctor repair\n' >&2
    exit 1
fi

step "migration predicate guards"
migration_021="$runtime_root/sdata/migrations/021-systemd-single-instance.sh"
migration_022="$runtime_root/sdata/migrations/022-service-compositor-wants.sh"
migration_test_root="$(mktemp -d)"
mkdir -p "$migration_test_root/bin" "$migration_test_root/config" "$migration_test_root/home"
cat > "$migration_test_root/bin/systemctl" <<'SH'
#!/bin/sh
: > "$INIR_TEST_SYSTEMCTL_CALLED"
exit 1
SH
chmod +x "$migration_test_root/bin/systemctl"
for migration_file in "$migration_021" "$migration_022"; do
    if ! (
        export HOME="$migration_test_root/home"
        export REPO_ROOT="$runtime_root"
        export XDG_CONFIG_HOME="$migration_test_root/config"
        export XDG_RUNTIME_DIR="$migration_test_root/runtime"
        export PATH="$migration_test_root/bin:$PATH"
        export INIR_TEST_SYSTEMCTL_CALLED="$migration_test_root/systemctl.called"
        # Arrange: no user-manager socket or migration state.
        # Act: evaluate the migration in the non-systemd profile.
        # Assert: it is a no-op without invoking systemctl.
        source "$migration_file"
        migration_check && exit 1
        migration_apply
    ); then
        printf 'FAIL: %s is not a non-systemd no-op\n' "$(basename "$migration_file")" >&2
        rm -rf "$migration_test_root"
        exit 1
    fi
done
if [[ -e "$migration_test_root/systemctl.called" ]]; then
    printf 'FAIL: non-systemd migrations invoked systemctl\n' >&2
    rm -rf "$migration_test_root"
    exit 1
fi
rm -rf "$migration_test_root"

step "rsync failure propagation"
# rsync_dir__sync must fail when rsync fails, not succeed via awk pipe
# Need ask=false for non-interactive x function behavior
ask=false
source "$runtime_root/sdata/lib/functions.sh"
rsync_test_root="$(mktemp -d)"
mkdir -p "$rsync_test_root/bin" "$rsync_test_root/src/dir" "$rsync_test_root/dst"
echo "content" > "$rsync_test_root/src/dir/file.txt"
# Fake rsync that fails
cat > "$rsync_test_root/bin/rsync" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$rsync_test_root/bin/rsync"
export PATH="$rsync_test_root/bin:$PATH"
export INSTALLED_LISTFILE="$rsync_test_root/installed.list"
if rsync_dir__sync "$rsync_test_root/src" "$rsync_test_root/dst" 2>/dev/null; then
    printf 'FAIL: rsync_dir__sync succeeded despite rsync failure\n' >&2
    rm -rf "$rsync_test_root"
    exit 1
fi
# Verify no manifest was written on failure
if [[ -f "$rsync_test_root/installed.list" && -s "$rsync_test_root/installed.list" ]]; then
    printf 'FAIL: installed.list written despite rsync failure\n' >&2
    rm -rf "$rsync_test_root"
    exit 1
fi
rm -rf "$rsync_test_root"

step "supervisor reconciliation helper"
# Need ask=false for non-interactive x function behavior
ask=false
source "$runtime_root/sdata/lib/functions.sh"
# Test runsvdir path (no systemd and no turnstile)
reconcile_test_root="$(mktemp -d)"
mkdir -p "$reconcile_test_root/bin" "$reconcile_test_root/home/.local/bin" "$reconcile_test_root/home/.config/niri/config.d" "$reconcile_test_root/var/service"
cat > "$reconcile_test_root/home/.local/bin/inir" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$reconcile_test_root/home/.local/bin/inir"
cat > "$reconcile_test_root/bin/systemctl" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$reconcile_test_root/bin/systemctl"
cat > "$reconcile_test_root/bin/sv" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$reconcile_test_root/bin/sv"
# Create startup KDL file (required for reconcile to render)
cat > "$reconcile_test_root/home/.config/niri/config.d/50-startup.kdl" <<'KDL'
// 50 — Processes spawned at login
spawn-at-startup "bash" "-c" "systemctl --user import-environment XDG_MENU_PREFIX && kbuildsycoca6"
KDL
export HOME="$reconcile_test_root/home"
export XDG_BIN_HOME="$reconcile_test_root/home/.local/bin"
export XDG_CONFIG_HOME="$reconcile_test_root/home/.config"
export XDG_RUNTIME_DIR="$reconcile_test_root/runtime"
export INIR_TURNSTILED_SERVICE_PATH="$reconcile_test_root/var/service/turnstiled"
export PATH="$reconcile_test_root/bin:$PATH"
# No systemd socket = predicate false = runsvdir
if ! reconcile_inir_supervisor | grep -q '^runsvdir$'; then
    printf 'FAIL: reconcile_inir_supervisor did not select runsvdir\n' >&2
    rm -rf "$reconcile_test_root"
    exit 1
fi
# Verify runit service created
if [[ ! -x "$reconcile_test_root/home/.config/service/inir/run" ]]; then
    printf 'FAIL: runit service not created\n' >&2
    rm -rf "$reconcile_test_root"
    exit 1
fi
# Verify KDL has runsvdir block
startup_kdl="$reconcile_test_root/home/.config/niri/config.d/50-startup.kdl"
if ! grep -q 'runsvdir ~/.config/service' "$startup_kdl"; then
    printf 'FAIL: KDL missing runsvdir block\n' >&2
    rm -rf "$reconcile_test_root"
    exit 1
fi
# Idempotent: second run should not change KDL
cp "$startup_kdl" "$startup_kdl.bak"
reconcile_inir_supervisor >/dev/null
if ! diff -q "$startup_kdl" "$startup_kdl.bak" >/dev/null; then
    printf 'FAIL: second reconcile_inir_supervisor changed KDL\n' >&2
    diff -u "$startup_kdl.bak" "$startup_kdl" >&2
    rm -rf "$reconcile_test_root"
    exit 1
fi
rm -rf "$reconcile_test_root"

step "turnstile supervisor selection"
turnstile_test_root="$(mktemp -d)"
mkdir -p "$turnstile_test_root/bin" "$turnstile_test_root/home/.local/bin" "$turnstile_test_root/home/.config/niri/config.d" "$turnstile_test_root/var/service/turnstiled"
mkdir -p "$turnstile_test_root/examples"
printf '#!/bin/sh\nexit 0\n' > "$turnstile_test_root/examples/dbus.run"
printf '#!/bin/sh\nexit 0\n' > "$turnstile_test_root/examples/dbus.check"
chmod +x "$turnstile_test_root/examples/dbus.run" "$turnstile_test_root/examples/dbus.check"
cat > "$turnstile_test_root/home/.local/bin/inir" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$turnstile_test_root/home/.local/bin/inir"
cat > "$turnstile_test_root/bin/systemctl" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$turnstile_test_root/bin/systemctl"
cat > "$turnstile_test_root/bin/sv" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$turnstile_test_root/bin/sv"
cat > "$turnstile_test_root/bin/pgrep" <<'SH'
#!/bin/sh
printf '123\n'
SH
chmod +x "$turnstile_test_root/bin/pgrep"
cat > "$turnstile_test_root/home/.config/niri/config.d/50-startup.kdl" <<'KDL'
// BEGIN inir-runsvdir-fallback
spawn-sh-at-startup "exec runsvdir ~/.config/service"
// END inir-runsvdir-fallback
KDL
if ! (
    export HOME="$turnstile_test_root/home"
    export XDG_BIN_HOME="$turnstile_test_root/home/.local/bin"
    export XDG_CONFIG_HOME="$turnstile_test_root/home/.config"
    export XDG_RUNTIME_DIR="$turnstile_test_root/runtime"
    export INIR_TURNSTILED_SERVICE_PATH="$turnstile_test_root/var/service/turnstiled"
    export INIR_TURNSTILE_EXAMPLES="$turnstile_test_root/examples"
    export PATH="$turnstile_test_root/bin:$PATH"
    result="$(reconcile_inir_supervisor)"
    [[ "$result" == turnstile ]]
    turnstile_run="$turnstile_test_root/home/.config/service/inir/run"
    turnstile_conf="$turnstile_test_root/home/.config/service/turnstile-ready/conf"
    grep -Fq 'chpst -e "$TURNSTILE_ENV_DIR"' "$turnstile_run"
    grep -Fxq 'core_services="dbus"' "$turnstile_conf"
    ! grep -Fq 'runsvdir' "$turnstile_test_root/home/.config/niri/config.d/50-startup.kdl"
    cp "$turnstile_run" "$turnstile_run.before"
    cp "$turnstile_conf" "$turnstile_conf.before"
    reconcile_inir_supervisor >/dev/null
    cmp -s "$turnstile_run" "$turnstile_run.before"
    cmp -s "$turnstile_conf" "$turnstile_conf.before"
    if INIR_TURNSTILE_EXAMPLES="$turnstile_test_root/missing" configure_turnstile_user_services; then
        exit 1
    fi
); then
    printf 'FAIL: active turnstile was not selected exclusively\n' >&2
    rm -rf "$turnstile_test_root"
    exit 1
fi
rm -rf "$turnstile_test_root"

step "Void dependency profile"
void_deps="$runtime_root/sdata/dist-void/install-deps.sh"
for pkg in rsync base-devel pkg-config cairo-devel python3-devel glib-devel gobject-introspection python3-gobject-devel libffi-devel; do
    if ! grep -q "^[[:space:]]*$pkg$" "$void_deps"; then
        printf 'FAIL: Void base packages missing %s\n' "$pkg" >&2
        exit 1
    fi
done
# ONLY_MISSING_DEPS handling present
if ! grep -q 'ONLY_MISSING_DEPS' "$void_deps"; then
    printf 'FAIL: Void installer missing ONLY_MISSING_DEPS handling\n' >&2
    exit 1
fi

step "turnstile profile contracts"
if ! grep -Fq 'manage_rundir = no' "$runtime_root/sdata/subcmd-install/2.setups.sh"; then
    printf 'FAIL: Void setup does not configure turnstile for elogind\n' >&2
    exit 1
fi
if ! grep -Fq "if elevate sh -c" "$runtime_root/sdata/subcmd-install/2.setups.sh"; then
    printf 'FAIL: Void service setup does not fail on elevation errors\n' >&2
    exit 1
fi
if ! grep -Fq 'turnstile-ready/conf' "$runtime_root/sdata/lib/functions.sh"; then
    printf 'FAIL: Void setup does not configure turnstile-ready core services\n' >&2
    exit 1
fi
if ! grep -Fq 'Could not configure the iNiR supervisor' "$runtime_root/sdata/subcmd-install/3.files.sh"; then
    printf 'FAIL: file installation does not propagate supervisor setup failures\n' >&2
    exit 1
fi

migration_lib="$runtime_root/sdata/lib/migrations.sh"
repair_lib="$runtime_root/sdata/lib/functions.sh"
doctor_lib="$runtime_root/sdata/lib/doctor.sh"
if ! grep -Fq '"014-malloc-arena-optimization"' "$migration_lib" \
        || ! grep -Fq 'is_migration_retired "$migration_id" && return 1' "$migration_lib" \
        || ! grep -Fq 'repair_legacy_quickshell_malloc_environment()' "$repair_lib" \
        || ! grep -Fq 'repair_legacy_quickshell_malloc_environment' "$runtime_root/setup" \
        || ! grep -Fq 'repair_legacy_quickshell_malloc_environment' "$doctor_lib"; then
    printf 'FAIL: retired allocator migration is not repaired through install/update/doctor\n' >&2
    exit 1
fi

if command -v python3 &>/dev/null && [[ -f "$runtime_root/scripts/lib/generate-ipc-registry.py" ]]; then
    step "IPC registry freshness"
    python3 "$runtime_root/scripts/lib/generate-ipc-registry.py" --check
fi

if [[ "$run_runtime" == true ]]; then
    step "runtime restart"
    bash "$runtime_root/scripts/inir" kill >/dev/null 2>&1 || true
    sleep 1
    bash "$runtime_root/scripts/inir" run >/tmp/inir-test-local-runtime.log 2>&1 &
    sleep 3

    step "runtime logs"
    bash "$runtime_root/scripts/inir" logs

    step "runtime filtered errors"
    bash "$launcher" logs --full | grep -iE 'error|ReferenceError|TypeError|binding loop' | tail -80 || true

    step "launcher ipc"
    bash "$launcher" ipc shellUpdate diagnose >/dev/null
fi

step "agent artifact leak guard"
# The source tree legitimately has AGENTS.md/CLAUDE.md in payload dirs.
# Distribution stripping removes them post-copy. Validate the stripping
# contracts exist so no install path can miss them.
leak_guard=0
agent_files=(AGENTS.md CLAUDE.md CODEX.md PI.md codemap.md .mcp.json opencode.json skills-lock.json)
agent_dirs=(.claude .factory .opencode .codex .agents .codebase-memory .impeccable .pi-subagents)

# Makefile must strip agent files after cp -a
for agent_file in "${agent_files[@]}"; do
    if ! grep -q -- "-name $agent_file" "$runtime_root/Makefile" 2>/dev/null; then
        printf 'LEAK GUARD: Makefile missing strip for %s\n' "$agent_file" >&2
        leak_guard=1
    fi
done
for agent_dir in "${agent_dirs[@]}"; do
    if ! grep -q -- "-name $agent_dir" "$runtime_root/Makefile" 2>/dev/null; then
        printf 'LEAK GUARD: Makefile missing strip for %s/\n' "$agent_dir" >&2
        leak_guard=1
    fi
done
if ! grep -q -- '-delete' "$runtime_root/Makefile" 2>/dev/null; then
    printf 'LEAK GUARD: Makefile missing agent-file strip after payload copy\n' >&2
    leak_guard=1
fi
# rsync-based install (sdata/lib/functions.sh) must exclude agent files
if [[ -f "$runtime_root/sdata/lib/functions.sh" ]]; then
    for agent_file in "${agent_files[@]}"; do
        [[ "$agent_file" == .mcp.json || "$agent_file" == opencode.json ]] && continue
        if ! grep -q -- "--exclude='$agent_file'" "$runtime_root/sdata/lib/functions.sh" 2>/dev/null; then
            printf 'LEAK GUARD: sdata/lib/functions.sh missing %s rsync exclude\n' "$agent_file" >&2
            leak_guard=1
        fi
    done
    for agent_dir in "${agent_dirs[@]}"; do
        if ! grep -q -- "--exclude='$agent_dir/'" "$runtime_root/sdata/lib/functions.sh" 2>/dev/null; then
            printf 'LEAK GUARD: sdata/lib/functions.sh missing %s/ rsync exclude\n' "$agent_dir" >&2
            leak_guard=1
        fi
    done
fi
# Agent-only directories must not appear in payload manifests
for agent_dir in "${agent_dirs[@]}"; do
    if grep -qx "$agent_dir" "$runtime_root/sdata/runtime-payload-dirs.txt" 2>/dev/null; then
        printf 'LEAK: %s listed in runtime-payload-dirs.txt\n' "$agent_dir" >&2
        leak_guard=1
    fi
done
for agent_file in "${agent_files[@]}"; do
    if grep -qx "$agent_file" "$runtime_root/sdata/runtime-root-files.txt" 2>/dev/null; then
        printf 'LEAK: %s listed in runtime-root-files.txt\n' "$agent_file" >&2
        leak_guard=1
    fi
done
# Maintainer and development tooling must be stripped by both install paths.
dev_tooling_files=(release.sh wiki-sync.sh verify-docs.sh qml-check.fish
    test-local-distribution.sh test-mascot-pack-flow.sh)
dev_tooling_dirs=(agents tools l10n)
for tool in "${dev_tooling_files[@]}" "${dev_tooling_dirs[@]}"; do
    pattern="--exclude='/$tool'"
    [[ " ${dev_tooling_dirs[*]} " == *" $tool "* ]] && pattern="--exclude='/$tool/'"
    if ! grep -q -- "$pattern" "$runtime_root/sdata/lib/functions.sh" 2>/dev/null; then
        printf 'LEAK GUARD: sdata/lib/functions.sh missing %s rsync exclude\n' "$tool" >&2
        leak_guard=1
    fi
    if ! grep -q -- "/$tool" "$runtime_root/Makefile" 2>/dev/null; then
        printf 'LEAK GUARD: Makefile missing strip for %s\n' "$tool" >&2
        leak_guard=1
    fi
done

for pkgbuild in "$runtime_root/distro/arch/inir-shell/PKGBUILD" "$runtime_root/distro/arch/inir-shell-git/PKGBUILD"; do
    [[ -f "$pkgbuild" ]] || continue
    for agent_file in "${agent_files[@]}"; do
        if ! grep -q -- "-name $agent_file" "$pkgbuild" 2>/dev/null; then
            printf 'LEAK GUARD: %s missing strip for %s\n' "$(basename "$(dirname "$pkgbuild")")/PKGBUILD" "$agent_file" >&2
            leak_guard=1
        fi
    done
    for agent_dir in "${agent_dirs[@]}"; do
        if ! grep -q -- "-name $agent_dir" "$pkgbuild" 2>/dev/null; then
            printf 'LEAK GUARD: %s missing strip for %s/\n' "$(basename "$(dirname "$pkgbuild")")/PKGBUILD" "$agent_dir" >&2
            leak_guard=1
        fi
    done
done

if [[ "$leak_guard" -eq 1 ]]; then
    printf 'FAIL: agent artifact distribution guard failed\n' >&2
    exit 1
fi

printf '\nAll local distribution checks passed.\n'
