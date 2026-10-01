"""Make a pose contact sheet from BuddieLab --export-frames output (Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw

frames = Path('.build/motion-frames')
out = Image.new('RGB', (1120, 720), '#f7f7f1')
draw = ImageDraw.Draw(out)
for row, name in enumerate(('Sprout', 'Mochi', 'Orbit')):
    for col, frame in enumerate((20, 48, 80, 180)):
        image = Image.open(frames / f'frame-{row * 240 + frame:04d}.png').convert('RGB')
        mask = Image.new('L', image.size)
        mask.putdata([
            255 if i // image.width > 100 and (min(rgb) < 150 or max(rgb) - min(rgb) > 40) else 0
            for i, rgb in enumerate(image.getdata())
        ])
        x0, y0, x1, y1 = mask.getbbox()
        crop = image.crop((x0-12, y0-12, x1+12, y1+12))
        crop.thumbnail((220, 175), Image.Resampling.LANCZOS)
        out.paste(crop, (col*280+25, row*240+55))
        pose = ('idle', 'walking', 'turning', 'click')[col]
        draw.text((col*280+26, row*240+24), f'{name} / {pose}', fill='#29392d')
out.save('docs/media/motion-contact.png')
