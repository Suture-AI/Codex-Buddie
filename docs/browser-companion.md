# Browser cursor investigation and companion prototype

The browser does have its own visible agent cursor. The earlier statement that
DOM browser actions never show one was too broad. The installed browser runtime
sends movement requests to the ChatGPT extension, which stores cursor state per
tab/session and draws an animated arrow inside the page. Native app control uses
a separate macOS window, which the existing Buddie renderer replaces.

This explains why a cursor can appear inside an ordinary tab. The inspected
implementation is independent of whether the tab was put into a group. This
investigation does not establish which model release changed tab organization.

## Inspected route

The installed `@oai/browser-desktop` service calls its UI adapter's `moveMouse`
before browser input dispatch. The ChatGPT extension publishes `AGENT_CURSOR_STATE`
to its content script, then waits for an arrival acknowledgement when requested.
The content script owns curved paths, springs, rotation, glow and visibility.

The cursor lives under `#codex-agent-overlay-root`, marked
`data-codex-agent-overlay-root="true"`, in a closed shadow root. The 24 × 24
`browser-agent-cursor` element carries the animated transform and opacity; a
23 × 24 image carries the gray artwork. The content script runs in top-level tabs.
These are inspected private markers, not an OpenAI customization API.

Chrome's documented
[`chrome.dom.openOrClosedShadowRoot`](https://developer.chrome.com/docs/extensions/reference/api/dom)
provides access to this drawing surface from an extension. No vendor file needs
to be modified. The companion uses that API and leaves the original cursor
controller and arrival messages running. It never calls private browser-input
APIs, sends actions or changes permission handling.

## Prototype review

| Before | After | Why |
| --- | --- | --- |
| The native renderer could not affect the browser's in-page arrow. | A separate content script discovers the known browser drawing surface. | Both control paths can retain their own input implementation. |
| Rotating the arrow asset would rotate the whole buddy. | Bit follows the translated anchor and opacity while remaining upright. | Turns and gait belong to the character; the target coordinate stays exact. |
| A second easing curve could lag behind the native cursor. | The adapter samples the existing transform without adding a positional spring. | Movement and arrival remain owned by the browser extension. |
| A failed replacement could hide the only cursor. | Artwork loads before hiding the arrow; unknown layouts, failure and teardown preserve or restore its visibility. | The stock renderer remains available. |

The 305-frame atlas comes from Bit's existing native renderer and approved
artwork. It includes five perspectives, walking/running, blinks and press/release
expressions. Pose changes follow observed distance/time. Reduced Motion suppresses
autonomous gait/blinks while retaining direct press feedback. Actual page input
is never intercepted; the canvas is pointer-transparent and accessibility-hidden.

**Verdict: pass the local compatibility prototype; block live integration
signoff pending installation and real browser actions.** Twelve fixture checks
passed in Brave through official CUA, including three fractional anchors under
rotation/stretch, hide/show, unknown artwork, image failure and restoration.
Motion checks passed at 30/60/120 Hz. The fixture explicitly uses a simulated
closed-root cursor and is not a test of cross-extension access or real arrival
timing. Native walking is represented by pose frames rather than the full
continuous rig; landing quality, frame costs and live click attribution need
review after installation.

![Local browser fixture, not live extension integration](media/browser-companion-preview.jpg)

The companion currently uses default Bit. It does not yet synchronize Studio
settings or cover browser chrome, internal pages, embedded browser surfaces,
PDF viewers or non-Chromium providers. See [installation and scope](../browser-extension/README.md)
and [the evidence record](evidence/browser-companion.json). Installation in the
user's Brave profile requires the computer-use tool's action-time confirmation;
that request has been presented and remains pending.
