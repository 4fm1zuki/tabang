"""Generate unique, locally bundled profile illustrations for TABANG.

The prototype ships entirely offline and cannot use third-party portraits for
simulated people: reusing a real person's photograph for a fictional donor or
patient would be misleading. These illustrations are drawn procedurally, one
per account, so every seeded profile has a distinct image and no network or
licensing dependency at runtime.

Usage:
    python tools/make_avatars.py

Output:
    assets/images/avatars/avatar_001.png ... avatar_048.png
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images" / "avatars"
SIZE = 512
SS = 2  # supersampling factor for smooth edges

SKIN = [
    "#F2C6A0", "#E8B58C", "#DDA57A", "#CF9166", "#B97A4E",
    "#A9683F", "#8D5230", "#F7D4B4", "#E3AE85", "#C98A5D",
]
HAIR = [
    "#1C1412", "#2B1B16", "#3A241B", "#4A2F22", "#131010",
    "#5A3A27", "#201714", "#6B4A31",
]
SHIRT = [
    "#B3261E", "#8C1D18", "#1F5FA8", "#2F6B4F", "#7A4E8C",
    "#C25E2A", "#3A4A5C", "#286A6A", "#8A6A2A", "#5B3A66",
]
BACK_A = [
    "#FDF1EE", "#FFF7E8", "#EAF4F2", "#EDF2FA", "#F7EEF5",
    "#F3F1EC", "#E9F0E8", "#FCEFDF",
]
BACK_B = [
    "#F3D4CE", "#F6E1B9", "#CFE8E1", "#D4E1F4", "#E8D7EC",
    "#DEDCD3", "#D3E3D1", "#F4DEC7",
]
POSE = ["short", "side", "long", "bun", "curly", "buzz", "wavy", "hijab"]


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def mix(a: str, b: str, t: float) -> tuple[int, int, int]:
    ar, ag, ab = hex_rgb(a)
    br, bg, bb = hex_rgb(b)
    return (
        int(ar + (br - ar) * t),
        int(ag + (bg - ag) * t),
        int(ab + (bb - ab) * t),
    )


def gradient(size: int, top: str, bottom: str) -> Image.Image:
    img = Image.new("RGB", (1, size))
    px = img.load()
    for y in range(size):
        px[0, y] = mix(top, bottom, y / max(1, size - 1))
    return img.resize((size, size))


def draw_avatar(index: int) -> Image.Image:
    rng = random.Random(90210 + index * 7919)

    skin = rng.choice(SKIN)
    hair = rng.choice(HAIR)
    shirt = rng.choice(SHIRT)
    pose = POSE[index % len(POSE)]
    bg_top = rng.choice(BACK_A)
    bg_bottom = rng.choice(BACK_B)

    canvas = gradient(SIZE * SS, bg_top, bg_bottom).convert("RGBA")
    d = ImageDraw.Draw(canvas, "RGBA")

    # Decorative background shapes, unique per account.
    for _ in range(rng.randint(2, 4)):
        r = rng.randint(40, 130) * SS
        cx = rng.randint(-60, SIZE + 60) * SS
        cy = rng.randint(-40, SIZE + 40) * SS
        tint = rng.choice([(255, 255, 255, 42), (255, 255, 255, 28), (120, 60, 50, 18)])
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=tint)

    # Shoulders / torso.
    shoulder_y = int(SIZE * 0.70) * SS
    shoulder = [
        (int(SIZE * 0.08) * SS, SIZE * SS),
        (int(SIZE * 0.18) * SS, shoulder_y),
        (int(SIZE * 0.34) * SS, int(SIZE * 0.65) * SS),
        (int(SIZE * 0.66) * SS, int(SIZE * 0.65) * SS),
        (int(SIZE * 0.82) * SS, shoulder_y),
        (int(SIZE * 0.92) * SS, SIZE * SS),
    ]
    d.polygon(shoulder, fill=shirt)
    # Collar
    d.polygon(
        [
            (int(SIZE * 0.42) * SS, int(SIZE * 0.66) * SS),
            (int(SIZE * 0.50) * SS, int(SIZE * 0.78) * SS),
            (int(SIZE * 0.58) * SS, int(SIZE * 0.66) * SS),
            (int(SIZE * 0.50) * SS, int(SIZE * 0.72) * SS),
        ],
        fill=mix(shirt, "#FFFFFF", 0.25),
    )

    # Neck.
    d.rounded_rectangle(
        (
            int(SIZE * 0.43) * SS,
            int(SIZE * 0.55) * SS,
            int(SIZE * 0.57) * SS,
            int(SIZE * 0.72) * SS,
        ),
        radius=int(SIZE * 0.05) * SS,
        fill=mix(skin, "#000000", 0.10),
    )

    # Ears.
    d.ellipse(
        (
            int(SIZE * 0.285) * SS,
            int(SIZE * 0.38) * SS,
            int(SIZE * 0.34) * SS,
            int(SIZE * 0.49) * SS,
        ),
        fill=skin,
    )
    d.ellipse(
        (
            int(SIZE * 0.66) * SS,
            int(SIZE * 0.38) * SS,
            int(SIZE * 0.715) * SS,
            int(SIZE * 0.49) * SS,
        ),
        fill=skin,
    )

    # Head.
    head_box = (
        int(SIZE * 0.31) * SS,
        int(SIZE * 0.22) * SS,
        int(SIZE * 0.69) * SS,
        int(SIZE * 0.62) * SS,
    )
    d.ellipse(head_box, fill=skin)
    # Soft cheek shading.
    d.ellipse(
        (
            int(SIZE * 0.34) * SS,
            int(SIZE * 0.40) * SS,
            int(SIZE * 0.46) * SS,
            int(SIZE * 0.52) * SS,
        ),
        fill=mix(skin, "#B3261E", 0.06),
    )
    d.ellipse(
        (
            int(SIZE * 0.54) * SS,
            int(SIZE * 0.40) * SS,
            int(SIZE * 0.66) * SS,
            int(SIZE * 0.52) * SS,
        ),
        fill=mix(skin, "#B3261E", 0.06),
    )

    # Hair styles.
    if pose in ("long", "wavy", "side"):
        d.ellipse(
            (
                int(SIZE * 0.275) * SS,
                int(SIZE * 0.17) * SS,
                int(SIZE * 0.725) * SS,
                int(SIZE * 0.70) * SS,
            ),
            fill=hair,
        )
        # Face opening.
        d.ellipse(
            (
                int(SIZE * 0.315) * SS,
                int(SIZE * 0.235) * SS,
                int(SIZE * 0.685) * SS,
                int(SIZE * 0.63) * SS,
            ),
            fill=skin,
        )
        if pose == "side":
            d.chord(
                (
                    int(SIZE * 0.28) * SS,
                    int(SIZE * 0.16) * SS,
                    int(SIZE * 0.73) * SS,
                    int(SIZE * 0.50) * SS,
                ),
                180,
                360,
                fill=hair,
            )
    elif pose == "curly":
        for i in range(18):
            a = math.pi + i * math.pi / 17
            cx = int(SIZE * (0.50 + 0.26 * math.cos(a))) * SS
            cy = int(SIZE * (0.36 + 0.22 * math.sin(a))) * SS
            r = rng.randint(34, 58) * SS
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=hair)
        d.ellipse(
            (
                int(SIZE * 0.315) * SS,
                int(SIZE * 0.235) * SS,
                int(SIZE * 0.685) * SS,
                int(SIZE * 0.61) * SS,
            ),
            fill=skin,
        )
        d.chord(
            (
                int(SIZE * 0.31) * SS,
                int(SIZE * 0.19) * SS,
                int(SIZE * 0.69) * SS,
                int(SIZE * 0.44) * SS,
            ),
            180,
            360,
            fill=hair,
        )
    elif pose == "bun":
        d.ellipse(
            (
                int(SIZE * 0.30) * SS,
                int(SIZE * 0.18) * SS,
                int(SIZE * 0.70) * SS,
                int(SIZE * 0.48) * SS,
            ),
            fill=hair,
        )
        d.ellipse(
            (
                int(SIZE * 0.44) * SS,
                int(SIZE * 0.06) * SS,
                int(SIZE * 0.60) * SS,
                int(SIZE * 0.23) * SS,
            ),
            fill=hair,
        )
        d.chord(
            (
                int(SIZE * 0.30) * SS,
                int(SIZE * 0.19) * SS,
                int(SIZE * 0.70) * SS,
                int(SIZE * 0.50) * SS,
            ),
            180,
            360,
            fill=hair,
        )
    elif pose == "hijab":
        hijab = rng.choice(SHIRT)
        d.ellipse(
            (
                int(SIZE * 0.255) * SS,
                int(SIZE * 0.14) * SS,
                int(SIZE * 0.745) * SS,
                int(SIZE * 0.74) * SS,
            ),
            fill=hijab,
        )
        d.ellipse(
            (
                int(SIZE * 0.315) * SS,
                int(SIZE * 0.235) * SS,
                int(SIZE * 0.685) * SS,
                int(SIZE * 0.62) * SS,
            ),
            fill=skin,
        )
        d.polygon(
            [
                (int(SIZE * 0.30) * SS, int(SIZE * 0.42) * SS),
                (int(SIZE * 0.20) * SS, int(SIZE * 0.74) * SS),
                (int(SIZE * 0.36) * SS, int(SIZE * 0.67) * SS),
            ],
            fill=mix(hijab, "#000000", 0.10),
        )
        d.polygon(
            [
                (int(SIZE * 0.70) * SS, int(SIZE * 0.42) * SS),
                (int(SIZE * 0.80) * SS, int(SIZE * 0.74) * SS),
                (int(SIZE * 0.64) * SS, int(SIZE * 0.67) * SS),
            ],
            fill=mix(hijab, "#000000", 0.10),
        )
    elif pose == "buzz":
        d.chord(
            (
                int(SIZE * 0.31) * SS,
                int(SIZE * 0.18) * SS,
                int(SIZE * 0.69) * SS,
                int(SIZE * 0.44) * SS,
            ),
            180,
            360,
            fill=hair,
        )
    else:  # short
        d.chord(
            (
                int(SIZE * 0.30) * SS,
                int(SIZE * 0.17) * SS,
                int(SIZE * 0.70) * SS,
                int(SIZE * 0.47) * SS,
            ),
            180,
            360,
            fill=hair,
        )
        d.ellipse(
            (
                int(SIZE * 0.30) * SS,
                int(SIZE * 0.30) * SS,
                int(SIZE * 0.38) * SS,
                int(SIZE * 0.40) * SS,
            ),
            fill=hair,
        )

    # Eyebrows.
    eye_y = int(SIZE * 0.385) * SS
    brow_y = int(SIZE * 0.352) * SS
    for x0, x1 in ((0.375, 0.455), (0.545, 0.625)):
        d.arc(
            (
                int(SIZE * x0) * SS,
                int(SIZE * (brow_y / SIZE - 0.012)) * SS,
                int(SIZE * x1) * SS,
                int(SIZE * (brow_y / SIZE + 0.020)) * SS,
            ),
            200,
            340,
            fill=mix(hair, "#000000", 0.15),
            width=int(SIZE * 0.012) * SS,
        )
    # Eyes.
    for x in (0.415, 0.585):
        d.ellipse(
            (
                int(SIZE * (x - 0.030)) * SS,
                eye_y - int(SIZE * 0.015) * SS,
                int(SIZE * (x + 0.030)) * SS,
                eye_y + int(SIZE * 0.015) * SS,
            ),
            fill="#FFFFFF",
        )
        d.ellipse(
            (
                int(SIZE * (x - 0.012)) * SS,
                eye_y - int(SIZE * 0.013) * SS,
                int(SIZE * (x + 0.012)) * SS,
                eye_y + int(SIZE * 0.013) * SS,
            ),
            fill="#2A1B16",
        )
        d.ellipse(
            (
                int(SIZE * (x + 0.002)) * SS,
                eye_y - int(SIZE * 0.008) * SS,
                int(SIZE * (x + 0.012)) * SS,
                eye_y + int(SIZE * 0.002) * SS,
            ),
            fill="#FFFFFF",
        )

    # Nose.
    d.line(
        (
            int(SIZE * 0.50) * SS,
            int(SIZE * 0.40) * SS,
            int(SIZE * 0.49) * SS,
            int(SIZE * 0.455) * SS,
            int(SIZE * 0.525) * SS,
            int(SIZE * 0.457) * SS,
        ),
        fill=mix(skin, "#5A3020", 0.30),
        width=int(SIZE * 0.009) * SS,
        joint="curve",
    )

    # Mouth.
    d.arc(
        (
            int(SIZE * 0.44) * SS,
            int(SIZE * 0.46) * SS,
            int(SIZE * 0.56) * SS,
            int(SIZE * 0.535) * SS,
        ),
        15,
        165,
        fill=mix(skin, "#8C1D18", 0.55),
        width=int(SIZE * 0.014) * SS,
    )

    # Glasses on some accounts.
    if index % 5 == 1:
        glass = "#2A2422"
        for x0 in (0.372, 0.542):
            d.rounded_rectangle(
                (
                    int(SIZE * x0) * SS,
                    int(SIZE * 0.365) * SS,
                    int(SIZE * (x0 + 0.086)) * SS,
                    int(SIZE * 0.415) * SS,
                ),
                radius=int(SIZE * 0.014) * SS,
                outline=glass,
                width=int(SIZE * 0.008) * SS,
            )
        d.line(
            (
                int(SIZE * 0.458) * SS,
                int(SIZE * 0.389) * SS,
                int(SIZE * 0.542) * SS,
                int(SIZE * 0.389) * SS,
            ),
            fill=glass,
            width=int(SIZE * 0.008) * SS,
        )

    # Beard on some accounts.
    if index % 7 == 3:
        d.chord(
            (
                int(SIZE * 0.33) * SS,
                int(SIZE * 0.37) * SS,
                int(SIZE * 0.67) * SS,
                int(SIZE * 0.64) * SS,
            ),
            10,
            170,
            fill=mix(hair, "#000000", 0.05),
        )
        d.ellipse(
            (
                int(SIZE * 0.405) * SS,
                int(SIZE * 0.505) * SS,
                int(SIZE * 0.595) * SS,
                int(SIZE * 0.575) * SS,
            ),
            fill=skin,
        )
        d.arc(
            (
                int(SIZE * 0.44) * SS,
                int(SIZE * 0.455) * SS,
                int(SIZE * 0.56) * SS,
                int(SIZE * 0.54) * SS,
            ),
            15,
            165,
            fill=mix(skin, "#8C1D18", 0.55),
            width=int(SIZE * 0.014) * SS,
        )

    # A small blood-drop badge on the shirt, to tie portraits to the brand.
    bx, by = int(SIZE * 0.72) * SS, int(SIZE * 0.82) * SS
    r = int(SIZE * 0.035) * SS
    d.ellipse((bx - r, by - r, bx + r, by + r), fill="#FFFFFF")
    drop = [
        (bx, by - int(r * 0.8)),
        (bx - int(r * 0.55), by + int(r * 0.10)),
        (bx - int(r * 0.20), by + int(r * 0.43)),
        (bx + int(r * 0.20), by + int(r * 0.43)),
        (bx + int(r * 0.55), by + int(r * 0.10)),
    ]
    d.polygon(drop, fill="#B3261E")

    # Vignette so white card backgrounds stay calm around the portrait.
    vignette = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    vd = ImageDraw.Draw(vignette)
    vd.ellipse(
        (
            -int(SIZE * 0.05) * SS,
            -int(SIZE * 0.05) * SS,
            int(SIZE * 1.05) * SS,
            int(SIZE * 1.05) * SS,
        ),
        fill=255,
    )
    vignette = vignette.filter(ImageFilter.GaussianBlur(int(SIZE * 0.06) * SS))
    shade = Image.new("RGBA", canvas.size, (30, 18, 16, 0))
    shade.putalpha(vignette.point(lambda v: int((255 - v) * 0.20)))
    canvas = Image.alpha_composite(canvas, shade)

    return canvas.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(1, 49):
        image = draw_avatar(i)
        image.save(OUT / f"avatar_{i:03d}.png", optimize=True)
    print(f"Wrote 48 avatars to {OUT}")


if __name__ == "__main__":
    main()
