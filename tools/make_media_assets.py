"""Build TABANG's bundled photo assets, privacy artwork and app icons.

Usage (from the repository root):
    python tools/make_media_assets.py

The source photographs live in ``tools/image_sources`` and are all public
domain or CC0 (see ``tools/image_sources/CREDITS.md``). They are cropped to
16:9, lightly graded and written to ``assets/images`` as optimised JPEGs.
The script also draws the privacy card art and regenerates every platform
launcher icon from one vector-style source, so the branding stays consistent.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "tools" / "image_sources"
IMAGES = ROOT / "assets" / "images"
BRANDING = ROOT / "assets" / "branding"

CRIMSON = (179, 38, 30)
CRIMSON_DARK = (110, 21, 18)
CRIMSON_DEEP = (74, 14, 12)
CREAM = (247, 245, 244)


def ensure_dirs() -> None:
    IMAGES.mkdir(parents=True, exist_ok=True)
    BRANDING.mkdir(parents=True, exist_ok=True)


def crop_16x9(image: Image.Image, top: int) -> Image.Image:
    """Crop a 1920-wide source to 16:9 starting at ``top``."""
    width, height = image.size
    target_height = round(width * 9 / 16)
    top = max(0, min(top, height - target_height))
    return image.crop((0, top, width, top + target_height))


def grade(image: Image.Image, warmth: float = 0.03) -> Image.Image:
    """Give every photo the same gentle, warm editorial grade."""
    image = image.convert("RGB")
    image = ImageEnhance.Color(image).enhance(1.05)
    image = ImageEnhance.Contrast(image).enhance(1.03)
    if warmth:
        wash = Image.new("RGB", image.size, CRIMSON)
        image = Image.blend(image, wash, warmth)
    return image


def save_jpeg(image: Image.Image, name: str, width: int = 1200) -> None:
    height = round(width * 9 / 16)
    image = image.resize((width, height), Image.LANCZOS)
    path = IMAGES / name
    image.save(path, "JPEG", quality=84, optimize=True, progressive=True)
    print(f"{path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")


def process_photos() -> None:
    # source file, output file, crop-top, relative warmth.
    #
    # Only the photos the app still uses are listed: the ten content_*.jpg
    # illustrations were replaced by the per-folder artwork (Learn & Prepare,
    # Blood Drives, Announcements & Stories) and the files were deleted, so
    # listing them here would recreate them on the next run.
    specs = [
        ("ramstein.jpg", "hero_donation.jpg", 10, 0.035),
        ("baliuag07.jpg", "content_drive.jpg", 250, 0.03),
        ("baliuag04.jpg", "drive_community.jpg", 300, 0.03),
    ]
    for source, output, top, warmth in specs:
        path = SOURCES / source
        if not path.exists():
            print(f"missing source: {path}")
            continue
        with Image.open(path) as opened:
            cropped = crop_16x9(opened, top)
            save_jpeg(grade(cropped, warmth), output)


def gradient(size: tuple[int, int], top: tuple[int, int, int],
             bottom: tuple[int, int, int]) -> Image.Image:
    """A vertical two-stop gradient, built one column wide then stretched."""
    _, height = size
    strip = Image.new("RGB", (1, height))
    pixels = strip.load()
    for y in range(height):
        t = y / max(1, height - 1)
        pixels[0, y] = tuple(
            round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)
        )
    return strip.resize(size, Image.BILINEAR)


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=radius, fill=255
    )
    return mask


def draw_droplet(canvas: Image.Image, size: int, safe: bool = False) -> None:
    """Draw the white TABANG droplet centred on a square canvas."""
    scale = 4
    s = size * scale
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    cx = s / 2
    if safe:
        top = s * 0.28
        bottom = s * 0.76
        radius = s * 0.155
    else:
        top = s * 0.21
        bottom = s * 0.80
        radius = s * 0.205

    centre_y = bottom - radius
    # A soft shadow lifts the droplet off the crimson field.
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse(
        (cx - radius, centre_y - radius + s * 0.012,
         cx + radius, centre_y + radius + s * 0.012),
        fill=(0, 0, 0, 70),
    )
    sd.polygon(
        [(cx, top + s * 0.012),
         (cx - radius * 0.94, centre_y + s * 0.012),
         (cx + radius * 0.94, centre_y + s * 0.012)],
        fill=(0, 0, 0, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(s * 0.018))
    layer = Image.alpha_composite(layer, shadow)
    draw = ImageDraw.Draw(layer)

    draw.ellipse(
        (cx - radius, centre_y - radius, cx + radius, centre_y + radius),
        fill=(255, 255, 255, 255),
    )
    draw.polygon(
        [(cx, top),
         (cx - radius * 0.94, centre_y),
         (cx + radius * 0.94, centre_y)],
        fill=(255, 255, 255, 255),
    )

    # Small specular highlight.
    highlight = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hd.ellipse(
        (cx - radius * 0.56, centre_y - radius * 0.62,
         cx - radius * 0.12, centre_y - radius * 0.20),
        fill=(255, 255, 255, 110),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(s * 0.006))
    layer = Image.alpha_composite(layer, highlight)

    layer = layer.resize((size, size), Image.LANCZOS)
    canvas.alpha_composite(layer)


def make_icon(size: int, *, rounded: bool = False, safe: bool = False) -> Image.Image:
    # Draw at 4x and downsample for clean anti-aliased edges.
    scale = 4
    s = size * scale
    background = gradient((s, s), CRIMSON_DARK, CRIMSON)

    # Soft radial highlight in the upper-left corner.
    glow = Image.new("L", (s, s), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        (-s * 0.35, -s * 0.45, s * 0.55, s * 0.45),
        fill=90,
    )
    glow = glow.filter(ImageFilter.GaussianBlur(s * 0.16))
    white = Image.new("RGB", (s, s), (255, 255, 255))
    background = Image.composite(white, background, glow.point(lambda v: v // 3))

    icon = background.convert("RGBA")
    draw_droplet(icon, s, safe=safe)
    icon = icon.resize((size, size), Image.LANCZOS)

    if rounded:
        icon.putalpha(rounded_mask(size, round(size * 0.22)))
    return icon


def write_icon_set() -> None:
    source = make_icon(1024)
    source.save(BRANDING / "app_icon.png", "PNG", optimize=True)
    print(f"{(BRANDING / 'app_icon.png').relative_to(ROOT)}")

    web_icons = ROOT / "web" / "icons"
    web_icons.mkdir(parents=True, exist_ok=True)
    make_icon(192).save(web_icons / "Icon-192.png", "PNG", optimize=True)
    make_icon(512).save(web_icons / "Icon-512.png", "PNG", optimize=True)
    make_icon(192, safe=True).save(
        web_icons / "Icon-maskable-192.png", "PNG", optimize=True
    )
    make_icon(512, safe=True).save(
        web_icons / "Icon-maskable-512.png", "PNG", optimize=True
    )
    make_icon(32).save(ROOT / "web" / "favicon.png", "PNG", optimize=True)

    android = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, px in {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }.items():
        target = android / folder / "ic_launcher.png"
        make_icon(px).save(target, "PNG", optimize=True)

    ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, px in {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }.items():
        make_icon(px).save(ios / name, "PNG", optimize=True)

    macos = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, px in {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }.items():
        make_icon(px, rounded=True).save(macos / name, "PNG", optimize=True)

    ico = make_icon(256, rounded=True)
    ico.save(
        ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64),
               (128, 128), (256, 256)],
    )


def make_privacy_art() -> None:
    width, height = 1200, 675
    art = gradient((width, height), CRIMSON_DEEP, CRIMSON)
    draw = ImageDraw.Draw(art, "RGBA")

    # Dotted halo.
    for i in range(34):
        angle = i / 34 * math.pi * 2
        x = width / 2 + math.cos(angle) * 285
        y = height / 2 + math.sin(angle) * 220
        radius = 4 if i % 4 == 0 else 2
        draw.ellipse((x - radius, y - radius, x + radius, y + radius),
                     fill=(255, 255, 255, 35))

    # Two overlapping speech bubbles.
    draw.rounded_rectangle((250, 170, 700, 430), radius=54,
                           fill=(255, 255, 255, 42))
    draw.polygon([(320, 425), (320, 510), (430, 425)],
                 fill=(255, 255, 255, 42))
    draw.rounded_rectangle((470, 250, 955, 500), radius=54,
                           fill=(255, 255, 255, 225))
    draw.polygon([(820, 495), (820, 575), (720, 495)],
                 fill=(255, 255, 255, 225))

    # Lock on the front bubble.
    draw.rounded_rectangle((655, 345, 775, 445), radius=20, fill=CRIMSON)
    draw.arc((675, 300, 755, 390), start=180, end=360,
             fill=CRIMSON, width=18)
    draw.ellipse((707, 378, 723, 394), fill=(255, 255, 255, 255))
    draw.rounded_rectangle((710, 390, 720, 420), radius=5,
                           fill=(255, 255, 255, 255))

    path = IMAGES / "content_privacy.jpg"
    art.save(path, "JPEG", quality=88, optimize=True, progressive=True)
    print(f"{path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")


def main() -> None:
    ensure_dirs()
    process_photos()
    write_icon_set()


if __name__ == "__main__":
    main()
