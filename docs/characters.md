# Character packs

A buddy is a local directory containing `buddy.json` and optional transparent
PNG artwork. No executable code, remote URLs, or credentials are needed. The
studio bundles three generated characters and three procedural alternatives.

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

1. Start a new chat and generate **one body shell**. Specify a front view, an
   original silhouette, a blank face area, and no facial features or limbs.
2. Request a true transparent PNG with generous margins, no ground shadow,
   no text and no baked checkerboard. Download the original file.
3. Check the alpha channel; a black editor background does not prove transparency.
4. Trim unused transparent margin, preserve antialiased edges, and reduce the
   longest edge to about 512 px. Choose width/height that preserve the silhouette.
5. Add `buddy.json`, import it, and tune the eyes and gait. Check both studio size
   and native size, movement in both directions, click poses and Reduced Motion.

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
