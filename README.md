# Codex Buddie

A little character **in place of Codex's computer-use cursor**.

The intended character uses the agent's cursor window and keeps its click
coordinate; your own mouse stays independent.

**Experimental macOS prototype.** The renderer works in the included lab. A
modified copy of the native service boots with the renderer library loaded.
**Live integration is currently blocked by native IPC startup.** The ad-hoc
experiment reported `SkyIPCRequirement.Error.teamNotFound`; a matching-team
Apple development signing experiment also failed to connect. This is a renderer prototype and
research experiment, not a working Codex cursor skin or an official plugin.

The intended experience is a buddy that **walks along the agent's curved cursor
path**, stops at the exact hotspot, and animates the click, with no gray arrow or
glow showing. See the [next implementation brief](docs/next-steps.md).

The **Character Studio** initially opens with **Bit · Pixel bot**, an original compact
retro robot inspired by the user's Codex pet reference. Generated artwork is
registered on a small pixel canvas with a restrained palette and crisp sampling.
Independent feet, opposing paws, screen expressions and five coordinated head
and torso directions animate in the actual Cocoa renderer. An interrupted turn
retraces its current sequence. Body/head proportions, shell, screen-light and
antenna colors can be edited and saved as a portable pack.

![Bit in the actual Studio renderer](docs/media/bit-studio-customization.png)

[Walking review](docs/media/bit-studio-walk.gif) ·
[Fast-travel review](docs/media/bit-studio-fast-travel.gif) ·
[Facial reactions](docs/media/bit-face-reactions.gif) ·
[Pack format](docs/characters.md) ·
[Verification evidence](docs/evidence/bit-faces.json).

**Miso · Cat bot** joins the collection with cream/coral generated artwork,
separate limbs and a gently moving curled tail, five head/torso directions,
click/travel expressions, and independently editable shell, suit and lights.
See [Miso's customization](docs/media/miso-customization.png),
[walking](docs/media/miso-walk.gif) and [source/review](artwork/miso/README.md).

**Still a motion study.** Bit's visual direction was approved and his neck
shortened; Miso is a new candidate. Broader anatomy controls, knee articulation,
production cursor sizing and the native service
connection remain unfinished. These exports do not show a live Codex task.

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
Changing stops during a walk preserves position and velocity. Bit offers size,
body width/height, head size, stride, step height, **Shell**, **Screen lights**
and **Antenna** controls. Miso has the same shape controls and separate cream
shell, coral suit and screen-light colors. Click a color well or enter an exact
`#RRGGBB` value. Pip has equivalent
proportion controls and separate raincoat/boot colors.
Colors, proportions and gait are saved for each buddy automatically. Switching
away and back restores your edits; reopening the Studio restores the selected
buddy and Reduced Motion preference. **Reset character** restores the original
design. **Save a copy…** exports a portable buddy folder and adds it to the
collection; **Import buddy…** installs a local copy of its artwork.
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

## Prepare an isolated native experiment

**Research only: the current ad-hoc signed copy cannot accept native action
connections.** The service starts and the library loads, but the read-only
`cua.getApp(...)` health check fails with `Sky Computer Use native pipe startup
failed`; service logs report `SkyIPCRequirement.Error.teamNotFound`.
Normal app permission grants alone have not been shown to resolve this.
The [development-signing follow-up](docs/development-signing.md) records the
matching-team attempt and its failed native inventory probe.

**Apple Silicon only.** Gated to the inspected service builds `26.913.1001067`
and `26.924.1001281`, with exact executable SHA-256 entries in
[`compatibility/macos-arm64.json`](compatibility/macos-arm64.json). That entry
means inspected, not live-certified. Other binaries are rejected.

You must already have the official native CUA runtime locally. This repository
does not download or redistribute OpenAI's application or libraries.

```sh
./scripts/build.sh
python3 scripts/prepare.py prepare --service '/path/to/Codex Computer Use.app'
python3 scripts/prepare.py launcher --runtime '/path/to/cua_node'
```

`--runtime` is the directory containing `bin/node`, `bin/node_repl`, and
`lib/node_modules/@oai/cua-repl`. The `prepare` command:

1. Verifies the original executable hash and app signature.
2. Copies the app into `.build/native/Codex Buddie Runtime.app`.
3. Adds a dylib dependency in verified unused Mach-O header padding.
4. Gives the copy its own bundle identifier and an ad-hoc local signature.
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
  -c 'mcp_servers.native_cua_repl.command="/absolute/path/Codex-Buddie/.build/codex-buddie-cua"' \
  -c 'mcp_servers.native_cua_repl.args=[]'
```

Ask that session to use `native_cua_repl`, beginning with `await cua.getState();`.
Then try a harmless action in the Renderer Lab. The copied app has a different
identity, so existing macOS permissions do not transfer. Native client authentication currently rejects the
ad-hoc signed copy; this command is provided to reproduce that blocker. **Do not disable SIP, Gatekeeper, TCC, or other security checks.** A rejection
is a compatibility blocker to investigate, not a reason to weaken the machine.

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
| Native app observation through the modified service | **Blocked: native IPC startup** |
| Character replaces cursor during real native CUA actions | **Not reached** |
| Native hotspot accuracy, drag, multiple monitors, cancellation | **Not verified** |

Run checks with:

```sh
python3 -m unittest discover -s tests -v
bash scripts/test-animation.sh
./scripts/build.sh
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --self-test
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

Resolve the native IPC compatibility issue through a supported development or
customization mechanism. This repository does not patch authentication checks.
Then verify real native CUA actions, actual cursor view assignment, hotspot
placement, dragging, multiple displays, and teardown. Only after those checks
should this become an installer for non-developers. Windows and Linux are not implemented.

## References

- [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-reference)
- [Apple: NSWindow contentView](https://developer.apple.com/documentation/appkit/nswindow/contentview)

MIT-licensed project code. OpenAI's runtime retains its own terms and is not
included. This project is independent of OpenAI.
