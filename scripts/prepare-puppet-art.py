#!/usr/bin/env python3
"""Rebuild Pip's reviewed cutout crops and stable eyelid textures (Pillow)."""
import importlib.util
import colorsys
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artwork/pip/rig-study"


def main():
    definitions = json.loads((ART / "parts.json").read_text())
    source = Image.open(ART / definitions["source"]).convert("RGBA")
    for name, part in definitions["parts"].items():
        crop = source.crop(part["source_rect"])
        if name.endswith("Leg"):
            # The crop overlaps the cuff. The boot is drawn separately; keep
            # only the brown upper-leg texture in this layer.
            pixels = crop.load()
            for y in range(crop.height):
                for x in range(crop.width):
                    r, g, b, a = pixels[x, y]
                    h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
                    if h < .22 and s > .85 and v > .6:
                        pixels[x, y] = (r, g, b, 0)
        crop.save(ART / part["image"])
    spec = importlib.util.spec_from_file_location("extract_poses", ROOT / "scripts/extract-poses.py")
    extractor = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(extractor)
    extractor.extract(ART / "blink/source.png", ART / "blink/frames", 4, 1)
    geometry_path = ART / "blink/frames/geometry.json"
    geometry = json.loads(geometry_path.read_text())
    geometry["source"] = "artwork/pip/rig-study/blink/source.png"
    geometry["visual_review"] = "Use frames 0–2 for local eye patches. Frame 3 has whiskers near the right source boundary and is unused."
    geometry_path.write_text(json.dumps(geometry, indent=2) + "\n")
    base = Image.open(ART / "blink/frames/pose-00.png").convert("RGBA")
    mask = Image.new("L", base.size)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((127, 185, 173, 237), fill=255)
    draw.ellipse((190, 182, 210, 221), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.5))
    mask = ImageChops.multiply(mask, base.getchannel("A"))
    base.save(ART / "parts/head-open.png")
    for name, index in [("half", 1), ("closed", 2)]:
        variant = Image.open(ART / f"blink/frames/pose-{index:02d}.png").convert("RGBA")
        out = Image.composite(variant, base, mask)
        # Keep the original hood, mouth, whiskers and silhouette stable. Only
        # the local eyelid patches change; alpha is byte-for-byte identical.
        out.putalpha(base.getchannel("A"))
        out.save(ART / f"parts/head-{name}.png")
    mask.save(ART / "blink/eye-mask.png")


if __name__ == "__main__":
    main()
