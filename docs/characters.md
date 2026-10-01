# Character packs

A buddy is a local directory containing `buddy.json` and optional transparent
PNG artwork. No executable code, remote URLs, or credentials are needed. The
studio opens with Bit's pixel rig and also bundles Pip's articulated and complete-pose studies, three earlier generated rig
fixtures and three procedural alternatives.

## Version 3: articulated character parts

[`Characters/pip-articulated/buddy.json`](../Characters/pip-articulated/buddy.json)
is a working example. This format separates generated artwork into nine named
parts: `head`, `body`, `tail`, `pawNear`, `pawFar`, `legNear`, `legFar`,
`bootNear`, `bootFar`. The nine required slots describe a biped; Bit supplies transparent tail art.
This is not yet a universal rig for arbitrary anatomy.

Use a `puppet` object instead of `sprites`. It shares version 2's `canvas`,
`hotspot`, `height`, `mirrorWalk` and optional `materials`. `parts` replaces
`clips`; each part contains its own `frames` array, a source-image `pivot`, a
canvas-space `anchor` and a `scale` (0.01–4). Legs also require a `cuff` offset
from the boot's sole and a positive `span`, their neutral displayed length.
Each part's frames share dimensions, at most 1024 pixels per dimension, and its
pivot must lie inside that artwork. The whole pack shares the 64-frame/64 MB
budget, local PNG restrictions and material-mask validation.

`motionScale` (0.25–8) maps motion units to canvas pixels. The renderer removes
this scale, canvas-to-points scale and view zoom from cursor travel before
updating the gait. This keeps planted soles fixed at different sizes. The
hotspot, foot contacts and boot orientation do not inherit torso bob/stretch.
The head and arm attachment positions follow the torso's proportions.

`proportions` supports `torsoWidth` (0.85–1.22), `torsoHeight` (0.85–1.18) and
`headScale` (0.85–1.15), each defaulting to 1. Studio exposes these alongside
size, stride, step height and material colors, with swatches and editable
`#RRGGBB` values. Complete valid hex values update the preview immediately;
unfinished/invalid entries restore the current color when editing ends.
Save/import preserves the
original part pixels, masks, blink timings, attachments and selected values.
Optional `headTurn` and `headLeft` parts use the same pivot/anchor/frame format.
The turn sequence runs from right through front to left. The renderer moves
through its duration in either direction; a mid-turn reversal retraces the
current progress. Head placement crosses its attachment offset gradually.
The left head can carry its own blink frames. Authored heads are not mirrored again.

Optional expression heads use the same right-to-left directional sequence as
`headTurn`:

| Part | Trigger |
| --- | --- |
| `headFocus` | Fast airborne travel |
| `headPress` | Button held; interrupts any previous reaction |
| `headRelease` | First 0.38 seconds after release |
| `headHalf` | Frames 1 and 3 of the neutral `head` blink timeline |
| `headClosed` | Frame 2 of that timeline |

These tracks require `headTurn` and `headLeft`. Each expression's pivot,
anchor, scale, image size, frame count and per-frame durations must match
`headTurn`; mismatches are rejected at import. Their frames represent
perspectives, not a time-based emotion cycle. The renderer selects the
current turn progress, including during a mid-turn reversal. Neutral blinking
continues through turns. Missing expression tracks preserve the older renderer.
Reduced Motion retains static press feedback and omits the travel, release
and blink embellishments. Bit includes 54 frames across 18 parts, within the
unchanged pack budget. See [the face animation](media/bit-face-reactions.gif),
[poses](media/bit-face-sequence.png) and [live Studio evidence](evidence/bit-faces.json).

Optional `bodyTurn` and `bodyLeft` must be supplied together. Their frames use
the body's neutral pivot and attachment, with right/front/left ordering matching
the head track. Both tracks share normalized progress; the head duration drives
the turn when present, otherwise the body duration does. Physical limbs keep
their screen-side attachments and highlights while the torso changes perspective.
Bit supplies five head and five torso directions; a direction reversal cannot
flip an intermediate pose. Older packs retain their mirrored-limb rendering.
Review the [Cocoa turn](media/bit-studio-turn.gif) and [five poses](media/bit-studio-turn.png).

