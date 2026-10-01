# Eight-pose walk refinement

Generated from the four-pose walk study in the same ChatGPT conversation. The
eight poses add lowered/contact and swing positions between the earlier keys.
Identity and wardrobe remain grounded in Pip. Exact image model ID is not exposed
by the ChatGPT UI; provenance records the request, source file and digest.

Detection and manually reviewed row origins are recorded in `frames/geometry.json`
and `registration.json`. One scale applies to all frames, preserving the source's
body lowering and foot lift. The current bundled pack uses these eight walk poses
plus six [matching side-facing idle poses](../idle-side/).

See [rendered motion](../../../docs/media/pip-refined-motion.gif),
[rendered contacts](../../../docs/media/pip-refined-contact.png) and
[the current review](review.json). Runtime tests verify stopped facing and
Reduced Motion, but do not prove correct leg anatomy. Foot ownership/contact,
turns, settling and mirrored lighting remain quality gaps. This is still a study.
