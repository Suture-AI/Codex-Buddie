"""Register generated part sheets without mirroring their light or silhouette."""
from PIL import Image


def arm_sheet(path, colors, height=10):
    source = Image.open(path).convert("RGBA")
    palette = Image.new("P", (1, 1))
    rgb = [tuple(bytes.fromhex(c)) for c in colors]
    palette.putpalette([v for c in rgb for v in c] + list(rgb[0]) * (256 - len(rgb)))
    boxes = []
    for row in range(2):
        top, bottom = round(row * source.height / 2), round((row + 1) * source.height / 2)
        for col in range(5):
            left, right = round(col * source.width / 5), round((col + 1) * source.width / 5)
            b = source.crop((left, top, right, bottom)).getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
            assert b and min(b[0], b[1], right - left - b[2], bottom - top - b[3]) > 2, "Review the arm-sheet gutters."
            boxes.append((left + b[0], top + b[1], left + b[2], top + b[3]))
    scale = height / max(b[3] - b[1] for b in boxes)
    frames, roots = [], []
    for b in boxes:
        part = source.crop(b)
        part = part.resize((round(part.width * scale), round(part.height * scale)), Image.Resampling.NEAREST)
        alpha = part.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
        part = part.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
        part.putalpha(alpha)
        shoulder = alpha.crop((0, 0, part.width, 1)).getbbox()
        assert shoulder, "The top row must contain the shoulder opening."
        root = (shoulder[0] + shoulder[2] - 1) // 2
        frame = Image.new("RGBA", (64, 64))
        frame.alpha_composite(part, (34 - root, 43))
        frames.append(frame); roots.append([root, 0])
    return frames, {"source_boxes": boxes, "shared_scale": scale, "height": height,
                    "resized_roots": roots, "registered_shoulder": [34, 43]}


def install_arms(images, parts, frames, anchors, duration, height=10):
    def frame(name, seconds=1):
        return {"image": name + ".png", "mask": name + "-mask.png", "duration": seconds}
    for row, role in enumerate(("pawNear", "pawFar")):
        names = [role if i == 0 else f"{role}-turn-{i}" for i in range(5)]
        for i, name in enumerate(names):
            images[name] = frames[row * 5 + i]
        parts[role] = {"pivot": [34, 43], "anchor": anchors[row], "scale": 1, "span": height, "frames": [frame(role)]}
        parts[role + "Turn"] = dict(parts[role], frames=[frame(name, duration) for name in names])
        parts[role + "Left"] = dict(parts[role], frames=[frame(names[-1])])
