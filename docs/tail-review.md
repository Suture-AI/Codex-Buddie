# Miso tail motion review

Miso's tail now turns with its torso and keeps a continuous attachment at the
back of the hips. This improves the character rig; native Codex cursor
replacement remains unfinished. [Five poses](media/miso-tail-sequence.png),
[turn animation](media/miso-tail-turn.gif) and [walking/landing](media/miso-tail-gait.gif)
come from the actual Cocoa renderer.

| Before | After | Why |
| --- | --- | --- |
| The torso turned while the tail stayed on the screen's left. | Five authored perspectives share torso progress, and the root crosses the hips. | The tail belongs to the turning body rather than appearing attached to the screen. |
| The tail remained visible on one side in the front pose. | It is fully occluded behind the head and torso at front. | Provides consistent depth. The front render is pixel-identical with and without the tail. |
| Left-facing artwork reused the original tail. | A separate left-facing curl keeps image-left lighting and its own idle flex. | Avoids mirroring the highlight or losing the gentle idle motion. |
| The first generated strip mirrored the final two highlights. | A targeted ChatGPT correction replaced that strip; both sources and exact prompts are retained. | Preserves one light source through the turn. No unverified model version is claimed. |
| A 64-frame limit left too little space for additional articulated views. | Version 3 supports 96 logical frames; Miso uses 68. | Provides room for separate directions while retaining the 64 MB decoded-art budget, validation and shared image cache. Version 2 retains its original limit. |

Origin and physicality: each source stem registers to the same pivot, and all
nine tail textures remain four-connected after reduction and flex. Twenty-one
rendered turn samples keep the root attached while every boot pixel stays fixed.
The endpoint flex changes only its local tail region. Arms still retain their
screen-side textures during the torso turn, an unresolved visual limitation.

Interruptibility: tail selection uses the same normalized turn progress as the
torso. Changing the desired direction at the same progress produces identical
pixels. Existing motion-planner reversal tests pass. The turn adds no delayed
input or separate easing clock; pixel-art pose changes remain discrete.

Accessibility: Reduced Motion freezes both endpoint flexes while preserving
the appropriate facing artwork. Existing contact, viewport, expression,
customization and library tests pass. All 68 recolored frames and metadata
survive portable export/import; malformed directional pairs, timing and
registration are rejected.

**Block final motion sign-off.** The tail change passes this review. Directional
arms, non-pixel knees, broader anatomy, small-cursor legibility, live Studio
restart and actual native replacement remain open. No user approval of Miso,
live interaction with this build, or completed cursor integration is claimed.
See [source-pinned evidence](evidence/miso-tail.json) and
[reproduction commands](../artwork/miso/README.md#reproduce).
