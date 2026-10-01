# Codex Buddie

A little character **in place of Codex's computer-use cursor**.

The intended character uses the agent's cursor window and keeps its click
coordinate; your own mouse stays independent.

**Experimental macOS prototype.** Bit now replaces the native fog cursor during
real official CUA actions in an isolated, development-signed service copy.
The small bot on “Over here” in [this live screenshot](docs/media/native-cursor-live.jpg)
is the replacement; the larger bot is the Studio preview.
A SwiftUI sizing fix makes the replacement visible. Observation, target clicks
and a slider drag worked in the authorized Lab test session. Smooth native travel,
click reactions and an installer remain unfinished. This is an independent
research experiment, not an official plugin. See [the native review](docs/native-layout.md).

The intended experience is a buddy that **walks along the agent's curved cursor
path**, stops at the exact hotspot, and animates the click, with no gray arrow or
glow showing. See the [next implementation brief](docs/next-steps.md).

The **Character Studio** initially opens with **Bit · Pixel bot**, an original compact
retro robot inspired by the user's Codex pet reference. Generated artwork is
registered on a small pixel canvas with a restrained palette and crisp sampling.
Independent feet, opposing paws, screen expressions and five coordinated head
and torso directions animate in the actual Cocoa renderer. An interrupted turn
retraces its current sequence. Body/head proportions, shell, screen-light and
antenna colors can be edited and saved as a portable pack. Arm length, leg
length, boot width and stance are also adjustable. Pixel knees fold during
lift while soles remain planted through contact.

![Bit in the actual Studio renderer](docs/media/bit-studio-customization.png)

[Walking review](docs/media/bit-studio-walk.gif) ·
[Fast-travel review](docs/media/bit-studio-fast-travel.gif) ·
[Facial reactions](docs/media/bit-face-reactions.gif) ·
[Pack format](docs/characters.md) ·
[Verification evidence](docs/evidence/bit-faces.json).

