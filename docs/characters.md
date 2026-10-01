# Character packs

A buddy is a local directory containing `buddy.json` and optional transparent
PNG artwork. No executable code, remote URLs, or credentials are needed. The
studio bundles Pip's complete-pose motion study, three earlier generated rig
fixtures and three procedural alternatives.

## Version 2: complete character poses

Use this format for new characters. Faces, clothing, hands and footwear stay in
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

`idle` is required. Optional clips are `idleLeft`, `walkRight`, `walkLeft`, `press` and
`release`. Each clip is an array of PNG filenames and frame durations in seconds
(1/120–30). At most 64 frames and 64 MB of decoded pixel artwork are accepted.
Duplicate filenames share the loaded image. Files remain local and data-only.

Idle follows elapsed time. Walking follows distance divided by `rig.stride`;
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

**Save a copy…** preserves every frame, its timing, size, stride and hotspot.
The studio hides face/body sliders for complete art because those features are
already painted into the frames. Editing them coherently requires new artwork.
The very small native software-cursor bounds limit detailed sprite legibility;
the enlarged studio does not prove that production sizing is solved.

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
| footSpacing | 6–14 | 10 |
| footSize | 5–11 | 8 |
| stride | 16–40 | 28 |
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

`BuddieJourney` is the **studio-only** motion driver: a smooth curved trajectory
with continuous position/velocity on retarget and zero velocity at arrival.
Native integration must supply its own real movement samples without adding a
second positional spring. The native shim currently receives no verified press,
drag or release events; click poses are triggered explicitly in the studio only.
