#!/usr/bin/env python3
"""Build an editable pixel rig from Bit's original generated concept.

Rejected walking sheets are not used. Separate original parts use the motion
core's alternating contacts; blink textures are edited on the canonical pixels.
"""
import colorsys
import hashlib
import json
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artwork/bit"
PACK = ROOT / "Characters/bit"


def main():
    PACK.mkdir(parents=True, exist_ok=True)
    source = Image.open(ART / "concept-source.png").convert("RGBA")
    source_box = source.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
    crop = source.crop(source_box)
    crop.thumbnail((52, 56), Image.Resampling.NEAREST)
    base = Image.new("RGBA", (64, 64))
    base.alpha_composite(crop, ((64-crop.width)//2, 60-crop.height))
    alpha = base.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    # One common 16-color palette, sampled only from visible original pixels.
    # Reserve the rare mint/amber accents instead of letting frequency-based
    # quantization replace them with blue. Colors follow the generated concept.
    colors = ["0A0B39","171641","263781","32366D","4664C5","5579DD","708CEB","8DA9FB",
              "ACC0F6","7BF8CD","B0FFE0","45C9B6","FFCE42","DC991A","FFF4B4","657ED8"]
    palette = Image.new("P", (1,1))
    values = [int(h[i:i+2],16) for h in colors for i in (0,2,4)]
    palette.putpalette(values + values[:3] * (256-len(colors)))
    base = base.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    base.putalpha(alpha)
    base.save(ART / "canonical-64.png")
    definitions = {
        "head": ((0, 0, 64, 43), (32, 42), (32, 42)),
        "body": ((27, 42, 41, 53), (34, 51), (34, 51)),
        "pawNear": ((20, 43, 28, 53), (26, 44), (26, 44)),
        "pawFar": ((40, 44, 47, 53), (41, 45), (41, 45)),
        "legNear": ((26, 51, 33, 56), (29, 51), (29, 51)),
        "legFar": ((34, 51, 40, 56), (37, 51), (37, 51)),
        "bootNear": ((24, 55, 33, 60), (28, 59), (34, 59)),
        "bootFar": ((34, 55, 44, 60), (38, 59), (34, 59)),
        "tail": ((0, 0, 0, 0), (0, 0), (34, 51)),
    }
    images = {}
    for name, (rect, pivot, anchor) in definitions.items():
        image = Image.new("RGBA", (64, 64))
        image.paste(base.crop(rect), rect[:2]); images[name] = image
    turns = Image.open(ART / "turn-source.png").convert("RGBA")
    boxes = []
    for i in range(5):
        left, right = round(i*turns.width/5), round((i+1)*turns.width/5)
        box = turns.crop((left,0,right,turns.height)).getchannel("A").point(lambda a: 255 if a>=128 else 0).getbbox()
        assert box and box[0]>2 and box[2]<right-left-2, "Review the turn strip's gutters before cropping."
        boxes.append((box[0]+left, box[1], box[2]+left, box[3]))
    scale = 40/max(b[3]-b[1] for b in boxes)
    baseline = max(b[3] for b in boxes)
    # The generated turnaround added a 4–5 px neck absent from the concept.
    # Reviewed collar starts in the registered 64 px heads. Keep one collar
    # row and seat it at the common pivot, so head-size changes do not stretch
    # the neck and the chin no longer rises/falls through the turn.
    collar_starts = [40, 39, 39, 39, 38]
    for i, box in enumerate(boxes):
        # Register the neck, not the head's asymmetric silhouette center.
        neck = [(x,y) for y in range(box[3]-max(2,round((box[3]-box[1])*.07)),box[3])
                for x in range(box[0],box[2]) if turns.getpixel((x,y))[3]>=128]
        origin = (min(x for x,y in neck)+max(x for x,y in neck)+1)/2
        part = turns.crop(box)
        part = part.resize((round(part.width*scale),round(part.height*scale)),Image.Resampling.NEAREST)
        alpha = part.getchannel("A").point(lambda a:255 if a>=128 else 0)
        part = part.convert("RGB").quantize(palette=palette,dither=Image.Dither.NONE).convert("RGBA"); part.putalpha(alpha)
        out = Image.new("RGBA",(64,64))
        out.alpha_composite(part,(round(32+(box[0]-origin)*scale),round(43+(box[1]-baseline)*scale)))
        collar = collar_starts[i]
        assert out.getchannel("A").crop((0,collar,64,collar+1)).getbbox(), "Missing reviewed collar."
        compact = Image.new("RGBA", (64,64))
        compact.alpha_composite(out.crop((0,0,64,collar+1)), (0,42-collar))
        images[f"turn-{i}"] = compact
    images["head"] = images["turn-0"].copy()
    images["headLeft"] = images["turn-4"].copy()
    eye_boxes = {}
    for role in ("head","headLeft"):
        head = images[role]
        eye_pixels = {(x,y) for y in range(20,40) for x in range(12,52)
                      if head.getpixel((x,y))[3] and head.getpixel((x,y))[1]>180 and head.getpixel((x,y))[1]>head.getpixel((x,y))[2]*1.08}
        remaining = eye_pixels.copy(); groups = []
        while remaining:
            queue = [remaining.pop()]; group = []
            while queue:
                x,y = queue.pop(); group.append((x,y))
                for dx in (-1,0,1):
                    for dy in (-1,0,1):
                        p = (x+dx,y+dy)
                        if p in remaining: remaining.remove(p); queue.append(p)
            groups.append(group)
        assert len(groups)==2, (role,groups)
        boxes_for_eyes = [(min(x for x,y in g),min(y for x,y in g),max(x for x,y in g)+1,max(y for x,y in g)+1) for g in groups]
        eye_boxes[role] = boxes_for_eyes
        screen = Counter(head.getpixel((x,y)) for y in range(22,38) for x in range(23,43) if head.getpixel((x,y))[3] and max(head.getpixel((x,y))[:3])<80).most_common(1)[0][0]
        mint = Counter(head.getpixel(p) for p in eye_pixels).most_common(1)[0][0]
        for state in ("half","closed"):
            image = head.copy(); draw = ImageDraw.Draw(image)
            for p in eye_pixels: image.putpixel(p,screen)
            for x0,y0,x1,y1 in boxes_for_eyes:
                y=y1-2; draw.line((x0+1,y,x1-2,y),fill=mint)
                if state=="half": image.putpixel((x0,y+1),mint); image.putpixel((x1-1,y+1),mint)
            images[role+"-"+state]=image
    def frame(name, duration=1):
        return {"image": name+".png", "duration": duration, "mask": name+"-mask.png"}
    parts = {}
    for name, (rect, pivot, anchor) in definitions.items():
        parts[name] = {"pivot": pivot, "anchor": [anchor[0]+8, anchor[1]+8], "scale": 1, "frames": [frame(name)]}
        if name.startswith("leg"):
            parts[name].update(cuff=[0, -4], span=4)
    parts["headLeft"] = dict(parts["head"])
    for role in ("head","headLeft"):
        parts[role]["frames"] = [frame(role,2.3),frame(role+"-half",.05),frame(role+"-closed",.085),frame(role+"-half",.05),frame(role,1.1)]
    parts["headTurn"] = dict(parts["head"])
    parts["headTurn"]["frames"] = [frame(f"turn-{i}",.045) for i in range(5)]
    torsos = Image.open(ART / "body-turn-source.png").convert("RGBA")
    body_boxes = []
    for i in range(5):
        left, right = round(i*torsos.width/5), round((i+1)*torsos.width/5)
        box = torsos.crop((left,0,right,torsos.height)).getchannel("A").point(lambda a:255 if a>=128 else 0).getbbox()
        assert box and box[0]>2 and box[2]<right-left-2, "Review torso gutters."
        # The independent leg rig owns the hip joint, not this generated peg.
        body_boxes.append((left+box[0],box[1],left+box[2],box[3]-31))
    body_scale = 11/max(b[3]-b[1] for b in body_boxes)
    for i, box in enumerate(body_boxes):
        body = torsos.crop(box)
        body = body.resize((round(body.width*body_scale),11),Image.Resampling.NEAREST)
        alpha = body.getchannel("A").point(lambda a:255 if a>=128 else 0)
        body = body.convert("RGB").quantize(palette=palette,dither=Image.Dither.NONE).convert("RGBA"); body.putalpha(alpha)
        out = Image.new("RGBA",(64,64)); out.alpha_composite(body,(34-body.width//2,42))
        images[f"body-turn-{i}"] = out
    images["body"] = images["body-turn-0"].copy()
    images["bodyLeft"] = images["body-turn-4"].copy()
    parts["bodyLeft"] = dict(parts["body"],frames=[frame("bodyLeft")])
    parts["bodyTurn"] = dict(parts["body"],frames=[frame(f"body-turn-{i}",.045) for i in range(5)])
    for name, image in images.items():
        image.save(PACK / (name+".png"))
        mask = Image.new("RGBA", image.size, (0, 0, 0, 255))
        for y in range(64):
            for x in range(64):
                r,g,b,a=image.getpixel((x,y)); h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
                shell = 255 if a and .52 < h < .75 and v > .30 else 0
                face = 255 if a and .35 < h < .52 and s > .25 and v > .6 else 0
                signal = 255 if a and .08 < h < .20 and s > .25 and v > .5 else 0
                mask.putpixel((x,y),(shell,face,signal,255))
        mask.save(PACK / (name+"-mask.png"))
    manifest = {"version": 3, "id": "bit", "name": "Bit · Pixel bot", "rig": {"stride": 8, "footSpacing": 5, "footLift": 2},
                "puppet": {"canvas": [80,80], "hotspot": [42,24], "height": 64, "motionScale": 1, "mirrorWalk": True, "pixelArt": True,
                           "proportions": {"torsoWidth": 1, "torsoHeight": 1, "headScale": 1},
                           "materials": [{"id":"shell","name":"Shell","channel":0,"base":"#8095F2"}, {"id":"face","name":"Screen lights","channel":1,"base":"#81F8CA"}, {"id":"signal","name":"Antenna","channel":2,"base":"#FFD84B"}], "parts": parts}}
    (PACK / "buddy.json").write_text(json.dumps(manifest, indent=2)+"\n")
    provenance = {"source": "artwork/bit/concept-source.png", "source_sha256": hashlib.sha256((ART / "concept-source.png").read_bytes()).hexdigest(),
                  "requested_model": "GPT Image 2.5 if available", "verified_model": None, "processing": "scripts/build-bit.py: 64px nearest sampling; 16-color palette; reviewed cutout rectangles; pixel blink edits. Walking sheets were rejected and are not used.",
                  "source_bounds": source_box, "part_rectangles": {k:v[0] for k,v in definitions.items()}, "eye_boxes": eye_boxes,
                  "turn_source": "artwork/bit/turn-source.png", "turn_source_sha256": hashlib.sha256((ART / "turn-source.png").read_bytes()).hexdigest(),
                  "turn_geometry": {"source_boxes":boxes,"shared_scale":scale,"source_baseline":baseline,"target_neck":[32,42],"source_collar_rows":collar_starts,"retained_collar_rows":1},
                  "body_turn": {"source":"artwork/bit/body-turn-source.png","sha256":hashlib.sha256((ART/"body-turn-source.png").read_bytes()).hexdigest(),"trimmed_boxes":body_boxes,"shared_scale":body_scale,"target_top":42,"height":11},
                  "status": "User approved Bit's visual direction. Compact collar and coordinated head/torso turns; final animation polish remains pending."}
    (PACK / "provenance.json").write_text(json.dumps(provenance, indent=2)+"\n")
    print(json.dumps({"eyes":eye_boxes,"colors":len(set(base.getpixel((x,y))[:3] for y in range(64) for x in range(64) if base.getpixel((x,y))[3]))}))


if __name__ == "__main__":
    main()
