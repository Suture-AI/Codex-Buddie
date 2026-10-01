# Miso — animated pixel cat bot

![Actual Cocoa customization](../../docs/media/miso-customization.png)

Miso is selectable in the Studio collection, with independent boots, hands,
calves and a curled tail; five coordinated head/torso directions; blinks and
click/travel expressions; three editable material colors; and torso/head
proportions. The source remains cream/coral, with Sage, Lilac and Midnight
examples demonstrating independent recoloring. These are review examples,
not named palette buttons in the app. User design approval is not claimed.

## Generated source art

Four images were generated sequentially in ChatGPT using Brave and official
CUA, as requested. The UI did not expose the image model identifier, so the
requested GPT Image 2.5 version is unverified.

- [Concept](concept-source.png): unmodified 1254×1254 RGBA download with real
  transparency. [Original prompt](prompt.md).
- [First head strip](turn-attempt-1.png): rejected because left-facing heads
  mirrored the bright shell highlight.
- [Corrected head strip](turn-source.png): five perspectives with the highlight
  on the image's upper left, including a distinct front view.
- [Torso strip](body-turn-source.png): five coral chest shells with a cream belly.

The exact [follow-up prompts](turn-prompts.md), [art provenance](provenance.json)
and [pack processing record](../../Characters/miso/provenance.json) are retained.
`concept-preview.png` is a reduced concept preview on cream.

## Processing and animation

[build-miso.py](../../scripts/build-miso.py) registers the heads to one shared
38-pixel scale and chin baseline, with no neck stalk. Torso parts use a common
13-pixel height. A reviewed 16-color palette keeps square pixel clusters
consistent. Arms, calves, boots and tail come from the original concept.
One neighboring pixel was removed from the tail cutout; its tip flexes one
pixel each way while the attachment stays fixed.

Expression variants are local pixel edits of the generated heads. Tests
verify that all 25 source variants preserve alpha and every non-eye pixel.
The 58-frame pack has separate masks for cream shell, coral suit and screen
lights. Save/import retains every recolored frame, attachment and proportion.

Review the actual Cocoa [walk](../../docs/media/miso-walk.gif),
[gait and landing](../../docs/media/miso-gait.gif),
[turn](../../docs/media/miso-turn.gif),
[faces](../../docs/media/miso-faces.gif) and
[evidence](../../docs/evidence/miso-studio.json).

This is still a character study. The tail keeps its screen-side attachment
through turns; broader anatomy and joint controls remain unfinished. Live
Codex cursor replacement and collection persistence across launches are
separate unfinished requirements.

## Reproduce

```sh
uv run --with pillow python scripts/build-miso.py
bash scripts/test-animation.sh
bash scripts/build.sh
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --self-test
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-puppet .build/miso-puppet-review miso
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-turn .build/miso-turn-review miso
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-gait .build/miso-gait-review miso
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-faces .build/miso-face-review miso
uv run --with pillow python scripts/review-miso.py .build/miso-puppet-review .build/miso-turn-review .build/miso-gait-review .build/miso-face-review
```

Raw PNG frame directories are regenerable intermediates. The published GIFs,
contact sheets and evidence JSON are the retained review outputs.
