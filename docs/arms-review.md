# Directional arm motion review

| Before | After | Why |
| --- | --- | --- |
| Pixel walking shifted the complete arm up/down, including its shoulder. | Source rows swing from a fixed shoulder; the hand moves farther than the sleeve. | Keeps a continuous attachment as arm length and torso proportions change. [BuddiePuppet.m:51](../Sources/BuddiePuppet.m#L51). |
| Bit and Miso reused one arm texture on each side through every turn. | Each has ten generated views, registered to common shoulder pivots. | Near/far silhouettes change with the torso while lighting is preserved. [pixel_parts.py:5](../scripts/pixel_parts.py#L5). |
| The original foreground arm stayed in front in both directions. | Depth changes with yaw; both arms sit behind the torso in the central view. | Avoids an abrupt depth swap at the midpoint. [BuddiePuppet.m:123](../Sources/BuddiePuppet.m#L123). |
| Arm swing had the same projection in every perspective. | Horizontal swing narrows to zero at front and changes sign through the turn. | Prevents sideways waving when forward/back motion should project into depth. [BuddiePuppet.m:114](../Sources/BuddiePuppet.m#L114). |
| There was no portable directional-arm contract. | Four optional tracks require a complete set, matching geometry/timing and valid spans inside the images. | Imported art keeps its joints, timing and frame budget; older packs keep their own rendering. [BuddieCharacter.m:359](../Sources/BuddieCharacter.m#L359). |
| Miso's lighting follow-up still mirrored sleeve glints. | Four quantized poses receive 14 logged color-pixel retouches, preserving alpha and mittens. | Corrects the remaining light inconsistency without claiming the generator fixed it. [build-miso.py:171](../scripts/build-miso.py#L171). |
| The two new Bit alternatives differed in shape and highlights. | The simpler continuous mittens are included; the alternate remains in source provenance. | Preserves the approved soft pixel direction. [selection notes](../artwork/bit/arm-prompts.md). |

**Origin, physicality & cohesion.** [Turns](media/arms-turn-sequence.png) retain
the compact collar, head identity and planted feet. [Bit](media/bit-arm-gait.gif)
and [Miso](media/miso-arm-gait.gif) show four anatomy variants through walking,
flight, landing, reversal and clicks. [Selected frames](media/arms-gait-sequence.png)
show the longer arms. 240 actual Cocoa arm rasters remain four-connected and
cover the fixed shoulder at every tested length, torso proportion, direction
and swing phase. Head/antenna perspective still needs review; arbitrary body
types and non-pixel knees remain unfinished.

**Performance.** The new pixel arms draw ten source rows per arm from already
decoded/recolored images. No image generation or decoding happens on animation
ticks. 2,112 export frames fit their canvases. This is not evidence of frame-time
performance inside the real Codex host; that measurement remains open.

**Interruptibility & timing.** Arms use the existing torso turn progress and
walking phase. Desired-direction changes do not reset the pose; rendered pixels
are identical at the same progress, and the two sides of the front midpoint
match. No additional easing clock, delayed input or UI navigation animation is
introduced. The existing 30/60/120 Hz motion checks pass.

**Accessibility.** Reduced Motion preserves the selected facing with static
arms. Existing face, tail, foot-contact, anatomy/viewport and library checks
pass. All Miso colored frames and both packs' geometry survive portable import;
missing tracks, invalid spans and mismatched registration/timing are rejected.
See [source-pinned checks](evidence/directional-arms.json).

**Block final motion sign-off.** These arms pass the described review. Native
IPC/replacement, production cursor sizing, live Studio restart, additional body
types and the remaining visual findings still prevent product completion.

Reproduce from the repository root:

```sh
uv run --with pillow python scripts/build-bit.py
uv run --with pillow python scripts/build-miso.py
bash scripts/build.sh
bash scripts/test-animation.sh
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --self-test
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-turn .build/arms-bit-turn bit
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-turn .build/arms-miso-turn miso
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-anatomy .build/arms-bit-anatomy bit
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-anatomy .build/arms-miso-anatomy miso
uv run --with pillow python scripts/review-arms.py .build/arms-bit-turn .build/arms-miso-turn .build/arms-bit-anatomy .build/arms-miso-anatomy
```
