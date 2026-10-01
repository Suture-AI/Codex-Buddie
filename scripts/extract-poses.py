"""Extract complete, separated generated poses with shared scale (requires Pillow).

Connected alpha regions locate the characters. Small detached details are grouped
with their nearest character. The supplied grid orders detected poses; it does
not slice the source into assumed equal cells. This is for grounded idle
sheets by default. Locomotion needs a reviewed registration file with source
origins, a shared scale and a target origin, preserving vertical displacement.
"""
import argparse
from collections import deque
import json
from pathlib import Path
from PIL import Image, ImageDraw


def components(alpha, threshold=16):
    width, height = alpha.size
    values = bytearray(alpha.tobytes())
    groups = []
    for origin in range(len(values)):
        if values[origin] < threshold:
            continue
        values[origin] = 0
        queue = deque([origin])
        x0 = x1 = origin % width
        y0 = y1 = origin // width
        area = 0
        while queue:
            i = queue.popleft()
            x, y = i % width, i // width
            area += 1
            x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
            for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if 0 <= nx < width and 0 <= ny < height:
                    j = ny * width + nx
                    if values[j] >= threshold:
                        values[j] = 0
                        queue.append(j)
        if area >= 8:
            groups.append({'area': area, 'bbox': [x0, y0, x1+1, y1+1]})
    return sorted(groups, key=lambda g: g['area'], reverse=True)


def center(box):
    return ((box[0]+box[2])/2, (box[1]+box[3])/2)


def extract(source, output, columns, rows, registration=None):
    image = Image.open(source).convert('RGBA')
    alpha = image.getchannel('A')
    if alpha.getextrema()[0] != 0:
        raise ValueError('Source has no fully transparent pixels; remove its background first.')
    # Detection at <=1024px keeps the flood fill bounded; crop original pixels.
    detection = alpha.copy()
    detection.thumbnail((1024, 1024), Image.Resampling.NEAREST)
    ratio_x, ratio_y = image.width/detection.width, image.height/detection.height
    groups = components(detection)
    count = columns * rows
    if len(groups) < count:
        raise ValueError(f'Expected {count} distinct poses, found {len(groups)} alpha groups.')
    main = groups[:count]
    if min(g['area'] for g in main) < max(g['area'] for g in main) * .45:
        raise ValueError('Pose areas differ too much; a character may be missing or split.')
    if len(groups) > count and groups[count]['area'] > min(g['area'] for g in main) * .2:
        raise ValueError('Unexpected large extra component; inspect the source before extraction.')
    # Assign detached details using actual detected centers.
    boxes = [g['bbox'][:] for g in main]
    centers = [center(b) for b in boxes]
    for group in groups[count:]:
        box = group['bbox']; x, y = center(box)
        nearest = min(range(count), key=lambda i: (centers[i][0]-x)**2+(centers[i][1]-y)**2)
        target = boxes[nearest]
        if abs(centers[nearest][0]-x) > (target[2]-target[0]) or abs(centers[nearest][1]-y) > (target[3]-target[1]):
            raise ValueError('Detached artwork lies far from every pose; inspect it before grouping.')
        boxes[nearest] = [min(target[0],box[0]),min(target[1],box[1]),max(target[2],box[2]),max(target[3],box[3])]
    boxes.sort(key=lambda b: center(b)[1])
    ordered = []
    for row in range(rows):
        run = sorted(boxes[row*columns:(row+1)*columns], key=lambda b: center(b)[0])
        if max(center(b)[1] for b in run)-min(center(b)[1] for b in run) > max(b[3]-b[1] for b in run)*.3:
            raise ValueError('Detected poses do not form the requested rows.')
        ordered.extend(run)
    boxes = [[max(0,int(b[0]*ratio_x)-3),max(0,int(b[1]*ratio_y)-3),min(image.width,int(b[2]*ratio_x)+4),min(image.height,int(b[3]*ratio_y)+4)] for b in ordered]
    widths = [b[2]-b[0] for b in boxes]; heights = [b[3]-b[1] for b in boxes]
    # Uniform fit; the source's pose geometry is never individually stretched.
    scale = min(216/max(widths),272/max(heights))
    if registration:
        if len(registration['origins']) != count or not 0 < registration['scale'] <= 4:
            raise ValueError('Registration needs one origin per pose and a positive shared scale.')
        scale = registration['scale']
    output.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGB', (columns*256, rows*320), '#f4f3ef')
    frames = []
    for i, box in enumerate(boxes):
        crop = image.crop(box)
        crop = crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
        frame = Image.new('RGBA',(256,320))
        if registration:
            origin = registration['origins'][i]
            target = registration['target']
            position = (round(target[0]+(box[0]-origin[0])*scale),round(target[1]+(box[1]-origin[1])*scale))
        else:
            position = ((256-crop.width)//2,296-crop.height)
        if position[0]<0 or position[1]<0 or position[0]+crop.width>256 or position[1]+crop.height>320:
            raise ValueError(f'Pose {i+1} does not fit its canvas; review scale and registration.')
        frame.alpha_composite(crop,position)
        frame.save(output/f'pose-{i:02d}.png',optimize=True)
        frames.append(frame)
        sheet.paste(frame,((i%columns)*256,(i//columns)*320),frame)
        ImageDraw.Draw(sheet).text(((i%columns)*256+12,(i//columns)*320+10),str(i+1),fill='#30353a')
    sheet.save(output/'contact.png')
    report={'source':str(source),'source_size':list(image.size),'expected_count':count,'detected_count':len(main),'boxes':boxes,'shared_scale':scale,'canvas':[256,320],'registration':registration or 'Centered by detected complete bounds; shared foot baseline. Review for drift; not suitable for jump poses.','height_ratio':max(heights)/min(heights),'width_ratio':max(widths)/min(widths),'visual_review':'pending'}
    (output/'geometry.json').write_text(json.dumps(report,indent=2)+'\n')
    return frames


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('output',type=Path)
    parser.add_argument('--columns',type=int,required=True)
    parser.add_argument('--rows',type=int,required=True)
    parser.add_argument('--registration',type=Path,help='Reviewed JSON with scale, origins, and target; preserves movement relative to those origins.')
    args=parser.parse_args()
    if not 1<=args.columns<=16 or not 1<=args.rows<=16:
        parser.error('Grid dimensions must be between 1 and 16.')
    extract(args.source,args.output,args.columns,args.rows,json.loads(args.registration.read_text()) if args.registration else None)
