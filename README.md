# Codex Buddie

A little character **in place of Codex's computer-use cursor**.

The antenna tip is the click point. The character uses the agent's cursor
window; your own mouse stays independent.

**Experimental macOS prototype.** The renderer works in the included lab. A
modified copy of the native service boots with the renderer library loaded.
**Live integration is currently blocked by native IPC signing validation**
(`SkyIPCRequirement.Error.teamNotFound`). This is a renderer prototype and
research experiment, not a working Codex cursor skin or an official plugin.

## Try it

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/Suture-AI/Codex-Buddie.git
cd Codex-Buddie
./scripts/run.sh
```

The Renderer Lab opens with a small green buddy. Click **Look**, **Move**, or
**Click** to move its hotspot to that target. **Play / pause movement** animates
the cursor between targets. **Switch cursor style** tests both native layouts.
The lab simulates the native window; it does not perform computer-use actions.
Close the window to quit. Nothing is installed globally.

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

**Apple Silicon only.** Currently gated to service version `26.913.1001067`,
build `1001067`, with an exact executable SHA-256 in
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
| Native app observation through the modified service | **Blocked: IPC signing validation** |
| Character replaces cursor during real native CUA actions | **Not reached** |
| Native hotspot accuracy, drag, multiple monitors, cancellation | **Not verified** |

Run checks with:

```sh
python3 -m unittest discover -s tests -v
./scripts/build.sh
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --self-test
```

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
