# Bit — original retro-bot study

The user supplied a compact blue Codex pet as the visual reference and asked
for a smaller retro 8-bit bot with much better animation. Bit follows that
direction with a blue screen-faced robot, simple mint eyes, short limbs and an
amber antenna. This is a candidate; user approval is pending.

![Actual Studio output](../../docs/media/bit-studio-customization.png)

## Generated sources

All four images were generated sequentially through ChatGPT in Brave in
[this art conversation](https://chatgpt.com/c/6abdd0db-1804-83e8-8ac9-505a7e27ca9b).
The prompt requested GPT Image 2.5 if available; the UI did not expose the image
model identifier. No exact model version is certified.

- [Concept source](concept-source.png), image 1: original complete Bit.
- [First walking attempt](walk-attempt-1.png), image 2: rejected because the
  bottom row reverses direction instead of completing the rightward gait.
- [Second walking attempt](walk-attempt-2.png), image 3: rejected because the
  second half still repeats the leading-foot relationship.
- [Head turn source](turn-source.png), image 4: five right/front/left heads.

The user's reference image was not added to the repository. Browser upload
was blocked by extension file access, so its visual direction was described
in the prompt. The generated robot is an original design.

## Processing and motion

`scripts/build-bit.py` resamples the concept to a logical 64 px canvas with
nearest sampling and binary alpha. The [canonical image](canonical-64.png)
uses a reviewed 16-color palette that reserves mint and amber accents. The
head, torso, paws, legs and boots are isolated from this art. Their source
rectangles are recorded in [the pack provenance](../../Characters/bit/provenance.json).
A transparent tail fills the current biped schema's unused tail slot.

The walking sheets are not used. Independent limbs follow the native motion
core; attachment coordinates snap to logical pixels. Fast travel uses its
bounded airborne gait. Paws move in opposing one-pixel steps. The renderer
preserves the input hotspot rather than moving the cursor to accommodate art.

Turn heads share one scale and neck registration. Each orientation keeps its
authored perspective; it is not flipped again. Reversing partway retraces the
turn progress. Right and left blink variants alter only localized screen-eye
pixels, with identical alpha and unchanged surrounding head art.

This remains a motion study. The body still mirrors beneath the authored head
turn, lighting/antenna perspective is imperfect, pixel joints need cleanup,
and fast-travel entry/landing needs further visual refinement. Native UI
observation was unavailable, so these are automated Cocoa exports rather than
a manually exercised UI or live CUA task.

## Reproduce

From the repository root, with Pillow, ffmpeg and Xcode Command Line Tools:

```sh
uv run --with pillow python scripts/build-bit.py
bash scripts/test-animation.sh
bash scripts/build.sh
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --self-test
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-puppet .build/bit-review bit
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-frames .build/bit-cocoa bit
uv run --with pillow python scripts/review-bit.py .build/bit-review .build/bit-cocoa
```

The PNG frame directories are regenerable intermediates. The retained
[walking GIF](../../docs/media/bit-studio-walk.gif),
[fast-travel GIF](../../docs/media/bit-studio-fast-travel.gif),
customization sheet and [review measurements](../../docs/evidence/bit-studio.json)
are the published outputs. The earlier Pip evidence pins revision
`ad4b018`; it is historical evidence rather than a checksum of today's source.
