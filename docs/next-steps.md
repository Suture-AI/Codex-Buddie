# Next implementation brief

## User's intended experience

The buddy completely replaces the visible computer-use mouse. The gray arrow must never peek out from underneath. When Codex moves along its curved, swooping path to another control, the buddy walks or runs along that path, turns with its direction, stops at the destination and performs a click animation.

The follower in this repository is a feasibility prototype. Shipping an offset companion, hiding a pointer behind a larger sprite, or demonstrating replacement only in our own canvas does not fulfill the full product requirement.

## What is ready for Enzo

**Art direction update:** the user rejected the first Sprout/Mochi/Orbit visual
direction as too generic and insufficiently polished. Keep these as rig fixtures,
not approved final characters. The next direction needs a distinctive silhouette,
coherent materials and facial design, and no dangling cursor tether. Develop a
complete character concept before separating it into animation parts. The user
then selected a graphic designer-toy direction and clarified the key reference:
ChatGPT Pets. Keep it **soft, simple and cute**, with a much stronger identity
and more polished art than the first pear-like Sprout. Detailed sci-fi robots
are not the current direction. Study the built-in pets' clear silhouettes,
expressive complete poses and coherent facial/limb design; create original art.

**Latest user feedback:** Pip is cool, but the intended design is a smaller
retro 8-bit bot like the provided Codex pet reference. Keep soft chunky pixel
shapes, a compact body and expressive screen eyes; improve the animation
substantially. Develop the original Bit candidate, with proper steps, blinks
and turns. Pip is now a reusable motion/customization study.

