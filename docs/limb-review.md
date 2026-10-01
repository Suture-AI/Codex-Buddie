# Limb customization review

Reviewed against the user's intended complete cursor replacement and animated,
highly customizable buddies. This change improves the Studio rig; the overall
product remains incomplete. Artwork comes from the existing ChatGPT-generated
Bit, Miso and Pip packs. No new model attribution or user design approval is
claimed by this review.

| Before | After | Why |
| --- | --- | --- |
| Arms had a fixed length. | `armLength` scales each arm around its shoulder pivot. | Changes silhouette without detaching the arm from the torso. See [renderer](../Sources/BuddiePuppet.m). |
| Leg length was fixed by the original pack. | `legLength` raises or lowers the complete upper body over the original soles. | Keeps the head-to-body registration and short collar while changing the legs. |
| Boots had a fixed width. | `bootWidth` widens the original artwork about its sole, with unchanged vertical scale and adjusted cuff offset. | The boot can change shape without moving its ground height. |
| Stance came only from the pack's rig. | `stanceWidth` changes the step planner's resting spacing. | Planted feet continue to cancel exact cursor travel, including when the stance changes mid-walk. See [motion input](../Sources/BuddieView.m). |
| Pixel calves were a single straight sampled strip. | Two bones fold at a knee, sampling the original texture on the pixel grid. | Lifted feet have a joint, while both endpoints and four-connected pixels remain intact. |
| Body, size and gait settings shared one list. | Immediate Body/Limbs/Gait sections expose matching controls. | The larger control set remains readable without covering the palette or adding navigation animation. See [Studio](../Sources/Preview.m). |
| Slider values were visible only through their position. | Live numeric and percentage readouts use monospaced digits. | Users can reproduce proportions without guessing or shifting the label layout. |
| Sliders used 24-point frames. | Sliders and the new section selector have 40-point frames with separate hit areas. | Makes customization easier to target while keeping rows and colors separate. |
| Pack and library settings contained three body proportions. | Four optional limb proportions use shared bounds, default to 1, and survive copy, export/import, reset and library reopening. | Older packs keep their original anatomy; saved custom designs remain portable. See [pack model](../Sources/BuddieCharacter.m) and [library](../Sources/BuddieLibrary.m). |
| Studio construction happened only during app launch. | The same construction code can build hidden Cocoa views for layout review and controller tests. | Allows honest visual inspection while live CUA window lookup is unavailable. These exports are labelled and do not claim live input verification. |

Origin, physicality and cohesion: the four variants preserve the compact neck
and coherent source artwork in [the collection comparison](media/anatomy-collection.png).
[Bit](media/bit-anatomy.gif), [Miso](media/miso-anatomy.gif) and
[Pip](media/pip-anatomy.gif) go through walking, flight, moving landing,
reversal and click feedback. [Selected gait frames](media/anatomy-gait-sequence.png)
retain readable joint/contact detail. Pip still uses a straight textured calf;
physical limbs and Miso's tail retain screen-side attachments during torso turns.
Those are remaining motion findings, not final-quality approvals.
The subsequent [tail review](tail-review.md) resolves Miso's tail finding;
these original anatomy media and their source-pinned evidence are retained.
The later [arm review](arms-review.md) adds directional arms and fixed shoulders.

Interruptibility and timing: stance changes are handled by the existing step
planner. Tests cover 288 combinations of anatomy, size and 30/60/120 Hz, with
49,440 fixed contacts including live stance changes. No new UI tween or delayed
interaction is introduced. Existing interrupted turns/clicks and landings pass.

Accessibility: static Reduced Motion geometry remains stable. The new sections
use native AppKit controls with named sliders and numeric readouts. All 128
extremes of seven proportions fit both tested viewports at idle and in flight
(1,536 overflow checks rendered beyond the normal clip). This establishes
containment for these three bundled rigs, not small-cursor legibility or support
for arbitrary anatomy. Live keyboard/pointer and restart verification remain
open: official CUA returns `cgWindowNotFound` for Studio and Activity Monitor.

**Block final motion sign-off.** The new anatomy controls and pixel knees pass
the described review. Directional limb/tail art, non-pixel knees, live Studio
verification, production cursor sizing and actual native cursor replacement
still require work. See [source-pinned evidence](evidence/limb-customization.json)
and the full [acceptance gates](next-steps.md).

Reproduce the artifacts:

```sh
bash scripts/build.sh
bash scripts/test-animation.sh
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --self-test
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-anatomy .build/anatomy-bit bit
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-anatomy .build/anatomy-miso miso
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-anatomy .build/anatomy-pip pip-articulated
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-studio .build/anatomy-layout
uv run --with pillow python scripts/review-anatomy.py .build/anatomy-bit .build/anatomy-miso .build/anatomy-pip .build/anatomy-layout
```
