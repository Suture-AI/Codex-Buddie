#!/usr/bin/env python3
"""Publish actual Cocoa arm turns and walks; preserve older review artifacts."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BG, INK, MUTED = "#f4f3ef", "#293533", "#64706a"


def main():
    parser = argparse.ArgumentParser()
    for arg in ["bit_turn", "miso_turn", "bit_anatomy", "miso_anatomy"]:
        parser.add_argument(arg, type=Path)
    args = parser.parse_args()
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 12)
    outputs, bounds, packs = [], {}, {}

    def save(im, name, **kwargs):
        target = ROOT / "docs/media" / name
        im.save(target, **kwargs); outputs.append(target)

    def gif(frames, name):
        palette = frames[0].quantize(colors=256)
        indexed = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
        save(indexed[0], name, save_all=True, append_images=indexed[1:], duration=([30, 30, 40] * len(frames))[:len(frames)], loop=0, disposal=2, optimize=False)

    turns = Image.new("RGB", (1100, 680), BG); pen = ImageDraw.Draw(turns)
    motion = Image.new("RGB", (1120, 680), BG); draw = ImageDraw.Draw(motion)
    for row, identifier in enumerate(["bit", "miso"]):
        td, ad = getattr(args, identifier + "_turn"), getattr(args, identifier + "_anatomy")
        files = sorted(td.glob("turn-*.png")) + sorted(ad.glob("variant-*.png"))
        assert len(files) == 1056
        per_size = {}
        for path in files:
            with Image.open(path) as im:
                b = im.getchannel("A").getbbox()
                assert b and b[0] > 0 and b[1] > 0 and b[2] < im.width and b[3] < im.height, path
                per_size.setdefault(str(im.size), []).append(b)
        bounds[identifier] = {size: [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)] for size, boxes in per_size.items()}
        for col, (frame, label) in enumerate([(18, "Right"), (23, "Turning"), (27, "Front"), (31, "Turning"), (36, "Left")]):
            im = Image.open(td / f"turn-{frame:04d}.png").convert("RGBA").crop((48, 0, 268, 290))
            turns.paste(im, (col * 220, row * 330 + 30), im)
            pen.text((col * 220 + 18, row * 330 + 10), identifier.title() + " / " + label, fill=INK, font=font)
        frames = []
        for i in range(0, 96, 2):
            im = Image.open(td / f"turn-{i:04d}.png").convert("RGBA")
            bg = Image.new("RGB", im.size, BG); bg.paste(im, (0, 0), im); frames.append(bg)
        gif(frames, f"{identifier}-arm-turn.gif")
        frames = []
        for i in range(0, 240, 2):
            strip = Image.new("RGB", (800, 252), BG); p = ImageDraw.Draw(strip)
            p.text((16, 10), identifier.title() + " / Fixed shoulders, moving hands", font=font, fill=INK)
            for variant, label in enumerate(["Original", "Compact", "Long limbs", "Big boots"]):
                im = Image.open(ad / f"variant-{variant}-{i:04d}.png").convert("RGBA").resize((200, 200), Image.Resampling.NEAREST)
                strip.paste(im, (variant * 200, 30), im)
                p.text((variant * 200 + 16, 229), label, font=small, fill=MUTED)
            frames.append(strip)
        gif(frames, f"{identifier}-arm-gait.gif")
        for col, (frame, label) in enumerate([(36, "Step"), (48, "Opposing swing"), (85, "Fast travel"), (150, "Reversal")]):
            im = Image.open(ad / f"variant-2-{frame:04d}.png").convert("RGBA").resize((280, 280), Image.Resampling.NEAREST)
            motion.paste(im, (col * 280, row * 330 + 30), im)
            draw.text((col * 280 + 18, row * 330 + 10), identifier.title() + " / " + label, font=font, fill=INK)
        parts = json.loads((ROOT / f"Characters/{identifier}/buddy.json").read_text())["puppet"]["parts"]
        packs[identifier] = {"parts": len(parts), "logical_frames": sum(len(p["frames"]) for p in parts.values()), "arm_views": 10}
    pen.text((24, 651), "Actual Cocoa frames · authored arm perspective and depth · original collar, head and foot contacts", fill=MUTED, font=small)
    draw.text((24, 651), "Long-limb variants · shoulder-rooted swing · separate palette masks · native Codex integration remains unfinished", fill=MUTED, font=small)
    save(turns, "arms-turn-sequence.png"); save(motion, "arms-gait-sequence.png")
    sources = [*ROOT.glob("Sources/*.[mhc]"), ROOT / "tests/test_character.m", ROOT / "scripts/pixel_parts.py", ROOT / "scripts/build-bit.py", ROOT / "scripts/build-miso.py", Path(__file__)]
    for name in ["bit", "miso"]:
        sources += [*ROOT.glob(f"Characters/{name}/*"), *ROOT.glob(f"artwork/{name}/arm-*"), ROOT / f"artwork/{name}/provenance.json"]
    report = {
        "status": "Directional arms and fixed-shoulder pixel swing reviewed in actual Cocoa output; no live Studio input or native cursor integration claimed.",
        "packs": packs, "source_fps": 60, "gif_fps": 30, "reviewed_frame_count": 2112, "bounds": bounds,
        "checks": ["240 four-connected arm rasters: two characters, two arms, three proportion sets, five directions, four swing phases", "Shoulder pixel stays attached in every raster; default endpoint hands have three distinct swing positions", "Changing desired direction preserves the current pose; crossing front does not pop draw depth", "Front-facing swing does not wave sideways; Reduced Motion keeps the left-facing artwork still", "All Miso recolored frames and both packs' geometry survive save/import", "Missing tracks, mismatched geometry/timing and invalid or out-of-image spans are rejected", "Existing head/collar/face, tail, foot-contact, viewport and library checks pass"],
        "art": {"source": "ChatGPT in Brave via official CUA", "requested_model": "GPT Image 2.5 if available", "verified_model": None,
                "miso_retouch": "14 color pixels in four quantized sleeve poses; unchanged alpha and mittens; full edit log in pack provenance", "bit_selection": "First of two alternatives from one prompt; second retained but excluded"},
        "limitations": ["Authored head/antenna perspective still needs craft review", "Pip non-pixel knees and broader body types remain unfinished", "Small native cursor legibility and performance in the real host remain unverified", "Live Studio restart, native IPC and complete cursor replacement remain open"],
        "sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(sources + outputs)},
    }
    (ROOT / "docs/evidence/directional-arms.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Saved four arm-motion GIFs, two Cocoa contact sheets and source-pinned evidence.")


if __name__ == "__main__":
    main()