**Miso · Cat bot** joins the collection with cream/coral generated artwork,
separate limbs and a gently moving curled tail, five coordinated head/torso/tail directions,
click/travel expressions, and independently editable shell, suit and lights.
See [Miso's customization](docs/media/miso-customization.png),
[walking](docs/media/miso-walk.gif), [tail turns](docs/media/miso-tail-turn.gif)
and [source/review](artwork/miso/README.md).

Bit and Miso now use ten authored arm perspectives each. Shoulders stay fixed
while hands swing; arm length and torso proportions remain editable. See
[the turns](docs/media/arms-turn-sequence.png), [Bit walking](docs/media/bit-arm-gait.gif),
[Miso walking](docs/media/miso-arm-gait.gif) and [the checks](docs/evidence/directional-arms.json).

**Still a motion study.** Bit's visual direction was approved and his neck
shortened; Miso is a new candidate. Head/antenna perspective, non-pixel knee articulation,
production cursor sizing and real native cursor
interaction remain unfinished. These exports do not show a live Codex task.

Pip remains available as an articulated customization study and an earlier
complete-pose pack. Sprout/Mochi/Orbit remain rejected art-direction fixtures.
See the [current brief](docs/art-direction.md) and [Bit's source/provenance](artwork/bit/README.md).

## Additional runtime research

An independently tested [passive macOS overlay](experiments/passive-overlay/README.md)
is included under `experiments/passive-overlay/`. It has three presets, custom
sprite support, and 36 core checks. Its live trace proves that the native cursor's
window bounds can be observed, but it does **not** replace the original artwork.
The renderer experiment at the repository root remains the direct-replacement
track.

Read the [implementation findings](experiments/passive-overlay/docs/research.md)
and [validation evidence](experiments/passive-overlay/docs/validation.md). The
passive investigation inspected newer service builds than the native patch's
compatibility entry; those observations do not certify the patch for newer builds.

## Try it

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone --branch feature/animated-character-rig https://github.com/Suture-AI/Codex-Buddie.git
cd Codex-Buddie
./scripts/run.sh
```

Choose a character, then use **Take a walk**, the three stops, and **Try a click**.
Changing stops during a walk preserves position and velocity. **Body** holds
size, body width/height and head size; **Limbs** holds arm/leg length, boot width
and stance; **Gait** holds stride and step height. Numeric readouts show the
current values. Bit also offers **Shell**, **Screen lights** and **Antenna**
colors. Miso has the same shape controls and separate cream
shell, coral suit and screen-light colors. Click a color well or enter an exact
`#RRGGBB` value. Pip has equivalent
proportion controls and separate raincoat/boot colors.
See the [limb comparison](docs/media/anatomy-collection.png),
[Bit in motion](docs/media/bit-anatomy.gif) and
[verification scope](docs/evidence/limb-customization.json).
Colors, proportions and gait are saved for each buddy automatically. Switching
away and back restores your edits; reopening the Studio restores the selected
buddy and Reduced Motion preference. **Reset character** restores the original
design. **Save a copy…** exports a portable buddy folder and adds it to the
collection; **Import buddy…** installs a local copy of its artwork.
The isolated native renderer now reads the same saved selection, colors,
anatomy and Reduced Motion preference. It updates after Studio saves without
restarting the service. Imported packs work through the same library; malformed
saves keep the last good appearance. This bridge has automated renderer checks
and an isolated service startup check. A later native test displayed Bit and
exercised a saved size edit; see [the live review](docs/native-layout.md).
See [saved cursor settings](docs/cursor-library.md).

**Native size** compares the small software-cursor layout with the enlarged
studio view. **Reduced motion** removes autonomous animation and jumps directly
to targets. The system accessibility preference is also respected.

The studio simulates the native window; it does not perform computer-use actions.
Close the window to quit. The local library lives in
`~/Library/Application Support/Codex Buddie/Studio/`; imported artwork is copied
there, so moving the original download does not break it. See the
[character pack format and artwork workflow](docs/characters.md).

## How the experiment works

The inspected native service has a dedicated
`ComputerUse.ComputerUseCursor.Window`. A small Objective-C library intercepts
its content-view assignment and substitutes our character view for either
`SoftwareCursorStyle`'s image view or `FogCursorStyle`'s hosting view.

- The existing window and movement engine remain responsible for placement.
- The software cursor keeps its `(4, 4)` hotspot; the fog cursor keeps its centre.
- The old artwork is detached and retained for native geometry queries.
- Other windows and unrecognised cursor renderers are left alone.
- There is no system-mouse polling, click injection, transcript reading, or
  replacement computer-use driver in Buddie.

The native service is closed-source and has no custom-cursor API in the public
interfaces inspected. This experiment depends on private implementation details.

## Use Buddie from your regular terminals

Once you have a tested, development-signed service copy, enable it for existing
Codex CLI and Orca `cua` registrations:

```sh
python3 scripts/terminal-buddie.py enable \
  --service '/absolute/path/to/Codex Buddie Runtime.app'
```

Restart the Codex session in your other terminal, or open a new one. Ask it to
use **native CUA** for a normal computer task, such as opening Finder and clicking
Downloads. Approve that app's usual access prompt if requested. The Lab does
not need to be open. Its saved character selection still controls the cursor.

This updates the main Codex profile and existing Orca account/shared profiles.
It preserves official browser providers, tool settings and per-app permissions.
Existing sessions keep their old connection until restarted. Browser actions
that use DOM automation may draw a separate in-page cursor. The native renderer
switch does not skin that cursor; see the browser companion below.
The service path must remain available; moving or deleting that prepared copy
breaks the registration until restored.

To check or undo the switch:

```sh
python3 scripts/terminal-buddie.py status
python3 scripts/terminal-buddie.py disable
```

Restart affected sessions after disabling too. The script saves the original
CUA registration and preserves unrelated later settings. It refuses to overwrite
a CUA stanza that has been edited since activation. The live renderer's
[motion and compatibility limits](docs/native-layout.md) still apply.

## Browser tab cursor companion

The ChatGPT browser extension can draw its own animated cursor inside an ordinary
web tab. That is a separate renderer from the native macOS cursor. The earlier
blanket statement that browser DOM actions never show a cursor was incorrect.

A [companion extension prototype](browser-extension/README.md) now replaces that
in-page arrow's artwork with Bit while following the existing position and
visibility. It has 305 poses from the native renderer and passes 12 local browser
fixture checks. Installation beside the actual ChatGPT extension and real browser
actions are still pending; this is not yet a live browser-integration claim.
The current prototype uses default Bit without syncing Studio settings.

## Prepare an isolated native experiment

**Research only.** An existing Apple development identity was sufficient to sign
our isolated service copy for a successful inventory probe with the unmodified
official client. Re-signing the client failed authentication. Ad-hoc signing also
failed. See [the working reproduction](docs/development-signing.md).
Native fog rendering and Lab app access passed the scoped test described in
[the native review](docs/native-layout.md); other environments remain unverified.

**Apple Silicon only.** Gated to the inspected service builds `26.913.1001067`
and `26.924.1001281`, with exact executable SHA-256 entries in
[`compatibility/macos-arm64.json`](compatibility/macos-arm64.json). That entry
means inspected, not live-certified. Other binaries are rejected.

You must already have the official native CUA runtime locally. This repository
does not download or redistribute OpenAI's application or libraries.

```sh
./scripts/build.sh
python3 scripts/prepare.py prepare --service '/path/to/Codex Computer Use.app' \
  --signing-identity "$BUDDIE_SIGNING_IDENTITY"
python3 scripts/prepare.py launcher --runtime '/path/to/cua_node'
```

`--runtime` is the directory containing `bin/node`, `bin/node_repl`, and
`lib/node_modules/@oai/cua-repl`. Leave that official runtime unmodified.
`BUDDIE_SIGNING_IDENTITY` names an existing local development identity; omitting
it selects ad-hoc signing, which failed the native probe. The `prepare` command:

1. Verifies the original executable hash and app signature.
2. Copies the app into `.build/native/Codex Buddie Runtime.app`.
3. Adds a dylib dependency in verified unused Mach-O header padding.
4. Gives the copy its own bundle identifier and the selected local signature.
5. Verifies the new signature and that the original binary did not change.

The launcher starts the copy on a fresh private Unix socket and runs the
**official CUA REPL** against it. Each launch gets its own socket; it does not
connect to the normal service's socket. The launcher stops its child service
when the REPL exits. No Codex settings are edited.

To try it in a **fresh Codex CLI session**, override your existing native MCP
server for that invocation only. Replace the path with the absolute path printed
by `launcher`:

```sh
codex \
  -c 'mcp_servers.cua.command="/absolute/path/Codex-Buddie/.build/codex-buddie-cua"' \
  -c 'mcp_servers.cua.args=[]'
```

Ask that session to use `cua`, beginning with `await cua.getState();`.
Then try a harmless action in the Renderer Lab through the normal app-access
prompt. The copied app has a different identity, so existing macOS permissions
do not transfer. The successful inventory probe does not establish permission
for app observation or input. Preserve all normal security checks.

Quit that Codex session to stop the experiment. Starting Codex normally uses
your original configuration. The original application and runtime are untouched;
all generated copies are under `.build/`.

## Verification so far

| Check | Result |
| --- | --- |
| Build renderer library and lab | Passed locally |
| Replace both known view styles in the harness | Passed |
| Retain dimensions, remove old artwork, repeated replacement | Passed |
| Leave unrelated windows and unknown renderers untouched | Passed |
| Move character to target in lab through native CUA | Visually checked |
| Mach-O corruption, architecture, padding, duplicate-patch tests | Passed |
| Stage and verify signed copy; original stays unchanged | Passed |
| Load library inside copied native service; private socket starts | Passed |
| Initialise official REPL through generated launcher | Passed |
| Native app inventory through the modified service | **Passed: 33 apps, original official client** |
| Prepare saved Studio appearance in the modified service | Passed; Bit displayed during real native input |
| Saved settings/imports reach registered cursor views | Passed in automated Cocoa checks |
| Observe Studio through the current Bit service | Passed with explicit session-only app authorization |
| Character replaces cursor during real native CUA actions | **Passed for the fog style in the Lab** |
| Lazy SwiftUI cursor layout | Passed: real zero-frame hosting view resolves to 126 × 126 |
| Native slider drag | Reached slider; changed size and restored it to 64 |
| Smooth native path, click reactions, exact hotspot accuracy, multiple monitors, cancellation | **Not verified** |

Run checks with:

```sh
python3 -m unittest discover -s tests -v
bash scripts/test-animation.sh
bash scripts/test-cursor-library.sh
./scripts/build.sh
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --self-test
bash scripts/test-native-layout.sh
```

Animation checks cover frame-rate-independent gait, planted contact, the fixed
click anchor, reduced motion, teleport recovery, curved arrival and interruption
continuity. Pack checks cover the three real PNGs, export/import, independent
customization, full sprite packs, timed blink boundaries, shared frame dimensions,
invalid settings, missing files and paths that escape a pack. The native harness
also compares rendered blink and Reduced Motion frames and verifies the fixed
sprite hotspot.
See [the animation validation notes](docs/animation-validation.md).

## Next milestone

Resolve continuous native travel and click-event animation, then verify exact
hotspot placement, both cursor styles, multiple displays, cancellation and teardown. Only after those checks
should this become an installer for non-developers. Windows and Linux are not implemented.

## References

- [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-reference)
- [Apple: NSWindow contentView](https://developer.apple.com/documentation/appkit/nswindow/contentview)

MIT-licensed project code. OpenAI's runtime retains its own terms and is not
included. This project is independent of OpenAI.
