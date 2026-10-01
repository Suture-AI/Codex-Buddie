#!/usr/bin/env python3
"""Build reviewed coat/boot masks for Pip's existing registered RGBA poses.

This is specific to Pip's cobalt coat and orange boots, not a general segmenter.
Run with Pillow installed, from any directory. Original pose pixels stay intact.
"""
import colorsys
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "Characters/pip"


def ramp(value, low, high):
    t = max(0, min(1, (value - low) / (high - low)))
    return t * t * (3 - 2 * t)


def main():
    manifest_path = PACK / "buddy.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["sprites"]["materials"] = [
        {"id": "coat", "name": "Raincoat", "channel": 0, "base": "#0850EF"},
        {"id": "boots", "name": "Boots", "channel": 1, "base": "#FF8000"},
    ]
    for frames in manifest["sprites"]["clips"].values():
        for frame in frames:
            original = Image.open(PACK / frame["image"]).convert("RGBA")
            mask = Image.new("RGBA", original.size, (0, 0, 0, 255))
            source, target = original.load(), mask.load()
            boot_region = Image.new("L", original.size)
            boot_pixels = boot_region.load()
            for y in range(original.height):
                for x in range(original.width):
                    r, g, b, a = source[x, y]
                    if not a:
                        continue
                    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                    coat = ramp(s, 0.08, 0.32) if 0.51 <= h <= 0.75 else 0
                    # Fur and cream belly are deliberately excluded. White
                    # specular highlights remain bright in every palette.
                    # High-confidence orange seeds exclude brown shadowed fur.
                    boot_pixels[x, y] = 255 if y >= 212 and 0 <= h <= 0.22 and s >= 0.84 and v >= 0.4 else 0
                    target[x, y] = (round(coat * 255), 0, 0, 255)
            # Fill specular holes inside the boots so orange rims do not survive
            # a blue/cream recolor. Closing joins tiny gaps at highlight edges.
            seeds = boot_region.copy()
            boot_region = boot_region.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
            exterior = boot_region.copy()
            ImageDraw.floodfill(exterior, (0, 0), 128)
            boot_region = exterior.point(lambda value: 0 if value == 128 else 255)
            boot_region = ImageChops.lighter(boot_region, seeds)
            edge = boot_region.filter(ImageFilter.MaxFilter(7))
            for y in range(original.height):
                for x in range(original.width):
                    r, g, b, a = source[x, y]
                    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                    if a and edge.getpixel((x, y)) and v > 0.82 and 0 <= h <= 0.22:
                        boot_region.putpixel((x, y), 255)
            boot_region = boot_region.filter(ImageFilter.GaussianBlur(0.45))
            for y in range(original.height):
                for x in range(original.width):
                    coat = target[x, y][0]
                    target[x, y] = (coat, boot_region.getpixel((x, y)) if source[x, y][3] else 0, 0, 255)
            frame["mask"] = Path(frame["image"]).stem + "-mask.png"
            mask.save(PACK / frame["mask"])
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
