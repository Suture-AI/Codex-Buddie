#!/usr/bin/env python3
"""Package the reviewed generated cutouts as an editable version-3 buddy."""
import colorsys
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artwork/pip/rig-study"
PACK = ROOT / "Characters/pip-articulated"


def mask_for(image, name):
    mask = Image.new("RGBA", image.size, (0, 0, 0, 255))
    boot = Image.new("L", image.size)
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = image.getpixel((x, y))
            if not a:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            coat = round(255 * min(1, max(0, (s - .08) / .24))) if .51 <= h <= .75 else 0
            mask.putpixel((x, y), (coat, 0, 0, 255))
            if name.endswith("Boot") and 0 <= h <= .22 and s >= .84 and v >= .4:
                boot.putpixel((x, y), 255)
    if name.endswith("Boot"):
        seeds = boot.copy()
        boot = boot.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
        exterior = boot.copy()
        ImageDraw.floodfill(exterior, (0, 0), 128)
        boot = ImageChops.lighter(exterior.point(lambda v: 0 if v == 128 else 255), seeds)
        edge = boot.filter(ImageFilter.MaxFilter(7))
        for y in range(image.height):
            for x in range(image.width):
                r, g, b, a = image.getpixel((x, y))
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                if a and edge.getpixel((x, y)) and v > .82 and 0 <= h <= .22:
                    boot.putpixel((x, y), 255)
        boot = boot.filter(ImageFilter.GaussianBlur(.45))
        mask = Image.merge("RGBA", (mask.getchannel("R"), boot, mask.getchannel("B"), mask.getchannel("A")))
    return mask


def main():
    PACK.mkdir(parents=True, exist_ok=True)
    names = ["body", "tail", "paw", "nearLeg", "farLeg", "nearBoot", "farBoot", "head-open", "head-half", "head-closed"]
    for name in names:
        shutil.copyfile(ART / "parts" / f"{name}.png", PACK / f"{name}.png")
        mask_for(Image.open(PACK / f"{name}.png").convert("RGBA"), name).save(PACK / f"{name}-mask.png")

    def frame(name, duration=1):
        return {"image": f"{name}.png", "duration": duration, "mask": f"{name}-mask.png"}

    def part(name, pivot, anchor, scale, **extra):
        return {"pivot": pivot, "anchor": [anchor[0] + 64, anchor[1] + 48], "scale": scale, "frames": [frame(name)], **extra}

    parts = {
        "head": part("head-open", [128, 286], [150, 188], .89),
        "body": part("body", [216, 254], [150, 250], .30),
        "tail": part("tail", [355, 110], [116, 257], .24),
        "pawNear": part("paw", [105, 47], [104, 246], .16),
        "pawFar": part("paw", [105, 47], [191, 239], .13),
        "legNear": part("nearLeg", [88, 22], [133, 267], .17, cuff=[-12, -34], span=22),
        "legFar": part("farLeg", [88, 22], [167, 267], .17, cuff=[-10, -31], span=22),
        "bootNear": part("nearBoot", [209, 238], [150, 315], .17),
        "bootFar": part("farBoot", [193, 218], [150, 315], .17),
    }
    parts["head"]["frames"] = [frame("head-open", 1.8), frame("head-half", .05), frame("head-closed", .09), frame("head-half", .06), frame("head-open", 1.7)]
    manifest = {
        "version": 3, "id": "pip-articulated", "name": "Pip · Articulated",
        "rig": {"stride": 16, "footSpacing": 6, "footLift": 3},
        "puppet": {
            "canvas": [448, 448], "hotspot": [214, 118], "height": 96,
            "mirrorWalk": True, "motionScale": 3,
            "proportions": {"torsoWidth": 1, "torsoHeight": 1, "headScale": 1},
            "materials": [
                {"id": "coat", "name": "Raincoat", "channel": 0, "base": "#0850EF"},
                {"id": "boots", "name": "Boots", "channel": 1, "base": "#FF8000"},
            ],
            "parts": parts,
        },
    }
    (PACK / "buddy.json").write_text(json.dumps(manifest, indent=2) + "\n")
    provenance = {
        "sources": ["artwork/pip/rig-study/provenance.json", "artwork/pip/rig-study/blink/provenance.json"],
        "processing": ["scripts/prepare-puppet-art.py", "scripts/build-pip-puppet.py"],
        "requested_model": "GPT Image 2.5 if available", "verified_model": None,
        "status": "Selectable articulated study; original generated artwork, user approval pending.",
        "sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(PACK.glob("*.png"))},
    }
    (PACK / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")


if __name__ == "__main__":
    main()
