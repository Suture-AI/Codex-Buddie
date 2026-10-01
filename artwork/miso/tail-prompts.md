# Tail turnaround prompts

Generated sequentially in the same [ChatGPT conversation](https://chatgpt.com/c/6abddfa0-a020-83e8-b55a-95bb030c4fee), using Brave through official CUA. The UI did not expose the model identifier. Both downloaded sources are retained unchanged.

## First strip — rejected lighting

Selected the original complete Miso image before sending:

> Generate ONE production turnaround strip of the exact MISO cat robot's CORAL CURLED TAIL ONLY, using the FIRST complete MISO image in this conversation as the design reference. Exactly FIVE isolated tail pieces in ONE horizontal row, equal transparent cells: (1) curled tail projecting to image-left for the right-facing three-quarter body, (2) foreshortened left curl, (3) narrow almost edge-on curl seen behind a front-facing body, (4) foreshortened right curl, (5) curled tail projecting to image-right for the left-facing three-quarter body. All five pieces depict the SAME physical soft coral cat tail rotating with the torso, NOT different tail designs. The attachment root is the lowest point, at the horizontal center of each equal cell, with the same baseline and thickness in every frame. A short continuous stem joins that root to the curled tip; no floating curl or severed root. About 12 by 14 logical pixels per tail, enlarged with nearest-neighbor into crisp square pixel clusters. Keep the exact coral, salmon highlights, deep aubergine outline and simple cream highlight of the original. One fixed light from the UPPER LEFT OF THE IMAGE in every frame, never mirror the highlight. True transparent RGBA background and generous gutters. NO head, body, arms, legs, paws, boots, labels, arrows, shadows, checkerboard, scene, gradients or 3D gloss. Five isolated tails only. Generate the PNG now, using GPT Image 2.5 if available.

Downloaded `Five Coral Pixel Cat Tails.png` as `tail-turn-attempt-1.png`. The fourth and fifth tails put the cream highlight on the right, visibly mirroring the earlier views. Attachment roots also needed registration rather than assuming each cell's center.

## Corrected strip

With generated image 5 selected:

> Refine Generated image 5: keep the same five coral tail silhouettes and pixel scale, but correct the lighting in the FOURTH and FIFTH tails. They currently mirror the cream highlight onto the upper RIGHT. Move that bright cream highlight to the UPPER LEFT surface of each tail, and put dark coral shading on the lower RIGHT, consistent with the first three tails and a fixed light source from the upper-left of the image. Preserve all five distinct rotation views; do NOT simply mirror textures. Keep true transparent background, five isolated tails in one horizontal row, deep aubergine outlines, no labels. Generate the corrected PNG now.

Downloaded `Pixel-Art Cat Tail Sprite Strip.png` as `tail-turn-source.png`. Accepted for this rig pass: five continuous stems, fixed image-left lighting, true transparency and distinct front/three-quarter silhouettes. Common-scale extraction registers the bottom stem center of each view to one pivot. This is an implementation review, not user design approval.
