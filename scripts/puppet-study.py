#!/usr/bin/env python3
"""Render the generated cutout study from BuddieMotion's exported trace.

This is an art/kinematics prototype, not a loadable character pack or live CUA.
Parts are original ChatGPT artwork. No generic face or replacement oval feet.
"""
import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artwork/pip/rig-study"


class Puppet:
    def __init__(self):
        self.parts = {p.stem: Image.open(p).convert("RGBA") for p in (ART / "parts").glob("*.png")}

    def layer(self, canvas, name, pivot, target, scale, angle=0, stretch=(1, 1)):
        """Affine local-pivot transform; one resampling pass per part."""
        part = self.parts[name]
        c, s = math.cos(angle), math.sin(angle)
        sx, sy = scale * stretch[0], scale * stretch[1]
        # PIL wants output -> input. Transparent fill does not alter the pivot.
        a, b, d, e = c / sx, s / sx, -s / sy, c / sy
        tx = pivot[0] - a * target[0] - b * target[1]
        ty = pivot[1] - d * target[0] - e * target[1]
        warped = part.transform(canvas.size, Image.Transform.AFFINE, (a, b, tx, d, e, ty), Image.Resampling.BICUBIC)
        canvas.alpha_composite(warped)

    def frame(self, pose, proportions=(1, 1, 1), facing_left=False):
        image = Image.new("RGBA", (320, 352))
        body_width, head_size, body_height = proportions
        body_y = pose["bodyY"] * 3
        facing = -1 if facing_left else 1
        lean = pose["lean"] * .5 * facing
        body = (150, 250 + body_y)
        # Far boot stays behind the body and nearer leg at every crossing.
        # Counter-transform the foot positions before mirroring the art. The
        # pose is in world axes; reflecting it would make planted soles slide.
        feet = [(150 + facing * foot[0] * 3, 315 + foot[1] * 3 - foot[2] * 3) for foot in pose["feet"]]
        self.layer(image, "tail", (355, 110), (150-34*body_width, 257 + body_y), .24, angle=math.sin(pose["phase"] * math.tau) * .04 * pose["walkWeight"])
        for i in (1, 0):
            foot = feet[i]
            hip = (150 + facing * (-17 if i == 0 else 17) * body_width, 267 + body_y + 17*(body_height-1))
            cuff = (foot[0] - (12 if i == 0 else 10), foot[1] - (34 if i == 0 else 31))
            length = math.dist(hip, cuff)
            angle = -math.atan2(cuff[0] - hip[0], cuff[1] - hip[1])
            self.layer(image, "nearLeg" if i == 0 else "farLeg", (88, 22), hip, .17, angle=angle, stretch=(1, max(.5, length / 22)))
            # Fixed sole orientation during contact; lift belongs to the motion core.
            self.layer(image, "nearBoot" if i == 0 else "farBoot", (209, 238) if i == 0 else (193, 218), foot, .17)
        swing = math.sin(pose["phase"] * math.tau) * .18 * pose["walkWeight"]
        self.layer(image, "paw", (105, 47), (150+41*body_width, 239 + body_y), .13, angle=-swing)
        self.layer(image, "body", (216, 254), body, .30, angle=lean, stretch=(body_width, body_height))
        self.layer(image, "paw", (105, 47), (150-46*body_width, 246 + body_y), .16, angle=swing)
        # Head pivot rests in the collar; width customization does not stretch it.
        blink = pose["time"] % 3.7
        head = "head-half" if 1.8 <= blink < 1.85 or 1.94 <= blink < 2 else "head-closed" if 1.85 <= blink < 1.94 else "head-open"
        self.layer(image, head, (128, 286), (150, 188 + body_y - 76*(body_height-1)), .89 * head_size, angle=lean * .6)
        return image.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if facing_left else image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    poses = json.loads(args.trace.read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    puppet = Puppet()
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15)
    still = puppet.frame(poses[0])
    light = Image.new("RGB", still.size, "#f4f3ef"); light.paste(still, mask=still.getchannel("A")); light.save(args.output / "assembled.png")
    proportions = Image.new("RGB", (1280, 392), "#f4f3ef")
    labels = ImageDraw.Draw(proportions)
    for i, (name, shape) in enumerate([("Original", (1,1,1)), ("Round", (1.22,1,0.94)), ("Tall", (.92,.96,1.18)), ("Big hood", (1,1.15,1))]):
        art = puppet.frame(poses[0], shape)
        proportions.paste(art, (i*320, 30), art); labels.text((i*320+22, 12), name, fill="#293533", font=font)
    proportions.save(args.output / "proportions.png")
    contact = Image.new("RGB", (1600, 744), "#f4f3ef")
    labels = ImageDraw.Draw(contact)
    for k, i in enumerate([38,46,54,62,70,210,215,220,230,240]):
        art = puppet.frame(poses[i]); x, y = k%5*320, k//5*372
        contact.paste(art, (x,y+20), art)
        labels.text((x+12,y+8), f'{poses[i]["time"]:.3f}s / phase {poses[i]["phase"]:.2f}', fill="#293533", font=font)
    contact.save(args.output / "contact.png")
    frames = []
    facing_left = False
    previous = poses[0]["x"]
    for i, pose in enumerate(poses):
        if pose["x"] != previous:
            facing_left = pose["x"] < previous
        previous = pose["x"]
        # Mirroring remains a study limitation; no original native cursor involved.
        art = puppet.frame(pose, facing_left=facing_left)
        stage = Image.new("RGB", (900, 450), "#f4f3ef")
        draw = ImageDraw.Draw(stage)
        for x in range(0, 900, 24):
            draw.line((x, 371, x + 5, 371), fill="#bdc3bd")
        stage.paste(art, (round(260 + pose["x"] * 3 - (170 if facing_left else 150)), 56), art)
        draw.text((28, 20), "PIP / Articulated movement study", fill="#293533", font=font)
        draw.text((28, 412), "Generated cutout artwork · native motion-core trace · not live Codex replacement", fill="#5b6861", font=font)
        if i % 2 == 0:
            frames.append(stage)
    frames[0].save(args.output / "motion.gif", save_all=True, append_images=frames[1:], duration=[33, 33, 34] * (len(frames) // 3), loop=0, disposal=2)


if __name__ == "__main__":
    main()
