#!/usr/bin/env python3
"""Publish the real Cocoa face export and source-pinned review evidence."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("frames", type=Path)
    args = parser.parse_args()
    assert len(list(args.frames.glob("face-*.png"))) == 420
    output = ROOT / "docs/media"
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    sheet = Image.new("RGB", (880, 700), "#f4f3ef")
    pen = ImageDraw.Draw(sheet)
    samples = [(30, "Idle"), (160, "Travel"), (57, "Press"), (75, "Release"),
               (250, "Travel · left"), (305, "Press · left"), (330, "Release · left"), (358, "Blink · left")]
    for i, (frame, label) in enumerate(samples):
        im = Image.open(args.frames / f"face-{frame:04d}.png").convert("RGBA").crop((76, 0, 248, 290))
        x, y = i % 4 * 220 + 24, i // 4 * 330 + 40
        sheet.paste(im, (x, y), im)
        pen.text((x, y - 26), label, font=font, fill="#293533")
    pen.text((24, 674), "Actual Cocoa renderer · localized pixel expressions · unchanged shell and collar", font=font, fill="#293533")
    sheet.save(output / "bit-face-sequence.png")
    subprocess.run(["/opt/homebrew/bin/ffmpeg", "-y", "-loglevel", "error", "-framerate", "60", "-i", str(args.frames / "face-%04d.png"),
                    "-filter_complex", "color=c=0xf4f3ef:s=320x320:r=60[bg];[bg][0:v]overlay=shortest=1,fps=30,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=none",
                    "-loop", "0", str(output / "bit-face-reactions.gif")], check=True)
    files = [*ROOT.glob("Sources/Buddie*.*"), ROOT / "Sources/Preview.m", ROOT / "scripts/build-bit.py", Path(__file__),
             ROOT / "tests/test_motion.c", ROOT / "tests/test_character.m", *ROOT.glob("Characters/bit/*.png"),
             ROOT / "Characters/bit/buddy.json", ROOT / "Characters/bit/provenance.json",
             output / "bit-face-reactions.gif", output / "bit-face-sequence.png", output / "bit-face-live.png"]
    report = {
        "status": "Verified in the actual Cocoa renderer and live Studio through official CUA; native Codex cursor integration remains unfinished.",
        "source_fps": 60, "source_frames": 420, "gif_fps": 30, "sample_frames": [n for n, _ in samples],
        "behavior": {"press": "Immediate squint; interrupts a previous release", "release_seconds": 0.38,
                     "travel": "Attentive eyes during airborne travel", "idle": "Timed half/closed blink through all head directions",
                     "reduced_motion": "Static press feedback; no release sparkle, travel expression or timed blink"},
        "checks": ["30/60/120 Hz timing and interrupted clicks", "25 source expression poses preserve alpha and all non-eye pixels",
                   "25 Cocoa expression poses preserve silhouette, body, feet and neck registration",
                   "Every expression is distinct at all five perspectives; reversal preserves pose; left endpoint never wraps",
                   "Portable save/import retains all 54 frames and material masks; malformed direction timing/registration rejected",
                   "Existing motion, planted-contact, renderer and legacy pack regressions pass"],
        "live_ui": {"tool": "official CUA", "observed": "Travel focus and release sparkle with shell #EB504D",
                    "retained_screenshot": "docs/media/bit-face-live.png", "screenshot_processing": "Full app window downsampled to 960 px wide; saved as PNG",
                    "restored": "Bit selected with original size/proportions and red shell; saved Bit Ember reimported; walk paused"},
        "limitations": ["Native helper IPC is unresolved", "Expressions are pixel edits of ChatGPT-generated artwork; not new model-generated head identities",
                        "Miso is a generated concept only, pending a full rig and collection integration"],
        "sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)},
    }
    (ROOT / "docs/evidence/bit-faces.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Saved Bit's face animation, contact sheet and source-pinned review.")


if __name__ == "__main__":
    main()
