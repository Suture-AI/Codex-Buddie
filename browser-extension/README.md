# Browser companion prototype

This companion replaces the ChatGPT browser extension's **in-page agent cursor**
with Bit. That cursor is separate from the native macOS cursor window.

The installed extension inspected here draws its arrow inside the closed shadow
root of `#codex-agent-overlay-root`. Chrome's documented
[`chrome.dom.openOrClosedShadowRoot`](https://developer.chrome.com/docs/extensions/reference/api/dom)
lets an extension access that drawing surface. Buddie observes its existing
position and visibility, hides only the arrow image after its own art is ready,
and renders Bit at the same anchor. It leaves the official movement engine,
arrival acknowledgement and input dispatch in charge.

**Status:** 12 local browser-fixture checks and 30/60/120 Hz motion checks pass.
Installation beside the actual ChatGPT extension and real browser-action
verification are still pending. The native desktop replacement is independent.

## Load for a local test

In Brave or Chrome's extension manager, enable Developer mode, choose **Load
unpacked**, and select this `browser-extension` directory. Reload the test tab
after loading. Keep the official ChatGPT browser extension enabled. A fresh
browser action should then discover the existing agent cursor.

The browser will request access to HTTP/HTTPS pages because the drawing surface
can appear on any page the agent controls. This companion contains no background
worker, analytics, remote requests, debugger access or input injection. Its only
resource load is the bundled Bit sprite atlas. It observes the specific
cursor subtree and nearby trusted pointer presses for character reactions.
The manifest grants no history, cookies, tab management or native messaging APIs.

Disable/remove the companion to restore the stock artwork. It checks for an
invalidated extension context once per second and restores the original
visibility; reloading the tab also clears it. Unknown cursor layouts and failed
asset loads keep the original visible. Lifecycle behavior still needs real
extension testing.

## Current limits

- Bit uses the bundled default design; live Studio settings are not synchronized.
- Chromium HTTP/HTTPS tabs only. Browser chrome, internal pages, PDF viewers,
  embedded ChatGPT browser surfaces and other providers are not covered.
- The adapter depends on inspected private DOM markers and a 24 × 24 cursor
  layout. Future upstream changes may require a compatibility update.
- Position/opacity follow the official cursor exactly. Bit remains upright;
  the arrow's spin, glow and stretch are not applied to the character.
- Walking uses native-rendered pose frames driven by observed travel. Reduced
  Motion removes autonomous gait/blinks; it does not change the official path.
- Click reactions use trusted pointer events near the displayed agent cursor;
  user clicks at that same location are indistinguishable.

## Preview and checks

```sh
node tests/test_browser_motion.cjs
python3 -m http.server 8765 --bind 127.0.0.1 --directory browser-extension
```

Open `http://127.0.0.1:8765/preview/` and choose **Run compatibility checks**.
This is an explicitly simulated closed-root fixture, not proof of the companion
running inside the installed ChatGPT extension. It checks anchor preservation
through rotation/stretch, arrow removal, input transparency, hide/show, teardown,
unknown artwork, failed image loading and overlay recreation.

The atlas contains 305 poses exported from this repository's approved Bit artwork
and native rig by `scripts/export-browser-bit.m`. It includes five perspectives,
walking, running, blink and press/release states; no vendor artwork is distributed.

After installing, `http://127.0.0.1:8765/preview/live.html` provides three harmless
click targets without any simulated cursor or buddy script. Use actual browser
CUA actions there to distinguish a real extension result from the fixture.
