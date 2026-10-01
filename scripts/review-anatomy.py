#!/usr/bin/env python3
"""Assemble review artifacts from the Cocoa anatomy/layout export commands."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BG = "#f4f3ef"
INK = "#293533"
MUTED = "#64706a"
NAMES = ["Original", "Compact", "Long limbs", "Big boots"]
VALUES = [(1, 1, 1, 1), (.7, .65, 1.2, 1.1), (1.3, 1.8, .85, .9), (.9, 1.3, 1.35, 1.4)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("bit", type=Path)
    parser.add_argument("miso", type=Path)
    parser.add_argument("pip", type=Path)
    parser.add_argument("layout", type=Path)
    args = parser.parse_args()
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 12)
    outputs = []

    def save(im, name, **options):
        target = ROOT / "docs/media" / name
        im.save(target, **options)
        outputs.append(target)

    gallery = Image.new("RGB", (1120, 1070), BG)
    pen = ImageDraw.Draw(gallery)
    pen.text((24, 18), "BUDDIE / Editable limbs", fill=INK, font=font)
    pen.text((24, 44), "Actual Cocoa output · arms, legs, boot width and stance · original head-to-body registration", fill=MUTED, font=small)
    bounds = {}
    for row, (identifier, title) in enumerate([("bit", "Bit · Pixel bot"), ("miso", "Miso · Cat bot"), ("pip", "Pip · Articulated")]):
        directory = getattr(args, identifier)
        pen.text((24, 76 + row * 315), title, fill=INK, font=font)
        frame_bounds = []
        for variant in range(4):
            files = sorted(directory.glob(f"variant-{variant}-*.png"))
            assert len(files) == 240
            for file in files:
                with Image.open(file) as im:
                    b = im.getchannel("A").getbbox()
                    assert b and b[0] > 0 and b[1] > 0 and b[2] < 400 and b[3] < 400, file
                    frame_bounds.append(b)
            im = Image.open(files[0]).convert("RGBA").resize((250, 250), Image.Resampling.NEAREST if identifier != "pip" else Image.Resampling.LANCZOS)
            x, y = variant * 280 + 15, 93 + row * 315
            gallery.paste(im, (x, y), im)
            pen.text((x + 9, y + 240), NAMES[variant], fill=INK, font=font)
            pen.text((x + 9, y + 265), " / ".join(f"{round(n * 100)}%" for n in VALUES[variant]), fill=MUTED, font=small)
        bounds[identifier] = [min(b[0] for b in frame_bounds), min(b[1] for b in frame_bounds), max(b[2] for b in frame_bounds), max(b[3] for b in frame_bounds)]
        frames = []
        for frame in range(0, 240, 2):
            strip = Image.new("RGB", (800, 252), BG)
            draw = ImageDraw.Draw(strip)
            draw.text((16, 10), title + " / Limbs in motion", font=font, fill=INK)
            for variant in range(4):
                im = Image.open(directory / f"variant-{variant}-{frame:04d}.png").convert("RGBA")
                im = im.resize((200, 200), Image.Resampling.NEAREST if identifier != "pip" else Image.Resampling.LANCZOS)
                strip.paste(im, (variant * 200, 30), im)
                draw.text((variant * 200 + 16, 229), NAMES[variant], font=small, fill=MUTED)
            frames.append(strip)
        palette = frames[0].quantize(colors=256)
        indexed = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
        save(indexed[0], f"{identifier}-anatomy.gif", save_all=True, append_images=indexed[1:], duration=[30, 30, 40] * 40, loop=0, disposal=2, optimize=False)
    pen.text((24, 1041), "Values: arm length / leg length / boot width / stance. These are Studio renders; stock Codex integration is still unfinished.", fill=MUTED, font=small)
    save(gallery, "anatomy-collection.png")

    # A motion contact sheet preserves individual readable landing poses.
    gait = Image.new("RGB", (1120, 740), BG)
    draw = ImageDraw.Draw(gait)
    for row, identifier in enumerate(["bit", "miso"]):
        for col, (frame, label) in enumerate([(45, "Walking"), (85, "Fast travel"), (105, "Landing"), (150, "Reversal")]):
            im = Image.open(getattr(args, identifier) / f"variant-2-{frame:04d}.png").convert("RGBA").resize((280, 280), Image.Resampling.NEAREST)
            x, y = col * 280, row * 350 + 35
            gait.paste(im, (x, y), im)
            draw.text((x + 20, y - 20), identifier.title() + " / " + label, fill=INK, font=font)
    draw.text((24, 711), "Long-limb variants · knee fold, connected calf texture and planted sole height · actual Cocoa frames", fill=MUTED, font=small)
    save(gait, "anatomy-gait-sequence.png")

    for section in ["body", "limbs", "gait"]:
        im = Image.open(args.layout / f"{section}.png").convert("RGB")
        labelled = Image.new("RGB", (960, 732), BG)
        labelled.paste(im, (0, 0))
        ImageDraw.Draw(labelled).text((24, 709), "Cocoa layout export · not a live screenshot · native window interaction still awaits CUA verification", fill=MUTED, font=small)
        save(labelled, f"studio-{section}-layout.png")
    sources = [*ROOT.glob("Sources/Buddie*.*"), ROOT / "Sources/Preview.m", ROOT / "tests/test_character.m", ROOT / "tests/test_library.m", ROOT / "tests/test_motion.c", Path(__file__), ROOT / "scripts/build.sh", ROOT / "scripts/test-animation.sh"]
    report = {
        "status": "Editable limb anatomy and pixel knee folding verified in Cocoa exports and automated checks; live UI verification is pending.",
        "new_controls": {"armLength": [.7, 1.3], "legLength": [.65, 1.8], "bootWidth": [.8, 1.35], "stanceWidth": [.8, 1.4]},
        "variants": dict(zip(NAMES, VALUES)),
        "review": {"frames_per_character": 960, "source_fps": 60, "gif_fps": 30, "all_frame_bounds": bounds, "layout": "Hidden native Cocoa views built by the same Studio code; no live CUA screenshot claimed."},
        "checks": {"contact_scenarios": 288, "planted_contacts": 49440, "connected_calf_rasters": 108, "viewport_checks": 1536, "viewport_scope": "All 128 extremes of seven proportions, three bundled articulated buddies, idle/flight, 300x300 Studio and 20x23 software layout; rendered beyond clip to detect overflow.", "other": ["Default anatomy for older packs", "Copy/save/import and library persistence", "Bad values rejected", "UI sections show matching controls without palette overlap", "Static Reduced Motion geometry", "Existing motion, faces, registration and portable-pack tests"]},
        "limitations": ["CUA returns cgWindowNotFound for Studio and Activity Monitor; native input/relaunch is unverified", "Pip uses its existing straight textured legs; knee folding applies to pixel rigs", "Arms retain screen-side artwork through authored torso turns", "Stock Codex cursor replacement, release installation and production sizing remain unfinished"],
        "sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(sources + outputs)},
    }
    (ROOT / "docs/evidence/limb-customization.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Saved anatomy galleries, motion GIFs, labelled layout exports and source-pinned evidence.")


if __name__ == "__main__":
    main()