**Bit · Pixel bot** is now the default Studio selection. It has a compact
pixel rig, independent limbs, preserved-alpha screen blinks, editable shape and
three colors, and five coordinated head/torso directions with reversible turn progress.
The generated walk sheets were rejected after anatomy review. See
[Bit's review](evidence/bit-studio.json) and [source notes](../artwork/bit/README.md).
The user approved Bit's appearance and asked for a shorter neck. The generated
head strip's long neck is now a one-row collar, registered at the head pivot
through all five directions and tested with the user's smaller-head proportions.
The color-well mismatch reproduced as a blue exported pack despite a red swatch.
Wells now send live changes, and hex inputs provide exact editable colors. Official
CUA verified red rendering, red saved material values, reopen and repeated import.
See the [live UI capture](media/bit-live-color.png) and [verification record](evidence/bit-live-color.json).
Repeated imports also exposed a duplicate-name popup bug, now fixed and covered
by Cocoa regression checks. Native macOS color-panel interaction itself remains
unverified because CUA did not open that panel reliably.

The whole torso now turns with the head, and actual boot pixels stay fixed
during a stationary turn. See [the turn](media/bit-studio-turn.gif).
Next improve pixel leg joints and fast-travel landing, add richer expressions,
and persist the installed collection/settings across launches. Native integration and
production cursor size remain separate unresolved gates.

The root Studio also includes **Pip · Articulated**, a version-3 pack with nine
independent generated parts, stable blink textures, live torso width/height and
head size, editable outfit colors and portable save/import. Slow feet stay
planted across six tested size/zoom combinations. Fast cursor travel uses a
bounded airborne gait with a capped 5 Hz cycle and short landings. It exposed
and fixed a leg-stretch failure that the earlier offline study did not cover.
Review [the actual Cocoa outputs](media/pip-studio-customization.png),
[walking](media/pip-studio-walk.gif), [fast travel](media/pip-studio-fast-travel.gif)
and [validation evidence](evidence/articulated-studio.json).

The earlier full-pose Pip pack remains compatible. Authored turns, final joint
quality, production sizing and real interaction events remain open. Native CUA
UI observation recovered and the Studio's proportion/size controls have been
exercised directly. An isolated development-signed runtime still returns
`Sky Computer Use native pipe startup failed` while the original CUA runtime
can observe and control the Studio; see the development-signing evidence. The user's latest
feedback does not approve Pip as the final character.

The studio also retains three earlier ChatGPT-generated body packs, independent
animated faces/feet, distance-driven planted gait, continuous curved retargeting,
live proportions/face/gait controls, and pack import/export. `BuddieMotion.c` is
plain C; `BuddieCharacter.m` owns pack validation and `BuddieView.m` renders poses.
Run `bash scripts/test-animation.sh`. Review `docs/media/buddies-walking.gif` and
[the pack specification](characters.md). These components are independent of the
blocked live service connection and can be reused by a supported integration.

The repository root contains the native renderer experiment already pushed by a collaborator: it substitutes the cursor content view in a lab and stages an isolated service copy. Its documented live blocker is `SkyIPCRequirement.Error.teamNotFound` during native IPC signing validation. A matching-team Apple development signature was also tested; native inventory still fails. See [the probe evidence](development-signing.md). Preserve the original service and its authentication requirements.

The independent passive experiment under `experiments/passive-overlay/` adds:

- A native macOS app that builds with `bash experiments/passive-overlay/scripts/build.sh`.
- Three original character presets and a local PNG sprite-pack loader.
- Passive tracking of actual native computer-use cursor windows, observed during official CUA actions.
- An ordinary preview window and click-test control for repeatable UI checks.
- 36 passing core checks via `bash experiments/passive-overlay/scripts/test.sh`.
- Versioned evidence locating native cursor classes, the `SoftwareCursor` asset, browser image renderer and private cursor-location callback.

Read the [runtime research](../experiments/passive-overlay/docs/research.md) and the root README. The native and browser renderers are different integrations. The passive prototype uses public macOS APIs to observe a private app's window naming convention; it does not hook the actual renderer. Its observed newer service versions have not been certified for the root native shim.

## Resolve this before claiming live replacement

Prove a way to suppress or replace the original cursor **at its rendering source** while retaining its exact movement signal. The current 15 Hz window-position follower cannot guarantee this: it can lag, uses an uncalibrated anchor and does not change captured previews.

The installed browser renderer already has position, motion path, arrival timing, visibility and an image asset. Its cursor component is a promising integration point if a supported hook or controlled host is available. The native helper uses compiled cursor/style classes and an asset catalog; no public customization option was found. The root experiment illustrates the native code-signing/IPC constraint with an isolated copy. Neither investigation modifies the installed vendor app in place.

Check where native motion actually runs: retaining the original window does not establish that animations applied to a detached original view or layer will transfer to the replacement. Verify curved motion, rotation and scaling before claiming that the shim inherits all native animation. A rendering substitution that preserves the animated view/layer may be necessary.

A renderer we control can implement true replacement directly. That demonstrates the design but must be labeled as a separate integration, not advertised as changing stock ChatGPT/Codex. Keep passive tracking as a diagnostic/fallback mode.

## Animation contract

1. Input coordinates and the visual hotspot are exact and independent of the body animation.
2. Position and arrival time come from the actual motion driver. Preserve its curve instead of adding a second trailing spring.
3. Select facing from the curve's tangent. Animate feet according to distance traveled so they do not slide during speed changes.
4. Idle, locomotion, turning, pointer-down, dragging, pointer-up and hidden are separate states. Trigger click poses only from actual input events.
5. Pause/approval/error states need real session events; do not infer them from an unmoving pointer.
6. Reduced Motion uses a still character with immediate positioning and clear click feedback.
7. Character rendering must remain outside model screenshots unless deliberately tested as part of an integration.

## Acceptance gates

- A recording of a real CUA task shows the buddy moving between three controls and clicking correctly.
- No gray arrow, outline or glow appears at rest, through transparent parts of the sprite, during motion, at arrival, on hide/show or after errors.
- The original curve and arrival timing are preserved; the buddy visibly walks/runs rather than gliding as a static image.
- Pointer input still lands exactly on the intended control; the buddy cannot intercept input or take keyboard focus.
- State explicitly whether native desktop, built-in browser and picture-in-picture each pass. A passing result on one surface does not establish the others.
- Installation and uninstall work on a clean Mac, with no disabled system protections and no persistent process left behind.

## Release work after the integration is proven

Save preferences, add robust pack installation, solve detailed-character sizing
within the native software cursor's tiny bounds, pin the intended agent session,
measure latency/CPU/battery use, test multiple monitors, sign and notarize
downloadable builds, and publish an explicit compatibility list. Generated
character packs can then reuse the validated sprite pipeline.
