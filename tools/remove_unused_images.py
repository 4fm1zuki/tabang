"""Delete the superseded loose images and their credit entries.

These files were replaced by the per-folder artwork (Learn & Prepare, Blood
Drives, Announcements & Stories); only the credit registry still named them.

Run from the repository root:

    python tools/remove_unused_images.py
"""

from __future__ import annotations

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES = os.path.join(ROOT, "assets", "images")
CREDITS = os.path.join(ROOT, "lib", "core", "image_credits.dart")

# Still in use: the Home hero, and the two community photos the drive cards fall
# back to when a drive has no photograph of its own.
KEEP = {"hero_donation.jpg", "content_drive.jpg", "drive_community.jpg"}

removed_files: list[str] = []
for name in sorted(os.listdir(IMAGES)):
    path = os.path.join(IMAGES, name)
    if not os.path.isfile(path) or name in KEEP:
        continue
    os.remove(path)
    removed_files.append(name)

with open(CREDITS, encoding="utf-8") as handle:
    text = handle.read()

removed_credits: list[str] = []
for name in removed_files:
    pattern = re.compile(
        r"\n  ImageCredit\(\n    asset: 'assets/images/"
        + re.escape(name)
        + r"',.*?\n  \),",
        re.S,
    )
    text, count = pattern.subn("", text)
    if count:
        removed_credits.append(name)

with open(CREDITS, "w", encoding="utf-8", newline="") as handle:
    handle.write(text)

print(f"deleted {len(removed_files)} images, removed {len(removed_credits)} credits")
print("files:", ", ".join(removed_files))
