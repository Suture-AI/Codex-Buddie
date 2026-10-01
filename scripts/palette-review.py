#!/usr/bin/env python3
"""Compose Cocoa-exported palettes at reading and cursor sizes; never recolor here."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("frames", type=Path, help="BuddieLab --export-palettes output")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    names = ["Cobalt", "Rose", "Moss", "Lilac"]
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
    small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)

    def sprite(name, clip, frame):
        return Image.open(args.frames / f"{name}-{clip}-{frame:02d}.png").convert("RGBA")

    board = Image.new("RGB", (1024, 510), "#f4f3ef")
    draw = ImageDraw.Draw(board)
    for i, name in enumerate(names):
        x = i * 256
        draw.text((x + 24, 22), name, font=font, fill="#293533")
        art = sprite(name, "idle", 0)
        board.paste(art, (x, 54), art)
        draw.text((x + 24, 405), "64 px", font=small, fill="#5b6861")
        tiny = art.resize((51, 64), Image.Resampling.LANCZOS)
        board.paste(tiny, (x + 93, 397), tiny)
        dark = Image.new("RGB", (64, 76), "#27322f")
        dark.paste(tiny, (6, 6), tiny)
        board.paste(dark, (x + 169, 391))
    draw.text((24, 483), "PIP / Outfit colors · same original face, pose and alpha · native color renderer export", font=small, fill="#5b6861")
    board.save(args.output / "pip-outfit-colors.png")

    contact = Image.new("RGB", (1280, 1050), "#f4f3ef")
    labels = ImageDraw.Draw(contact)
    poses = [("idle", frame) for frame in range(6)] + [("walkRight", frame) for frame in range(8)]
    for i, (clip, frame) in enumerate(poses):
        x, y = i % 5 * 256, i // 5 * 350
        art = sprite("Rose", clip, frame)
        contact.paste(art, (x, y + 20), art)
        labels.text((x + 12, y + 8), f"Rose / {clip} {frame + 1}", font=small, fill="#293533")
    contact.save(args.output / "pip-outfit-contact.png")

    loop = []
    for frame in range(8):
        image = Image.new("RGB", (768, 310), "#f4f3ef")
        label = ImageDraw.Draw(image)
        for i, name in enumerate(names):
            art = sprite(name, "walkRight", frame).resize((192, 240), Image.Resampling.LANCZOS)
            image.paste(art, (i * 192, 35), art)
            label.text((i * 192 + 20, 14), name, font=small, fill="#293533")
        label.text((20, 286), "Palette consistency across all eight walk poses / pose study, not a live CUA recording", font=small, fill="#5b6861")
        loop.append(image)
    loop[0].save(args.output / "pip-outfit-walk.gif", save_all=True, append_images=loop[1:], duration=90, loop=0, disposal=2)


if __name__ == "__main__":
    main()
