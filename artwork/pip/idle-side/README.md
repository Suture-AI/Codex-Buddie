# Side-facing idle / blink

Six poses generated in ChatGPT using the eight-frame walk as a reference, then
edited with its Remove BG command. This preserves the walking camera at rest.
The app retains the last facing direction, including when Reduced Motion is on.

The source PNG has color in fully transparent pixels. Raw RGB previews can make
that look like a glow; compositing by the actual alpha produces clean edges.
`frames/contact.png` is an opaque light-background composite for reliable review.
Detection and shared-scale registration are recorded in `frames/geometry.json`.

The pack uses durations 2400/50/50/80/60/800 ms. Its tested render/export path is
documented in [the current review](../walk-refinement/review.json). The original
front-facing blink remains as historical art evidence, not the current idle.
