#!/usr/bin/env python3
"""iRiS style token guard.

iRiS surfaces read colour, translucency and corner values from
modules/iris/style/IrisStyle.qml (tokens and appearance presets). This guard
fails when a literal slips back into an iRiS consumer:

- hex colours ("#rrggbb") and numeric Qt.rgba(...) colours;
- decimal alpha literals in ColorUtils.applyAlpha(...), including conditional
  branches and variable inks (use fill/text tokens or tintFill/secondaryOf...);
- corner radii written as `N * density` instead of a radius token;
- Qt5Compat.GraphicalEffects imports (use QtQuick.Effects MultiEffect).

A line that genuinely needs a literal (an illustration, a mock preview that
mirrors a style value) carries `// iris-literal: <reason>`. Only iRiS is
checked; ii and Waffle own their own systems.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
IRIS = ROOT / "modules" / "iris"
EXEMPT_DIRS = {IRIS / "style"}

RULES = [
    ("hex colour", re.compile(r'"#[0-9a-fA-F]{3,8}"')),
    ("numeric Qt.rgba", re.compile(r"Qt\.rgba\(\s*[\d.]+\s*,\s*[\d.]+\s*,\s*[\d.]+\s*,")),
    # Any decimal alpha literal inside applyAlpha(...), also inside a condition
    # or on a variable ink: states and label steps are tokens or IrisStyle helpers.
    ("literal alpha", re.compile(r"applyAlpha\((?:[^()]|\([^()]*\))*?[,?:]\s*0?\.\d*[1-9]\d*\s*[):]")),
    # Effects are QtQuick.Effects (MultiEffect): Qt5Compat chains offscreen
    # passes and its hideSource toggles are fragile inside clipping chassis.
    ("Qt5Compat effect", re.compile(r"^\s*import\s+Qt5Compat\.GraphicalEffects")),
    ("literal corner radius", re.compile(
        r"\b\w*[Rr]adius\w*\s*:\s*(?:Math\.round\()?\s*\d+(?:\.\d+)?\s*\*\s*(?:root\.d|stage\.d|IrisStyle\.density)\b")),
]


def main() -> int:
    failures = []
    for path in sorted(IRIS.rglob("*.qml")):
        if any(parent in EXEMPT_DIRS for parent in path.parents):
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if "iris-literal:" in line:
                continue
            for name, pattern in RULES:
                if pattern.search(line):
                    failures.append(f"{path.relative_to(ROOT)}:{number}: {name}: {line.strip()[:140]}")
    if failures:
        print("FAIL: iRiS consumers must use IrisStyle tokens (or mark `// iris-literal: reason`):", file=sys.stderr)
        for failure in failures:
            print("  " + failure, file=sys.stderr)
        return 1
    print("iRiS style tokens: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
