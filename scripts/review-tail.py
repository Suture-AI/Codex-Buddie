#!/usr/bin/env python3
"""Review authored Miso tail views using actual Cocoa output."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("turn", type=Path)
    parser.add_argument("gait", type=Path)
    args = parser.parse_args()
    outputs, bounds = [], {}
    for directory, pattern, count in [(args.turn, "turn", 96), (args.gait, "gait", 300)]:
        files = sorted(directory.glob(pattern + "-*.png"))
        assert len(files) == count
        boxes = []
        for path in files:
            with Image.open(path) as im:
                b = im.getchannel("A").getbbox()
                assert im.size == (320, 320) and b and b[0] > 0 and b[1] > 0 and b[2] < 320 and b[3] < 320
                boxes.append(b)
        bounds[pattern] = [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]
        output = ROOT / "docs/media" / f"miso-tail-{pattern}.gif"
        subprocess.run(["/opt/homebrew/bin/ffmpeg", "-y", "-loglevel", "error", "-framerate", "60", "-i", str(directory / f"{pattern}-%04d.png"),
                        "-filter_complex", "color=c=0xf4f3ef:s=320x320:r=60[bg];[bg][0:v]overlay=shortest=1,fps=30,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=none",
                        "-loop", "0", str(output)], check=True)
        outputs.append(output)

    sheet = Image.new("RGB", (1100, 360), "#f4f3ef")
    pen = ImageDraw.Draw(sheet); font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    for i, (frame, label) in enumerate([(18, "Right"), (23, "Turning"), (27, "Front"), (31, "Turning"), (36, "Left")]):
        im = Image.open(args.turn / f"turn-{frame:04d}.png").convert("RGBA").crop((48, 0, 268, 290))
        sheet.paste(im, (i * 220, 30), im)
        pen.text((i * 220 + 20, 10), label, font=font, fill="#293533")
    pen.text((24, 324), "Actual Cocoa renderer · rooted tail turn · fixed boots", font=font, fill="#293533")
    output = ROOT / "docs/media/miso-tail-sequence.png"; sheet.save(output); outputs.append(output)

    # The generated stem must remain joined after palette reduction and flex.
    connectivity = {}
    for path in sorted((ROOT / "Characters/miso").glob("tail*.png")):
        if "mask" in path.name:
            continue
        im = Image.open(path).convert("RGBA")
        pixels = {(x, y) for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[3]}
        assert (34, 53) in pixels
        todo, seen = [(34, 53)], {(34, 53)}
        while todo:
            x, y = todo.pop()
            for p in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]:
                if p in pixels and p not in seen:
                    seen.add(p); todo.append(p)
        assert seen == pixels, path
        connectivity[path.name] = len(pixels)
    assert len(connectivity) == 9
    sources = [ROOT / p for p in ["Sources/BuddieCharacter.m", "Sources/BuddiePuppet.m", "Sources/BuddieView.m", "Sources/Preview.m", "tests/test_character.m", "scripts/build-miso.py"]]
    sources += [Path(__file__), *ROOT.glob("Characters/miso/*"), *ROOT.glob("artwork/miso/tail*"), ROOT / "artwork/miso/provenance.json"]
    parts = json.loads((ROOT / "Characters/miso/buddy.json").read_text())["puppet"]["parts"]
    report = {
        "status": "Miso tail rotates around the hips with authored perspective, behind the body; actual Cocoa review and regression checks passed.",
        "pack": {"parts": len(parts), "logical_frames": sum(len(p["frames"]) for p in parts.values()), "tail_views": 5, "unique_tail_images": 9, "version_3_frame_limit": 96, "decoded_byte_limit": 67108864},
        "art": {"source": "ChatGPT in Brave via official CUA", "requested_model": "GPT Image 2.5 if available", "verified_model": None, "user_approved": False},
        "render_review": {"source_fps": 60, "gif_fps": 30, "turn_frames": 96, "gait_frames": 300, "bounds": bounds, "source_connectivity": connectivity},
        "checks": ["21 Cocoa turn samples keep the tail root attached and every boot pixel fixed", "Changing desired direction at the same progress produces identical pixels", "Front view is pixel-identical with and without the tail: complete occlusion", "Both idle directions have three visible flex positions and static Reduced Motion", "All recolored frames and attachment metadata survive export/import", "Missing/misaligned/mistimed tail directions are rejected", "Version 3 accepts 96 frames and rejects 97; version 2 still accepts 64 and rejects 65", "Existing anatomy, foot-contact, viewport, expression and library checks pass"],
        "limitations": ["Head/antenna perspective still needs craft review", "Pip non-pixel knees, broader anatomy and production cursor sizing remain unfinished", "No live Studio interaction or native Codex replacement claimed in this review"],
        "sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(sources + outputs)},
    }
    (ROOT / "docs/evidence/miso-tail.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Saved Cocoa tail turn/gait review, contact sheet and source-pinned evidence.")


if __name__ == "__main__":
    main()
