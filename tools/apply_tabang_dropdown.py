"""Swap DropdownButtonFormField for TabangDropdown across lib/.

The call shapes match, so this is a rename plus the import. Run from the
repository root:

    python tools/apply_tabang_dropdown.py
"""

from __future__ import annotations

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")
DROP_DOWN = os.path.join(LIB, "widgets", "tabang_dropdown.dart")
NEEDLE = "tabang_dropdown.dart"

changed: list[str] = []
for folder, _, files in os.walk(LIB):
    for name in files:
        if not name.endswith(".dart"):
            continue
        path = os.path.join(folder, name)
        if os.path.abspath(path) == os.path.abspath(DROP_DOWN):
            continue
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        original = text

        text = text.replace("DropdownButtonFormField<", "TabangDropdown<")

        if "TabangDropdown<" in text and NEEDLE not in text:
            relative = os.path.relpath(DROP_DOWN, folder).replace("\\", "/")
            lines = text.split("\n")
            last_import = max(
                (i for i, line in enumerate(lines) if line.startswith("import ")),
                default=-1,
            )
            lines.insert(last_import + 1, f"import '{relative}';")
            text = "\n".join(lines)

        if text != original:
            with open(path, "w", encoding="utf-8", newline="") as handle:
                handle.write(text)
            changed.append(os.path.relpath(path, ROOT))

print(f"updated {len(changed)} files")
for entry in changed:
    print(" ", entry)
