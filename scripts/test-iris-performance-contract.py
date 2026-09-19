#!/usr/bin/env python3
"""Structural guards for iRiS lifetime/performance invariants."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
BAR = (ROOT / "modules/iris/bar/IrisBar.qml").read_text(encoding="utf-8")
ISLAND = (ROOT / "modules/iris/bar/IrisIsland.qml").read_text(encoding="utf-8")
STAGE = (ROOT / "modules/iris/stage/IrisStage.qml").read_text(encoding="utf-8")


def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def main() -> int:
    failures: list[str] = []

    require(
        'readonly property bool panelMode: String(Config.options?.iris?.controlCenter?.opens ?? "island") !== "island"' in BAR,
        "external Control Center is no longer gated by panel mode", failures)
    require(
        'GlobalStates.irisMorphOwner === "stage"' in BAR and "controlCentreLoader.externalOpen" in BAR,
        "Stage-origin Control Center path is not preserved", failures)
    require(
        "stage.controlIntent" in BAR and "readonly property bool controlIntent:" in STAGE,
        "floating Controls/Battery intent no longer prewarms the external body", failures)
    require(
        "controlCentreLoader.releaseTimer" in BAR and "controlCentreLoader.resident" in BAR,
        "external Control Center no longer has finite residency", failures)
    require(
        "controlCentreLoader.kept" not in BAR,
        "external Control Center reverted to permanent kept residency", failures)

    require(
        "active: (root.rects[bubbleSlot.index] ?? null) !== null" in STAGE,
        "Stage no longer loads resting bubbles only for floating slots", failures)
    require(
        "model: root.allSlots\n        FloatingBubble" not in STAGE,
        "Stage recreated a FloatingBubble for every registry slot", failures)
    require(
        "Component.onCompleted: bubble.settle()" in STAGE,
        "a lazily created floating bubble never reports its centre or enables move motion", failures)

    require(
        "value: !root.controlsInIsland && (root.pointerOnIsland || root.expanded)" in ISLAND,
        "Island-mode Control Center still warms the external panel", failures)
    require(
        "value: root.settingsIntent" in ISLAND,
        "Settings warm state is no longer driven by explicit intent", failures)
    settings_binding = ISLAND.split('property: "irisSettingsWarm"', 1)[1].split("}", 1)[0]
    require(
        "value: root.settingsIntent" in settings_binding and "value: root.expanded" not in settings_binding,
        "generic Island expansion warms Settings again", failures)
    require(
        "readonly property bool resident: pageItem.current || pageItem.opacity > 0.004" in ISLAND,
        "Island pages lost page-level residency", failures)

    for page_id in ("trayLoader", "controlsLoader", "toolsLoader", "mediaLoader", "activityLoader", "desktopLoader"):
        require(f"id: {page_id}" in ISLAND, f"missing lazy page body {page_id}", failures)

    if failures:
        print("iRiS performance contract failures:")
        for failure in failures:
            print(f"  {failure}")
        return 1

    print("iRiS performance contract: lifetime guards intact")
    return 0


if __name__ == "__main__":
    sys.exit(main())
