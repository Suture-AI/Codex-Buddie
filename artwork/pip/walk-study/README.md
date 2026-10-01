# Pip walk key poses

Generated in the same ChatGPT conversation, grounded in Pip's original image.
The first eight-frame attempt repeated the same leading boot and was rejected.
This replacement uses four key poses with changed arm and near/far leg layering.

`registration.json` records manually reviewed source-space origins and shared
row ground lines. One scale applies to every frame. Unlike idle extraction,
this preserves movement relative to the ground; feet are not independently
snapped to a line. `frames/geometry.json` records detected bounds.

Reproduce extraction with Pillow:

```sh
uv run --with pillow python scripts/extract-poses.py \
  artwork/pip/walk-study/source.png artwork/pip/walk-study/frames \
  --columns 2 --rows 2 --registration artwork/pip/walk-study/registration.json
```

The ten-frame pack (six blink, four walk) is integrated with the actual AppKit
renderer. See [the rendered study](../../../docs/media/pip-motion-study.gif),
[contact sheet](../../../docs/media/pip-render-contact.png), and [review](review.json).

This is not a completed smooth walk. It needs in-betweens, clearer opposing foot
contacts, a natural idle transition and left-facing art with consistent lighting.
The candidate direction has not been approved by the user. Native CUA replacement
remains blocked separately by IPC signing validation.
