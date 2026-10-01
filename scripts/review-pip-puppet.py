#!/usr/bin/env python3
"""Publish proof from actual Cocoa exports; no replacement character rendering."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("slow", type=Path)
    parser.add_argument("fast", type=Path)
    args = parser.parse_args()
    output = ROOT / "docs/media"
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
    names = ["Original", "Round", "Tall", "Big-hood", "Original", "Rose", "Moss", "Lilac"]
    sheet = Image.new("RGB", (1120, 780), "#f4f3ef")
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 18), "PIP / Articulated character · actual Cocoa renderer", font=font, fill="#293533")
    for index, name in enumerate(names):
        art = Image.open(args.slow / f"{name}.png").convert("RGBA")
        x, y = index % 4 * 280, index // 4 * 355 + 46
        crop = art.crop((305, 170, 535, 430))
        sheet.paste(crop, (x + 24, y + 28), crop)
        draw.text((x + 24, y + 6), name.replace("-", " "), font=font, fill="#293533")
        thumb = art.crop(art.getchannel("A").getbbox())
        thumb.thumbnail((90, 64), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x + 28, y + 288), thumb)
        draw.text((x + 103, y + 307), "64 px character", font=small, fill="#64706a")
    draw.text((24, 759), "Editable torso / head / colors. Enlarged review; native 20 × 23 cursor sizing remains unresolved.", font=small, fill="#64706a")
    sheet.save(output / "pip-studio-customization.png")
    bounds = {}
    for path in sorted(args.slow.glob("limit-*.png")):
        art = Image.open(path).convert("RGBA")
        box = art.getchannel("A").getbbox()
        assert box and box[0] > 0 and box[1] > 0 and box[2] < art.width and box[3] < art.height, (path.name, box)
        bounds[path.stem] = box
    for directory, pattern, name in [(args.slow, "slow-%04d.png", "pip-studio-walk.gif"), (args.fast, "frame-%04d.png", "pip-studio-fast-travel.gif")]:
        subprocess.run(["/opt/homebrew/bin/ffmpeg", "-y", "-loglevel", "error", "-framerate", "60", "-i", str(directory / pattern), "-filter_complex", "fps=30,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=sierra2_4a", "-loop", "0", str(output / name)], check=True)
    paths = [*ROOT.glob("Sources/Buddie*.*"), ROOT / "Sources/Preview.m", ROOT / "scripts/build-pip-puppet.py", ROOT / "scripts/review-pip-puppet.py", *ROOT.glob("Characters/pip-articulated/*.png"), ROOT / "Characters/pip-articulated/buddy.json"]
    paths += [output / name for name in ["pip-studio-customization.png", "pip-studio-walk.gif", "pip-studio-fast-travel.gif"]]
    report = {
        "status": "Cocoa integration study; not live CUA replacement or user approval",
        "source_frame_rate": 60, "gif_frame_rate": 30,
        "slow_frames": 420, "fast_frames": 240,
        "proportion_corner_bounds": bounds,
        "checks": ["v1/v2/v3 pack validation and portable editable copies", "120 stop/resume scenarios at 30/60/120 Hz", "15 fast travel/reversal/landing scenarios, 100–1600 motion units/sec", "Cocoa contact geometry at six size/zoom combinations", "Reduced Motion and fixed hotspot"],
        "limitations": ["Native UI observation still returned cgWindowNotFound; controls were not manually exercised", "Instant mirrored facing still reverses lighting and needs authored turns", "Joint overlap and sprint entry/landing need further visual refinement", "Full cursor-size legibility and live native IPC remain unresolved", "One original character; complete multi-character collection pending"],
        "sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)},
    }
    (ROOT / "docs/evidence/articulated-studio.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"proportion_corners": bounds, "media": [p.name for p in paths[-3:]]}, indent=2))


if __name__ == "__main__":
    main()
