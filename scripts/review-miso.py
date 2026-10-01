#!/usr/bin/env python3
"""Publish Miso's actual Cocoa render reviews, without synthesizing motion."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("puppet", type=Path)
    parser.add_argument("turn", type=Path)
    parser.add_argument("gait", type=Path)
    parser.add_argument("faces", type=Path)
    args = parser.parse_args()
    output = ROOT / "docs/media"
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 12)
    artifacts = []

    def save(im, name):
        p = output / name; im.save(p); artifacts.append(p)

    names = ["Original", "Round", "Tall", "Big-head", "Original", "Sage", "Lilac", "Midnight"]
    pictures = [Image.open(args.puppet / (name + ".png")).convert("RGBA") for name in names]
    boxes = [p.getchannel("A").getbbox() for p in pictures]
    box = (min(b[0] for b in boxes) - 4, min(b[1] for b in boxes) - 4, max(b[2] for b in boxes) + 4, max(b[3] for b in boxes) + 4)
    sheet = Image.new("RGB", (1120, 790), "#f4f3ef"); draw = ImageDraw.Draw(sheet)
    draw.text((24, 18), "MISO / Cat bot · actual Studio customization", font=font, fill="#293533")
    for i, (name, picture) in enumerate(zip(names, pictures)):
        x, y = i % 4 * 280, i // 4 * 360 + 45; crop = picture.crop(box)
        sheet.paste(crop, (x + 35, y + 28), crop)
        draw.text((x + 25, y + 5), name.replace("-", " "), font=font, fill="#293533")
        little = picture.crop(picture.getchannel("A").getbbox()); little.thumbnail((64, 48), Image.Resampling.NEAREST)
        sheet.paste(little, (x + 30, y + 302), little)
        draw.text((x + 90, y + 323), "48 px character", font=small, fill="#64706a")
    draw.text((24, 766), "Editable shell, suit, lights and proportions · separate limbs and tail · native cursor integration remains unfinished", font=small, fill="#64706a")
    save(sheet, "miso-customization.png")
    for directory, pattern, name, count, cream in [
        (args.puppet, "slow", "miso-walk.gif", 420, False), (args.turn, "turn", "miso-turn.gif", 96, True),
        (args.gait, "gait", "miso-gait.gif", 300, True), (args.faces, "face", "miso-faces.gif", 420, True),
    ]:
        assert len(list(directory.glob(pattern + "-*.png"))) == count
        filters = "color=c=0xf4f3ef:s=320x320:r=60[bg];[bg][0:v]overlay=shortest=1," if cream else ""
        filters += "fps=30,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=none"
        subprocess.run(["/opt/homebrew/bin/ffmpeg", "-y", "-loglevel", "error", "-framerate", "60", "-i", str(directory / (pattern + "-%04d.png")), "-filter_complex", filters, "-loop", "0", str(output / name)], check=True)
        artifacts.append(output / name)
    for directory, pattern, samples, title, name in [
        (args.turn, "turn", [(18, "Right"), (23, "Turning"), (27, "Front"), (31, "Turning"), (36, "Left")], "Coordinated head and torso · compact collar · fixed foot contacts", "miso-turn-sequence.png"),
        (args.gait, "gait", [(0, "Idle"), (60, "Walking"), (100, "Fast travel"), (113, "Landing"), (165, "Settled")], "Actual gait · separate feet and tail · bounded fast movement", "miso-gait-sequence.png"),
        (args.faces, "face", [(30, "Idle"), (160, "Travel"), (57, "Press"), (75, "Release"), (345, "Blink")], "Localized pixel expressions · unchanged shell and ears", "miso-face-sequence.png"),
    ]:
        sheet = Image.new("RGB", (1100, 350), "#f4f3ef"); pen = ImageDraw.Draw(sheet)
        for i, (frame, label) in enumerate(samples):
            im = Image.open(directory / f"{pattern}-{frame:04d}.png").convert("RGBA").crop((48, 0, 268, 290))
            sheet.paste(im, (i * 220, 30), im); pen.text((i * 220 + 20, 10), label, font=font, fill="#293533")
        pen.text((24, 324), title, font=font, fill="#293533"); save(sheet, name)
    bounds = {}
    for p in sorted(args.puppet.glob("limit-*.png")):
        im = Image.open(p).convert("RGBA"); b = im.getchannel("A").getbbox()
        assert b and b[0] > 0 and b[1] > 0 and b[2] < im.width and b[3] < im.height
        bounds[p.stem] = b
    assert len(bounds) == 8
    files = [*ROOT.glob("Sources/Buddie*.*"), ROOT / "Sources/Preview.m", ROOT / "tests/test_character.m", ROOT / "tests/test_motion.c",
             ROOT / "scripts/build-miso.py", Path(__file__), *ROOT.glob("Characters/miso/*"), *ROOT.glob("artwork/miso/*"), *artifacts]
    if (output / "miso-live.png").exists(): files.append(output / "miso-live.png")
    parts = json.loads((ROOT / "Characters/miso/buddy.json").read_text())["puppet"]["parts"]
    report = {"status": "Selectable Miso rig with actual Cocoa export review; no user design approval or live Codex replacement claimed.",
              "pack": {"parts": len(parts), "frames": sum(len(p["frames"]) for p in parts.values()), "materials": ["shell", "suit", "face"]}, "source_fps": 60, "gif_fps": 30,
              "checks": ["Every recolored frame/proportion survives portable export/import", "Three material masks do not overlap",
                         "25 expression textures preserve every alpha sample and non-eye pixel", "20 Cocoa face/perspective combinations preserve the whole character outside its eyes",
                         "Three tail positions change only tail pixels; Reduced Motion holds eyes and tail still", "Eight extreme proportion corners fit the renderer",
                         "Switching from an actively edited buddy cannot copy its colors; obsolete text fields and wells are ignored"],
              "proportion_corner_bounds": bounds,
              "live_ui": {"historical_source_commit": "d0d183da3dd7c1763b1aa0ce8508b4dd2e296c86", "current_build_verified": False,
                          "tool": "official CUA", "bundled_collection": "Miso present after restarting the Studio",
                          "color_isolation": "Edited Bit shell to #EB504D, switched while the field was active: Miso retained #FCEFD5",
                          "customization": {"suit": "#7C9A80", "torsoWidth": 1.12, "headScale": 0.93},
                          "observed": ["walking with travel eyes", "release sparkle", "live suit and proportion changes", "reset to original palette/proportions"],
                          "screenshot": "docs/media/miso-live.png", "screenshot_processing": "Full CUA app-window screenshot, downsampled to 960 px wide and saved as PNG"},
              "limitations": ["Native helper IPC and true cursor replacement remain unfinished", "Live collection restart verification is pending; automated persistence checks pass", "Miso design approval is pending", "Broader body types remain unfinished", "ChatGPT did not expose the image model identifier"],
              "sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}}
    (ROOT / "docs/evidence/miso-studio.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Saved Miso's Cocoa customization, turn, gait and face reviews.")


if __name__ == "__main__":
    main()
