# Complete-pose animation contract

Version 2 packs now play complete generated poses, preserving the face, hands
and footwear established in canonical art. Version 1 still supports the earlier
layered rig. See [the implemented schema](characters.md). Pip is a working
blink/four-key-pose motion study, not a final animation-quality reference.

## Minimum useful clips

| Clip | Visual contract | Driver |
| --- | --- | --- |
| Idle | Breathing/settling with occasional coherent blinks | Elapsed idle time |
| Walk right | Full alternating contact, passing and lifted steps | Distance traveled |
| Walk left | Same construction/lighting, opposite travel | Distance traveled |
| Press | A deliberate small interaction pose; exact anchor retained | Real pointer down |
| Release | Short return to the canonical resting stance | Real pointer up |

Generate one coherent clip at a time, grounded in the same original character.
Start with idle and rightward gait to prove identity and locomotion before
expanding the collection. Use mirroring only when it does not change asymmetric
markings or directional lighting. A generated hero image alone is not motion QA.

## Registration and playback

- Every frame shares the same pixel canvas, scale and local hotspot. Register
  by stable landmarks/baseline. Do not independently fit each pose to its box.
- Preserve intentional body bob and lifted feet while correcting accidental
  canvas drift. Do not flatten each frame's feet to a common line.
- Position belongs to the real cursor driver. Pose playback never adds a second
  positional spring, changes click coordinates, or delays arrival.
- Advance gait by world distance. Pause/retarget/reverse without a hard visual
  snap or a stationary running loop. Preserve the final contact on stopping.
- Do not infer clicks or agent session states from an unmoving pointer.
- Reduced Motion holds a still pose and provides a restrained explicit press
  state. A static preview does not verify native drag or cancellation behavior.

## Acceptance

Inspect frame counts, complete silhouette and transparent edges before assembly.
Review loops at actual size on light/dark backgrounds. Reject identity/wardrobe
drift, rubbery limb morphs, foot swaps, cuts between unrelated angles, cropped
extremities, flickering lighting, inconsistent registration and ghosted
crossfades. Verify the decoded assets and the runtime's rendered output.

The supported native integration and its visibility/press/drag events remain
separate unresolved product gates. Sprite work must not imply those are solved.

## Current gaps against this contract

Pip still cuts between its three-quarter idle and more side-facing walk view;
there are no authored turn/settle clips. Its four walk poses need in-betweens and
stronger leg separation. Left travel mirrors lighting. The runtime retains the
last distance phase while decelerating, then changes to idle; this does not yet
guarantee a planted final contact. Press/release use a restrained whole-image
response until authored poses are supplied. These are visible quality gaps,
not checks satisfied by the pack loader or motion unit tests.