Reimporting a saved identity reloads its collection entry. Different identities
can share a display name without losing menu entries or selection. Imported
packs remain session-local; keep the exported folder to reopen it later.
Changing selection commits the previous hex edit before replacing the model;
obsolete controls cannot repaint the new buddy even when material ids match.

Miso uses the same format with 58 frames, a three-pose curled tail, five authored
head/torso perspectives, and separate `shell`, `suit` and `face` materials.
Its [source art and reproduction steps](../artwork/miso/README.md) show how to
add another generated character without changing the motion core.

Set `pixelArt: true` in `puppet` (or version 2's `sprites`) for nearest-neighbor
sampling. Pixel parts snap their local attachments to canvas pixels, avoid
arbitrary head/body rotation and use small stepped paw motion. Raster contact
can therefore quantize by one logical pixel; the pointer hotspot never snaps.
Pixel calves sample their original texture in connected rows between the hip
and boot cuff, preserving a crisp grid at diagonals. For these parts, `pivot`
marks the first calf row and `span / scale` its source-row extent. Put only the
calf in that texture; keep boots in their own parts. Non-pixel rigs retain
rotated/stretched part rendering. Bit's revised boundaries and renderer have
60 raster checks for hip/cuff coverage and connected pixels.
Bit's 80 px canvas displays at a preferred 64 points, leaving the visible
character about 45 points tall before preview zoom. Studio limits its stride
slider to 8–16 motion units, where tiny limbs remain readable.

After fast travel, airborne landing feet stay beneath the moving hips until
touchdown; grounded contacts then remain fixed in world space. The lower foot
lands first over 0.14 seconds, the other over 0.20 seconds, with a restrained
body compression at first contact. The motion suite covers 63 moving/short-hop
landings at 30, 60 and 120 Hz, including the final contact frame.

Version 1 and 2 packs remain supported. Reduced Motion holds neutral feet and
the first idle textures, with direct press feedback when available. Bit's
expression edits change only the screen eyes, preserving the generated shell.

Review [Cocoa customization](media/pip-studio-customization.png),
[walking](media/pip-studio-walk.gif), [fast travel](media/pip-studio-fast-travel.gif)
and [verification evidence](evidence/articulated-studio.json). The renderer is
working in the lab; authored turns, more natural joints, final pixel-bot refinement,
production sizing and live native integration remain unfinished.

## Version 2: complete character poses

Use this format for complete authored poses. Faces, clothing, hands and footwear stay in
the artwork. The renderer adds no generic eyes, legs or tether. See
[`Characters/pip/buddy.json`](../Characters/pip/buddy.json) for a working pack.

```json
{
  "version": 2,
  "id": "my-pet",
  "name": "My Pet",
  "rig": { "stride": 32 },
  "sprites": {
    "canvas": [256, 320],
    "hotspot": [128, 48],
    "height": 64,
    "mirrorWalk": false,
    "directionalIdle": true,
    "clips": {
      "idle": [{ "image": "idle-00.png", "duration": 2.4 }],
      "walkRight": [{ "image": "walk-00.png", "duration": 0.125 }]
    }
  }
}
```

All PNGs share one canvas (16–1024 whole pixels per dimension), registration and
hotspot. `height` is the preferred canvas height in drawing points (32–96),
subject to the native view's available space. The hotspot lies inside the
canvas. Pip's `(128,48)` lies within its hood in every supplied frame; it maps
exactly to the native view's click coordinate. Mirroring uses this same pivot.

`idle` is required. Optional clips are `idleLeft`, `walkRight`, `walkLeft`, `turn`, `press` and
`release`. An optional `turn` follows the same right-to-left/retrace contract as
the articulated head turn, using complete poses. Each clip is an array of PNG filenames and frame durations in seconds
(1/120–30). At most 64 frames and 64 MB of decoded pixel artwork are accepted.
Duplicate filenames share the loaded image. Files remain local and data-only.

Idle follows elapsed time. Ordinary walking follows distance divided by `rig.stride`;
durations determine each pose's share of a cycle. Missing walking clips leave
the idle artwork visible. `mirrorWalk: true` explicitly allows the rightward
clip to serve left travel when no `walkLeft` exists. Mirroring also reverses
lighting and asymmetric details; Pip currently uses it only as a motion study.

`directionalIdle: true` declares that idle faces the same direction as
`walkRight`. After left travel, the renderer keeps that direction using
`idleLeft` if supplied, otherwise a mirrored idle if `mirrorWalk` is enabled.
It does not suddenly switch to a front-facing idle. The default is false for
older/front-facing packs. This flag and the authored frames survive save/import.

Press/release clips are explicit event-driven one-shots. Without them, the
studio applies a small whole-character press response around the fixed hotspot.
Reduced Motion holds the first pose. No interpolation or ghosted crossfade is
applied between unrelated character images. Smoothness therefore depends on
authored pose density and transitions; a higher frame count alone does not prove
correct alternating foot contacts or seamless turns.

**Save a copy…** preserves every frame, its timing, size, stride, hotspot and
material colors/masks.
The studio hides face/body sliders for complete art because those features are
already painted into the frames. Editing them coherently requires new artwork.
The very small native software-cursor bounds limit detailed sprite legibility;
the enlarged studio does not prove that production sizing is solved.

### Outfit colors

Bit exposes **Shell**, **Screen lights** and **Antenna** color wells.
Pip exposes independent **Raincoat** and **Boots** color wells in the studio.
Colors retain the generated shading and highlights; the face and limbs still
come from the original poses. Reset restores the original palette. A saved copy
keeps the source art, masks and selected colors, so it remains editable after
import. Existing packs without materials keep their original behavior.

Optional `sprites.materials` defines up to three materials:

```json
"materials": [
  { "id": "coat", "name": "Raincoat", "channel": 0,
    "base": "#0850EF", "color": "#D65378" }
]
```

Each frame then needs a `mask` alongside `image` and `duration`. A mask is an
opaque 8-bit RGBA PNG matching the canvas: red is channel 0, green channel 1,
blue channel 2. Zero protects the source pixel; 255 fully selects it. Alpha must
be 255 everywhere, including the background. The renderer preserves the artwork's
own alpha. Overlapping channel weights are normalized. Material ids and channels
must be unique. Mask files use the same local-path, size and shared 64 MB decoded
artwork budget as poses.

`base` describes the original material hue/saturation/value, not an average over
the entire image. The color operation shifts that material's hue and scales its
saturation and brightness while retaining desaturated specular highlights.
Selected colors are quantized to `#RRGGBB` so export/import is reproducible.
Choosing the original colors returns the exact source images. Recolored output
uses 8-bit channels. Frames are prepared when choosing an appearance and cached;
no color work runs on each animation tick. That cache can add up to one RGBA
rendered copy of each source frame to memory.

[`pip-outfit-colors.png`](media/pip-outfit-colors.png) compares four palettes at
full and 64 px sizes. [`pip-outfit-walk.gif`](media/pip-outfit-walk.gif) checks
consistency across the eight walking poses; it is not a live CUA recording.
Pip's masks are generated by `scripts/pip-materials.py`, a reviewed segmentation
specific to this artwork. New characters need their own reviewed material masks;
do not assume this cobalt/orange selection works for other designs.

## Version 1: earlier layered rig

```json
{
  "version": 1,
  "id": "my-buddy",
  "name": "My Buddy",
  "colors": { "body": "#C2EB89", "ink": "#283C31", "accent": "#F2A899" },
  "rig": { "width": 34, "height": 32, "eyeSpacing": 13, "stride": 28 },
  "art": { "body": "body.png", "foot": "foot.png" }
}
```

Omit either artwork slot to use the procedural renderer for that part. The foot
image is reused for both feet. Colors use `#RRGGBB`. The face, blush and feet use
the pack colors; a generated body's colors remain in its PNG.

| Rig setting | Range | Default |
| --- | --- | --- |
| width | 24–42 | 34 |
| height | 24–40 | 32 |
| cornerRadius (procedural body) | 4–21 | 13 |
| eyeSpacing | 8–20 | 13 |
| eyeSize | 3–7 | 5 |
| faceY | −7–7 | 0 |
| footSpacing | 4–14 | 10 |
| footSize | 5–11 | 8 |
| stride | 8–40 | 28 |
| footLift | 2–8 | 5 |

Values are logical drawing units. The renderer scales artwork to available
cursor bounds. The body is centered at x=34 with its bottom at y=54; eyes sit at
y=38+faceY. The fixed marker is at (8,8) in drawing space and maps to the native
view's hotspot. Body bob, lean, squash and facial movement never shift it.

Use **Save a copy…** to write the current settings and artwork together. Existing
packs are never overwritten. The save is staged, validated with the same loader,
then moved into place. Re-import the folder in a future session. Imported packs
are read into memory; source files remain unchanged.

Artwork filenames must stay directly inside the folder. Symlinks escaping the
folder and remote paths are rejected. Each PNG needs an alpha channel, dimensions
from 16 to 4096 pixels, and a file size up to 16 MB. The manifest is limited to
64 KB. For a small cursor, cropped 256–512 px assets are more than sufficient.

## Generate a new buddy in ChatGPT

1. Generate one complete original character: face, hands, feet and outfit. Aim
   for a readable silhouette at 48–96 px, with soft forms and restrained detail.
2. Use that same image as the reference for one animation clip at a time. Request
   transparent PNGs, full silhouettes, consistent camera/scale and generous gaps.
3. Inspect actual alpha and detected character bounds before extracting frames.
   `scripts/extract-poses.py` detects connected artwork, rather than assuming cells.
4. Register locomotion against reviewed source landmarks with `--registration`.
   Preserve lift and body bob; do not independently resize or bottom-align steps.
5. Inspect the loops, opposing feet, wardrobe and lighting at small sizes on light
   and dark backgrounds. Reject repeated poses and identity changes.
6. Add a version 2 manifest, import it, then verify the actual app's drawing,
   movement, turns, click response and Reduced Motion. A hero image is not motion QA.

The bundled Sprout, Mochi and Orbit images were generated individually through
ChatGPT in Brave on 2026-09-30 at the user's request. The prompts requested GPT
Image 2.5. **The ChatGPT image UI did not expose the exact model identifier**, so
the repo does not certify that version. Each pack has a `provenance.json` with
the downloaded file's SHA-256 and processing record. These are original project
characters, not copies of OpenAI's cursor or pet artwork.

Body descriptions: Sprout is a velvety moss-green bean with succulent leaves;
Mochi is a peach-pink dumpling with small rounded cat ears; Orbit is a lavender
ceramic robot with antenna nubs and a warm apricot side accent. All use restrained
detail, gentle upper-left lighting, and an empty central face area for the rig.

## Motion integration

`BuddieMotionUpdate` consumes actual anchor coordinates and monotonic time. It
outputs body, face and independent foot poses; it never writes the cursor
position. Gait phase advances by distance, contact points remain in world space,
and a pause or teleport resets safely. Motion is normalized by drawing scale.
At more than four strides per second the core uses a bounded airborne gait;
its cycle is capped at 5 Hz so rapid cursor travel does not drag a planted leg
across the screen. It returns below 2.5 strides per second, landing each foot
over 0.18/0.24 seconds. This is a stylized fast-travel fallback, not a finished
authored run cycle. Neither gait changes the input pointer trajectory.

`BuddieJourney` is the **studio-only** motion driver: a smooth curved trajectory
with continuous position/velocity on retarget and zero velocity at arrival.
Native integration must supply its own real movement samples without adding a
second positional spring. The native shim currently receives no verified press,
drag or release events; click poses are triggered explicitly in the studio only.
