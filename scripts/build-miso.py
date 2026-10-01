#!/usr/bin/env python3
"""Assemble Miso from reviewed ChatGPT source art into editable pixel parts."""
import hashlib
import json
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART, PACK = ROOT / "artwork/miso", ROOT / "Characters/miso"
COLORS = ["2C0F29", "492431", "392C31", "544144", "BDA588", "E6CFB0", "FCEFD5", "FFFAE7",
          "B84D46", "D76557", "FF8068", "FFAA87", "B4F0B9", "D7FFCD", "F5B09A", "705750"]
RGB = [tuple(bytes.fromhex(c)) for c in COLORS]
PALETTE = Image.new("P", (1, 1))
PALETTE.putpalette([v for c in RGB for v in c] + list(RGB[0]) * (256 - len(RGB)))


def pixel_image(image):
    alpha = image.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    result = image.convert("RGB").quantize(palette=PALETTE, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


def strip(filename, height, bottom):
    source = Image.open(ART / filename).convert("RGBA")
    boxes = []
    for i in range(5):
        left, right = round(i * source.width / 5), round((i + 1) * source.width / 5)
        b = source.crop((left, 0, right, source.height)).getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
        assert b and b[0] > 2 and b[2] < right - left - 2, "Review strip gutters before extracting frames."
        boxes.append((left + b[0], b[1], left + b[2], b[3]))
    scale = height / max(b[3] - b[1] for b in boxes)
    frames = []
    for b in boxes:
        part = source.crop(b)
        part = pixel_image(part.resize((round(part.width * scale), round(part.height * scale)), Image.Resampling.NEAREST))
        frame = Image.new("RGBA", (64, 64))
        frame.alpha_composite(part, (34 - part.width // 2, bottom - part.height))
        frames.append(frame)
    return frames, {"source_boxes": boxes, "shared_scale": scale, "bottom": bottom, "height": height}


def expressions(head):
    eyes = {(x, y) for y in range(12, 42) for x in range(10, 57)
            if (p := head.getpixel((x, y)))[3] and p[1] > p[0] * 1.1 and p[1] > p[2] * 1.1}
    remaining, groups = eyes.copy(), []
    while remaining:
        todo, group = [remaining.pop()], []
        while todo:
            x, y = todo.pop(); group.append((x, y))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    p = x + dx, y + dy
                    if p in remaining:
                        remaining.remove(p); todo.append(p)
        groups.append(group)
    assert len(groups) == 2, f"Expected two coherent eye clusters: {groups}"
    boxes = sorted((min(x for x, y in g), min(y for x, y in g), max(x for x, y in g) + 1, max(y for x, y in g) + 1) for g in groups)
    screen = Counter(p for y in range(64) for x in range(64) if (p := head.getpixel((x, y)))[3] and max(p[:3]) < 100).most_common(1)[0][0]
    mint, bright = (*RGB[12], 255), (*RGB[13], 255)
    result = {}
    for state in ("half", "closed", "focus", "press", "release"):
        image = head.copy(); draw = ImageDraw.Draw(image)
        for p in eyes:
            image.putpixel(p, screen)
        for eye, (x0, y0, x1, y1) in enumerate(boxes):
            cx, cy = (x0 + x1 - 1) // 2, (y0 + y1 - 1) // 2
            if state in ("half", "closed"):
                draw.line((x0 + 1, y1 - 2, x1 - 2, y1 - 2), fill=mint)
                if state == "half":
                    image.putpixel((x0, y1 - 1), mint); image.putpixel((x1 - 1, y1 - 1), mint)
            elif state == "focus":
                draw.rectangle((cx, y0, cx + 1, y1 - 1), fill=mint)
            elif state == "press":
                outer = x0 + 1 if eye == 0 else x1 - 2
                inner = outer + (2 if eye == 0 else -2)
                draw.line((outer, y0, inner, cy, outer, y1 - 1), fill=mint)
            else:
                draw.line((cx, y0, cx, y1 - 1), fill=mint)
                draw.line((x0 + 1, cy, x1 - 2, cy), fill=mint)
                image.putpixel((cx, cy), bright)
        assert image.getchannel("A").tobytes() == head.getchannel("A").tobytes()
        result[state] = image
    return result, boxes


def main():
    PACK.mkdir(parents=True, exist_ok=True)
    source = Image.open(ART / "concept-source.png").convert("RGBA")
    bounds = source.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
    crop = source.crop(bounds); crop.thumbnail((52, 56), Image.Resampling.NEAREST)
    base = Image.new("RGBA", (64, 64)); base.alpha_composite(crop, ((64 - crop.width) // 2, 60 - crop.height))
    base = pixel_image(base); base.save(ART / "canonical-64.png")
    definitions = {
        "head": ((0, 0, 64, 42), (34, 41), (34, 41)),
        "body": ((26, 41, 43, 54), (34, 53), (34, 53)),
        "pawNear": ((19, 43, 27, 53), (25, 44), (25, 44)),
        "pawFar": ((42, 44, 47, 53), (43, 45), (43, 45)),
        "tail": ((11, 38, 22, 50), (20, 49), (20, 49)),
        "legNear": ((25, 53, 31, 55), (28, 53), (29, 52)),
        "legFar": ((35, 53, 41, 55), (38, 53), (39, 52)),
        "bootNear": ((23, 54, 32, 60), (28, 59), (34, 59)),
        "bootFar": ((33, 54, 43, 60), (38, 59), (34, 59)),
    }
    images, parts = {}, {}
    def frame(name, duration=1):
        return {"image": name + ".png", "mask": name + "-mask.png", "duration": duration}
    for role, (rect, pivot, anchor) in definitions.items():
        im = Image.new("RGBA", (64, 64)); im.paste(base.crop(rect), rect[:2]); images[role] = im
        parts[role] = {"pivot": pivot, "anchor": [anchor[0] + 8, anchor[1] + 8], "scale": 1, "frames": [frame(role)]}
        if role.startswith("leg"):
            parts[role].update(cuff=[0, -5], span=2)
    # Remove neighboring head/hand pixels from the curled tail cutout.
    for y in range(38, 50):
        for x in range(11, 22):
            if (y < 43 and x >= 20) or (y >= 44 and x >= (19 if y < 47 else 20)):
                images["tail"].putpixel((x, y), (0, 0, 0, 0))
    images["tail"].putpixel((21, 43), (0, 0, 0, 0))
    # A one-pixel flex at the tip, tapering to zero at its attachment.
    for name, amount in (("tail-in", 1), ("tail-out", -1)):
        out = Image.new("RGBA", (64, 64))
        for y in range(38, 50):
            dx = round(amount * (49 - y) / 11)
            out.alpha_composite(images["tail"].crop((0, y, 64, y + 1)), (dx, y))
        images[name] = out
    parts["tail"]["frames"] = [frame("tail", 1), frame("tail-in", .28), frame("tail", .2), frame("tail-out", .28), frame("tail", .8)]
    heads, head_geometry = strip("turn-source.png", 38, 42)
    bodies, body_geometry = strip("body-turn-source.png", 13, 54)
    eye_boxes = {}
    for i in range(5):
        images[f"turn-{i}"] = heads[i]; images[f"body-turn-{i}"] = bodies[i]
        variants, eye_boxes[str(i)] = expressions(heads[i])
        for state, im in variants.items():
            images[f"turn-{i}-{state}"] = im
    for role, i in (("head", 0), ("headLeft", 4)):
        parts[role] = dict(parts["head"], frames=[frame(f"turn-{i}", 2.1), frame(f"turn-{i}-half", .05), frame(f"turn-{i}-closed", .09), frame(f"turn-{i}-half", .05), frame(f"turn-{i}", 1.25)])
    parts["headTurn"] = dict(parts["head"], frames=[frame(f"turn-{i}", .055) for i in range(5)])
    for state in ("half", "closed", "focus", "press", "release"):
        parts["head" + state.title()] = dict(parts["head"], frames=[frame(f"turn-{i}-{state}", .055) for i in range(5)])
    parts["body"]["frames"] = [frame("body-turn-0")]
    parts["bodyLeft"] = dict(parts["body"], frames=[frame("body-turn-4")])
    parts["bodyTurn"] = dict(parts["body"], frames=[frame(f"body-turn-{i}", .055) for i in range(5)])
    used = {f["image"][:-4] for p in parts.values() for f in p["frames"]}
    for name in sorted(used):
        im = images[name]; im.save(PACK / (name + ".png"))
        mask = Image.new("RGBA", im.size, (0, 0, 0, 255))
        for y in range(64):
            for x in range(64):
                p = im.getpixel((x, y)); color = p[:3]
                if p[3]:
                    mask.putpixel((x, y), (255 if color in RGB[4:8] else 0, 255 if color in RGB[8:12] + [RGB[14]] else 0, 255 if color in RGB[12:14] else 0, 255))
        mask.save(PACK / (name + "-mask.png"))
    manifest = {"version": 3, "id": "miso", "name": "Miso · Cat bot", "rig": {"stride": 8, "footSpacing": 5, "footLift": 2},
                "puppet": {"canvas": [80, 80], "hotspot": [42, 24], "height": 64, "motionScale": 1, "mirrorWalk": True, "pixelArt": True,
                           "proportions": {"torsoWidth": 1, "torsoHeight": 1, "headScale": 1},
                           "materials": [{"id": "shell", "name": "Cream shell", "channel": 0, "base": "#FCEFD5"},
                                         {"id": "suit", "name": "Coral suit", "channel": 1, "base": "#FF8068"},
                                         {"id": "face", "name": "Screen lights", "channel": 2, "base": "#B4F0B9"}], "parts": parts}}
    (PACK / "buddy.json").write_text(json.dumps(manifest, indent=2) + "\n")
    sources = [ART / name for name in ("concept-source.png", "turn-source.png", "body-turn-source.png")]
    provenance = {"sources": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
                  "requested_model": "GPT Image 2.5 if available", "verified_model": None, "builder": "scripts/build-miso.py",
                  "source_bounds": bounds, "parts": definitions, "head_geometry": head_geometry, "body_geometry": body_geometry, "eye_boxes": eye_boxes,
                  "processing": "Nearest-neighbor common-scale registration; 16-color palette; separate reviewed limbs; localized eye variants; one-pixel tail flex; material masks.",
                  "status": "Selectable original cat-bot rig; actual Cocoa motion/customization reviewed; no user design approval or native cursor integration claimed."}
    (PACK / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    print(json.dumps({"parts": len(parts), "frames": sum(len(p["frames"]) for p in parts.values()), "eye_boxes": eye_boxes}))


if __name__ == "__main__":
    main()
