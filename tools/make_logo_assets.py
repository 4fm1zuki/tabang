"""Generate TABANG's logo assets from the supplied `assets/logo.jpg`.

The source is a 1024x1024 artwork (blood drop, heart and hand) on a plain white
square, so every output keeps that white plate: the design's own white outline
around the mark is part of the drawing, and knocking the background out would
eat it.

Run from the repository root:

    python tools/make_logo_assets.py

Outputs
-------
assets/branding/app_icon.png        1024, in-app mark and source of the icons
assets/branding/tabang_logo_*.png   sized copies for UI use
web/favicon.png                     32
web/icons/Icon-*.png                PWA icons (192, 512)
web/icons/Icon-maskable-*.png       PWA maskable icons, art inset to the safe zone
android/app/src/main/res/mipmap-*/ic_launcher.png   launcher icons
"""

from __future__ import annotations

import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "logo.jpg")
BRANDING = os.path.join(ROOT, "assets", "branding")

# Standard launcher icon sizes per density bucket.
ANDROID_ICONS = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Maskable icons must keep their subject inside the safe zone (the outer ~20% of
# the square can be cropped by the launcher), so the art is inset and padded.
MASKABLE_INSET = 0.78

# The source artwork carries a wide white margin around the mark. Trimming to
# the mark and re-padding by this fraction makes the logo read at header sizes
# instead of sitting small inside its tile.
TRIM_THRESHOLD = 246
TRIM_PADDING = 0.06


def _trim_to_mark(image: Image.Image) -> Image.Image:
    """Crop the white margin, then re-pad the mark by [TRIM_PADDING]."""
    grey = image.convert("L")
    mask = grey.point(lambda value: 255 if value < TRIM_THRESHOLD else 0)
    box = mask.getbbox()
    if box is None:
        return image
    art = image.crop(box)
    side = max(art.size)
    pad = int(round(side * TRIM_PADDING))
    canvas = Image.new("RGB", (side + 2 * pad, side + 2 * pad), (255, 255, 255))
    canvas.paste(
        art,
        ((canvas.width - art.width) // 2, (canvas.height - art.height) // 2),
    )
    return canvas


def _square(image: Image.Image, size: int, inset: float = 1.0) -> Image.Image:
    """Resize [image] to a white square of [size], art occupying [inset]."""
    canvas = Image.new("RGB", (size, size), (255, 255, 255))
    inner = max(1, int(round(size * inset)))
    art = image.resize((inner, inner), Image.LANCZOS)
    offset = (size - inner) // 2
    canvas.paste(art, (offset, offset))
    return canvas


def main() -> None:
    art = Image.open(SOURCE).convert("RGB")
    if art.width != art.height:
        side = min(art.size)
        left = (art.width - side) // 2
        top = (art.height - side) // 2
        art = art.crop((left, top, left + side, top + side))
    art = _trim_to_mark(art)

    os.makedirs(BRANDING, exist_ok=True)

    # In-app mark, at the source resolution so it stays crisp on every surface.
    _square(art, 1024).save(os.path.join(BRANDING, "app_icon.png"), "PNG")

    for size in (512, 256, 128, 64):
        _square(art, size).save(
            os.path.join(BRANDING, f"tabang_logo_{size}.png"), "PNG"
        )

    # Web / PWA.
    web = os.path.join(ROOT, "web")
    icons = os.path.join(web, "icons")
    os.makedirs(icons, exist_ok=True)
    _square(art, 32).save(os.path.join(web, "favicon.png"), "PNG")
    _square(art, 192).save(os.path.join(icons, "Icon-192.png"), "PNG")
    _square(art, 512).save(os.path.join(icons, "Icon-512.png"), "PNG")
    _square(art, 192, MASKABLE_INSET).save(
        os.path.join(icons, "Icon-maskable-192.png"), "PNG"
    )
    _square(art, 512, MASKABLE_INSET).save(
        os.path.join(icons, "Icon-maskable-512.png"), "PNG"
    )

    # Android launcher icons.
    for folder, size in ANDROID_ICONS.items():
        target = os.path.join(ROOT, "android", "app", "src", "main", "res", folder)
        if not os.path.isdir(target):
            continue
        _square(art, size).save(os.path.join(target, "ic_launcher.png"), "PNG")

    print("Logo assets written from", SOURCE)


if __name__ == "__main__":
    main()
