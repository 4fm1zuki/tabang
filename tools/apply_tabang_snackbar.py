"""Point every SnackBar at TabangSnackBar (3 s, swipeable in either direction).

Reads and writes UTF-8 so files containing em dashes or "Niño" are untouched
apart from the intended rename. Run from the repository root:

    python tools/apply_tabang_snackbar.py
"""

from __future__ import annotations

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

SKIP = {"common.dart"}  # holds the class itself

changed: list[str] = []
for folder, _, files in os.walk(LIB):
    for name in files:
        if not name.endswith(".dart") or name in SKIP:
            continue
        path = os.path.join(folder, name)
        with open(path, encoding="utf-8") as handle:
            original = handle.read()
        # "SnackBar(" only ever introduces a bar; SnackBarAction( and
        # SnackBarThemeData( have different text, and the class definition is
        # "extends SnackBar {".
        updated = original.replace("SnackBar(", "TabangSnackBar(")
        if updated != original:
            with open(path, "w", encoding="utf-8", newline="") as handle:
                handle.write(updated)
            changed.append(os.path.relpath(path, ROOT))

print(f"updated {len(changed)} files")
for name in changed:
    print(" ", name)
