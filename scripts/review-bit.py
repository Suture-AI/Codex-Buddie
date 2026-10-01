#!/usr/bin/env python3
"""Build a review from actual Cocoa Bit exports, preserving nearest pixels."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("slow", type=Path)
    parser.add_argument("fast", type=Path)
    args = parser.parse_args()
    output = ROOT / "docs/media"
    names = ["Original","Round","Tall","Big-head","Original","Rose","Moss","Lilac"]
    pictures = [Image.open(args.slow / (name+".png")).convert("RGBA") for name in names]
    boxes = [p.getchannel("A").getbbox() for p in pictures]
    box = (min(b[0] for b in boxes)-4,min(b[1] for b in boxes)-4,max(b[2] for b in boxes)+4,max(b[3] for b in boxes)+4)
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc",16)
    small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc",12)
    sheet = Image.new("RGB",(1120,790),"#f4f3ef"); draw=ImageDraw.Draw(sheet)
    draw.text((24,18),"BIT / A smaller retro buddy · actual Studio renderer",font=font,fill="#293533")
    for i, (name, picture) in enumerate(zip(names,pictures)):
        x,y=i%4*280,i//4*360+45; crop=picture.crop(box)
        sheet.paste(crop,(x+35,y+28),crop)
        draw.text((x+25,y+5),name.replace("-"," "),font=font,fill="#293533")
        little=picture.crop(picture.getchannel("A").getbbox()); little.thumbnail((64,48),Image.Resampling.NEAREST)
        sheet.paste(little,(x+30,y+302),little)
        draw.text((x+90,y+323),"48 px character",font=small,fill="#64706a")
    draw.text((24,766),"Generated artwork, independent limbs, pixel blinks, authored head turn. Motion study; live cursor replacement remains unfinished.",font=small,fill="#64706a")
    sheet.save(output/"bit-studio-customization.png")
    bounds={}
    for path in sorted(args.slow.glob("limit-*.png")):
        im=Image.open(path).convert("RGBA"); b=im.getchannel("A").getbbox()
        assert b and b[0]>0 and b[1]>0 and b[2]<im.width and b[3]<im.height
        bounds[path.stem]=b
    for directory,pattern,name in [(args.slow,"slow-%04d.png","bit-studio-walk.gif"),(args.fast,"frame-%04d.png","bit-studio-fast-travel.gif")]:
        subprocess.run(["/opt/homebrew/bin/ffmpeg","-y","-loglevel","error","-framerate","60","-i",str(directory/pattern),"-filter_complex","fps=30,split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=none","-loop","0",str(output/name)],check=True)
    paths=[*ROOT.glob("Sources/Buddie*.*"),ROOT/"Sources/Preview.m",ROOT/"scripts/build-bit.py",ROOT/"scripts/review-bit.py",*ROOT.glob("Characters/bit/*.png"),ROOT/"Characters/bit/buddy.json"]
    paths += [output/name for name in ["bit-studio-customization.png","bit-studio-walk.gif","bit-studio-fast-travel.gif"]]
    report={"status":"User approved Bit's visual direction and requested a shorter neck. Updated one-row collar; animation polish and live CUA integration remain unfinished.",
            "source_fps":60,"gif_fps":30,"slow_frames":420,"fast_frames":240,"proportion_corner_bounds":bounds,
            "checks":["v1/v2/v3 regression tests","Bit portable pixel/turn metadata","Localized blink edits with unchanged alpha","Five authored head directions; reversal retraces the current turn","Independent feet from the motion core; generated walk sheets rejected","Reduced Motion and fixed hotspot","Eight proportion corners fit the review view"],
            "limitations":["Body still mirrors beneath authored head turns","Pixel joints and fast-travel landing need further visual polish","Native service IPC and true cursor-size legibility remain unresolved","Image model identifier not exposed by ChatGPT"],
            "sha256":{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}}
    (ROOT/"docs/evidence/bit-studio.json").write_text(json.dumps(report,indent=2)+"\n")
    print("Saved Bit's actual Cocoa motion, customization and geometry review.")


if __name__=="__main__":
    main()
