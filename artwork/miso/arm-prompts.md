# Miso arm prompts

Submitted sequentially through official CUA in Brave, in the existing Miso art
conversation. The original complete character was selected for the first
prompt. ChatGPT did not expose the image model identifier.

## First sheet

> Generate ONE production part sheet of MISO's two tiny ARMS ONLY, matching the FIRST complete cream-and-coral cat robot in this conversation. Exactly TEN isolated arm pieces in a strict grid: TWO horizontal rows, FIVE equal transparent cells per row. Each arm is one connected short coral sleeve plus one simple cream mitten, deep aubergine outline, no fingers. TOP ROW is the arm on the LEFT SIDE OF THE IMAGE through five torso views: right-facing three-quarter (near arm, broad), midway to front, front, midway toward left, left-facing three-quarter (far arm, narrow). BOTTOM ROW is the arm on the RIGHT SIDE OF THE IMAGE in those same five torso views: far/narrow to front to near/broad. The arms stay on their respective image sides; do not swap or mirror them between rows. The top of each sleeve is the shoulder attachment, on a common baseline and centered in its cell; the hand hangs directly below and slightly outward. About 6 logical pixels wide and 10 high, with near views about 8 wide and far views about 5. Keep all ten the same physical length, same simple silhouette and exact MISO palette. Flat squared shoulder opening, no shoulder ball or peg. One stationary light from UPPER LEFT OF THE IMAGE for every view, especially the last two columns; do NOT mirror highlights. Crisp square pixel clusters enlarged with nearest neighbor. True transparent RGBA background and wide gutters between all parts. No heads, torsos, legs, boots, tails, labels, arrows, shadows, extra detached bits, checkerboard or scene. Generate the PNG now using GPT Image 2.5 if available.

`Pixel Art Arm Sprite Sheet.png` is retained unchanged as
`arm-turn-attempt-1.png`. The late columns mirrored the sleeve highlights.

## Lighting follow-up

> Correct only the lighting in this ten-arm sheet. The last two columns of BOTH rows incorrectly mirror the bright sleeve highlight onto image-right. Keep the same ten silhouettes, perspectives, two-row layout, coral sleeves and cream mittens. A single light is fixed at the UPPER LEFT OF THE WHOLE IMAGE: put the small bright coral/cream highlight on the image-left edge of EVERY sleeve, with darker coral on its image-right edge. Even an arm that faces left must remain lit from image-left. Do not flip, mirror or rotate any silhouette to make this change. Preserve continuous shoulder-to-hand connections, identical pixel scale and real transparency. No new parts, labels or shadows. Generate the corrected PNG now.

`Pixel Art Arm Sprite Sheet (1).png` is retained unchanged as
`arm-turn-source.png`. This follow-up still left mirrored sleeve glints.
After common-scale reduction, the builder relocates those clusters to the
left: **14 changed color pixels across four poses**, no alpha changes or mitten
edits. Every before/after pixel is recorded under `arm_geometry.highlight_edits`
in the pack provenance. The image generator is not credited with that correction.
