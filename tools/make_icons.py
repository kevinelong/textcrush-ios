"""Render the iOS app icons from the game's own mark, following AppIcon.appiconset/Contents.json.

    python tools/make_icons.py

Same four letter tiles on the game's ground as the Android launcher icon and the web app icons, so
the mark is recognisable whichever way the game arrived. The set is read from Contents.json rather
than hardcoded, so it stays in step with whatever Xcode expects. Pillow only, no network.
"""
import json
import os
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ICONS = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")

BOARD = (34, 17, 0, 255)
TILES = [
    ((199, 79, 160, 255), "T"),
    ((57, 179, 106, 255), "E"),
    ((63, 169, 199, 255), "X"),
    ((224, 138, 60, 255), "T"),
]
LETTER = (255, 255, 255, 255)
LETTER_EDGE = (34, 17, 0, 255)

FONTS = [
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\segoeuib.ttf",
    r"C:\Windows\Fonts\arial.ttf",
]
SS = 4  # supersample factor


def pick_font() -> str:
    for path in FONTS:
        if os.path.exists(path):
            return path
    raise SystemExit("no truetype font found")


def render(size: int, font_path: str) -> Image.Image:
    # iOS icons are opaque and get their corners rounded by the system, so the mark fills the square
    # with a margin rather than being masked here.
    canvas = Image.new("RGBA", (size, size), BOARD)
    draw = ImageDraw.Draw(canvas)
    span = size * 0.84
    tile = span / 2
    radius = tile * 0.42
    letter_px = int(tile * 0.72)
    font = ImageFont.truetype(font_path, letter_px)
    origin = (size - span) / 2

    for index, (color, letter) in enumerate(TILES):
        col, row = index % 2, index // 2
        cx = origin + col * tile + tile / 2
        cy = origin + row * tile + tile / 2

        draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color)

        box = draw.textbbox((0, 0), letter, font=font, stroke_width=max(1, letter_px // 12))
        draw.text(
            (cx - (box[0] + box[2]) / 2, cy - (box[1] + box[3]) / 2),
            letter,
            font=font,
            fill=LETTER,
            stroke_width=max(1, letter_px // 12),
            stroke_fill=LETTER_EDGE,
        )

    return canvas


def main() -> None:
    font_path = pick_font()

    with open(os.path.join(ICONS, "Contents.json"), encoding="utf-8") as handle:
        contents = json.load(handle)

    written = 0

    for entry in contents["images"]:
        filename = entry.get("filename")
        size = entry.get("size")
        scale = entry.get("scale")

        if not filename or not size or not scale:
            continue

        points = float(re.match(r"([\d.]+)x", size).group(1))
        px = int(round(points * int(scale.rstrip("x"))))

        # Pillow writes at the requested size directly; supersampling here would only blur the small
        # sizes, and Xcode downsamples the 1024 itself.
        render(px * SS, font_path).resize((px, px), Image.LANCZOS).save(os.path.join(ICONS, filename))
        written += 1

    print(f"wrote {written} icons into {os.path.relpath(ICONS, ROOT)}")


if __name__ == "__main__":
    main()
