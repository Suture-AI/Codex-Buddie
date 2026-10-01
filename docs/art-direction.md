# Character direction — current user brief

The first Sprout/Mochi/Orbit set did not meet the user's quality bar. The user
chose a graphic designer-toy direction, then clarified the reference as
**ChatGPT Pets: still soft, simple and cute, with substantially better design
than the pear-like first character**. Complex sci-fi machinery is not the target.

**Latest correction:** Pip is cool, but the user wants a **smaller retro 8-bit
bot**, and substantially better animation. They supplied an image of a compact
blue Codex pet with a dark screen face, simple cyan eyes, chunky pixel contours,
a tiny torso and short feet. Use this as a style/motion reference for original
art. The current candidate is Bit: a compact blue screen-faced robot with an offset
antenna. Keep the silhouette soft through stepped pixel shapes, a limited
palette and readable expressions. Prioritize proper steps, blinks and turns.
Pip remains a renderer/customization study, not the final visual target.

## Reference review

Reviewed the official [Pets documentation](https://learn.chatgpt.com/docs/pets)
and the built-in sprite sheets for stable pet IDs `dewey`, `hoots`, and `fireball`
through the Pets inspection tools. No pet was created, selected, changed or
deleted. OpenAI's artwork is a visual reference, not repository content.

Observed design strengths to carry into original characters:

- Recognizable identity and a clean silhouette at small size.
- Face, body, hands and feet share one drawing style and lighting treatment.
- Distinct profiles for travel, real alternating steps, and expressive complete
  poses. A static body with tiny procedural feet is insufficient.
- Compact proportions, readable eyes, restrained detail, and clear color groups.
- Personality comes from expression, posture and gesture as much as texture.

## Earlier concept: Pip

An original tiny otter explorer in a cobalt rain hood and tangerine boots, with
warm cream facial markings, small paws, a curved tail and compact proportions.
Soft 2.5D toon shading and crisp edges. The complete face and footwear are part
of the canonical design. Generate and inspect the whole character before making
animation assets. This is a candidate direction, not user-approved final art.

The rendering pipeline must preserve the canonical character's facial design
and complete limbs. Do not paste generic dot eyes or oval feet over new artwork.
Remove the dangling tether from the final design; calibrate a fixed local
hotspot for the actual renderer integration instead.

Pip is now exposed as an explicitly labeled **Motion study** in the review
studio, with matching side-facing blink and eight walk poses. This is for evaluating the
candidate direction, not approval into a finalized character collection. See
[the recording](media/pip-refined-motion.gif) and
[remaining quality gaps](../artwork/pip/walk-refinement/review.json).

## Review at useful sizes

Inspect at 48, 64, 96 and 192 pixels, on light and dark backgrounds. Check clean
alpha edges, coherent shapes, facial readability, complete feet, and a memorable
silhouette. Review idle, blink, walk, direction change and click motion before
adding a new character to the user-facing collection. A polished hero image is
necessary but does not establish animation quality.

## Bit implementation

Bit now opens as the Studio default. It uses original concept/turn artwork
generated one image at a time in ChatGPT through Brave. Two walking sheets
failed inspection (direction reversal, then repeated leading feet), so they
are retained as rejected evidence rather than used as a fake eight-step loop.
The renderer instead moves independently extracted limbs using the motion core.
Screen blinks only change reviewed eye pixels. Five authored head orientations
bridge right/front/left; the smaller body still mirrors and needs a full turn.

Review [actual customization](media/bit-studio-customization.png),
[walking](media/bit-studio-walk.gif), [fast travel](media/bit-studio-fast-travel.gif)
and [source/provenance](../artwork/bit/README.md). The user has not yet approved
Bit, and these are controlled Studio exports, not live CUA recordings.
