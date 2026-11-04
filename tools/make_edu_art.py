"""Draw original educational illustrations for TABANG.

These flat, brand-coloured cards supplement the bundled public-domain
photographs. They are original artwork, so no external credit is required and
the app still works completely offline.

Usage:
    python tools/make_edu_art.py
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images" / "educational"
W, H = 1200, 760


def rounded_gradient(top: str, bottom: str) -> Image.Image:
    img = Image.new("RGB", (1, H))
    px = img.load()
    a = tuple(int(top[i:i + 2], 16) for i in (1, 3, 5))
    b = tuple(int(bottom[i:i + 2], 16) for i in (1, 3, 5))
    for y in range(H):
        t = y / (H - 1)
        px[0, y] = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
    return img.resize((W, H))


def base(top: str, bottom: str) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = rounded_gradient(top, bottom).convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    # soft bubbles
    for cx, cy, r, alpha in [
        (110, 120, 150, 38),
        (1090, 170, 190, 45),
        (1010, 680, 230, 28),
        (260, 690, 190, 22),
    ]:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, alpha))
    return img, d


def drop(d: ImageDraw.ImageDraw, cx: int, cy: int, size: int, fill: str = "#B3261E"):
    r = size
    d.ellipse((cx - r, cy - int(r * 0.18), cx + r, cy + int(r * 1.82)), fill=fill)
    d.polygon(
        [
            (cx, cy - int(r * 2.25)),
            (cx - int(r * 0.95), cy + int(r * 0.25)),
            (cx + int(r * 0.95), cy + int(r * 0.25)),
        ],
        fill=fill,
    )


def heart(d: ImageDraw.ImageDraw, cx: int, cy: int, size: int, fill: str):
    r = size // 2
    d.ellipse((cx - r, cy - r, cx, cy + r), fill=fill)
    d.ellipse((cx, cy - r, cx + r, cy + r), fill=fill)
    d.polygon([(cx - r, cy + r // 3), (cx + r, cy + r // 3), (cx, cy + r * 2)], fill=fill)


def person(d: ImageDraw.ImageDraw, cx: int, cy: int, scale: float, color: str):
    d.ellipse((cx - 42 * scale, cy - 100 * scale, cx + 42 * scale, cy - 16 * scale), fill=color)
    d.rounded_rectangle(
        (cx - 62 * scale, cy - 2 * scale, cx + 62 * scale, cy + 120 * scale),
        radius=34 * scale,
        fill=color,
    )


def benefits():
    img, d = base("#FFF4F1", "#FBE4DE")
    # central heart + drop
    heart(d, 600, 315, 240, "#B3261E")
    drop(d, 600, 280, 54, "#FFFFFF")
    # three people connected by a line
    d.arc((210, 300, 990, 820), 195, 345, fill="#8C1D18", width=10)
    for i, (cx, color) in enumerate(
        [(250, "#1F5FA8"), (600, "#8C1D18"), (950, "#2F6B4F")]
    ):
        person(d, cx, 560, 0.9, color)
    return img


def help():
    img, d = base("#F2F8F7", "#DFEFEC")
    # two hands (stylised)
    d.rounded_rectangle((180, 430, 700, 610), radius=90, fill="#C98A5D")
    d.rounded_rectangle((500, 430, 1020, 610), radius=90, fill="#DDA57A")
    for x in (260, 350, 440, 780, 870, 960):
        d.rounded_rectangle((x, 380, x + 55, 520), radius=27, fill="#CF9166")
    drop(d, 600, 250, 120, "#B3261E")
    d.ellipse((560, 300, 640, 380), fill="#FFFFFF")
    heart(d, 600, 340, 42, "#B3261E")
    return img


def prepare():
    img, d = base("#FFF9EC", "#F8E8C8")
    # water glass
    d.rounded_rectangle((190, 280, 430, 610), radius=34, fill="#DCE9F8")
    d.rounded_rectangle((190, 400, 430, 610), radius=34, fill="#7FB2E5")
    d.rounded_rectangle((230, 250, 265, 620), radius=16, fill="#FFFFFF")
    # plate / food
    d.ellipse((520, 420, 880, 660), fill="#FFFFFF")
    d.ellipse((560, 450, 840, 620), fill="#D7F0E2")
    d.ellipse((610, 470, 720, 570), fill="#2F6B4F")
    d.ellipse((740, 460, 820, 550), fill="#C25E2A")
    # clock
    d.ellipse((920, 130, 1100, 310), fill="#FFFFFF")
    d.ellipse((942, 152, 1078, 288), outline="#B3261E", width=12)
    d.line((1010, 220, 1010, 172), fill="#B3261E", width=10)
    d.line((1010, 220, 1050, 235), fill="#B3261E", width=10)
    # small drop
    drop(d, 1080, 430, 46, "#B3261E")
    return img


def aftercare():
    img, d = base("#F3F0FB", "#E3DBF3")
    # bed / person resting
    d.rounded_rectangle((190, 430, 900, 610), radius=42, fill="#FFFFFF")
    d.rounded_rectangle((190, 520, 900, 590), radius=30, fill="#C7B7E0")
    d.ellipse((360, 350, 500, 490), fill="#DDA57A")
    d.rounded_rectangle((470, 400, 760, 520), radius=60, fill="#8C1D18")
    d.rounded_rectangle((320, 390, 400, 530), radius=34, fill="#1F5FA8")
    # bandage
    d.rounded_rectangle((630, 610, 750, 660), radius=25, fill="#F7D4B4")
    d.rounded_rectangle((670, 620, 710, 650), radius=12, fill="#FFFFFF")
    # water glass
    d.rounded_rectangle((980, 300, 1090, 550), radius=22, fill="#DCE9F8")
    d.rounded_rectangle((980, 400, 1090, 550), radius=22, fill="#7FB2E5")
    heart(d, 1035, 200, 48, "#B3261E")
    return img


def facts():
    img, d = base("#EEF5FF", "#DCE9F8")
    # red cells
    for cx, cy, r in [(260, 250, 95), (430, 520, 80), (930, 250, 100), (1060, 530, 70), (760, 610, 55)]:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill="#D9553F")
        d.ellipse(
            (cx - int(r * 0.55), cy - int(r * 0.55), cx + int(r * 0.55), cy + int(r * 0.55)),
            fill="#F6B3A6",
        )
    # ABO chart card
    d.rounded_rectangle((450, 140, 810, 500), radius=38, fill="#FFFFFF")
    d.rounded_rectangle((500, 190, 760, 250), radius=18, fill="#B3261E")
    for y in (290, 350, 410):
        d.rounded_rectangle((500, y, 760, y + 40), radius=14, fill="#F3D4CE")
    return img


def eligibility():
    img, d = base("#F4FAF5", "#DDEFE2")
    d.rounded_rectangle((280, 120, 920, 650), radius=44, fill="#FFFFFF")
    d.rounded_rectangle((330, 180, 870, 235), radius=16, fill="#2F6B4F")
    for i, y in enumerate((300, 390, 480, 570)):
        d.rounded_rectangle((370, y, 430, y + 60), radius=18, fill="#2F6B4F")
        d.line((385, y + 30, 405, y + 48), fill="#FFFFFF", width=8)
        d.line((405, y + 48, 440, y + 8), fill="#FFFFFF", width=8)
        d.rounded_rectangle((480, y + 10, 820 - i * 40, y + 50), radius=16, fill="#DDEFE2")
    drop(d, 1010, 470, 60, "#B3261E")
    return img


def drive_pin():
    img, d = base("#FFF4F1", "#F6D9D2")
    # map pin
    d.ellipse((420, 150, 780, 510), fill="#B3261E")
    d.polygon([(480, 430), (720, 430), (600, 680)], fill="#B3261E")
    d.ellipse((505, 235, 695, 425), fill="#FFFFFF")
    drop(d, 600, 260, 58, "#B3261E")
    # location ring
    d.ellipse((300, 560, 900, 700), outline="#8C1D18", width=8)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    art = {
        "edu_benefits.png": benefits,
        "edu_help.png": help,
        "edu_prepare.png": prepare,
        "edu_aftercare.png": aftercare,
        "edu_facts.png": facts,
        "edu_eligibility.png": eligibility,
        "drive_locator.png": drive_pin,
    }
    for name, fn in art.items():
        image = fn()
        image.filter(ImageFilter.SMOOTH).convert("RGB").save(OUT / name, optimize=True)
    print(f"Wrote {len(art)} educational illustrations to {OUT}")


if __name__ == "__main__":
    main()
