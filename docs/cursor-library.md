# Saved Studio appearance in the native renderer

The isolated cursor renderer now follows Studio's saved buddy, palette, body and
limb proportions, gait, size and Reduced Motion preference. It reads the same
library and never writes to it. Changes apply after Studio's autosave; imported
artwork is loaded from the installed copy.

A new service copy must be prepared to include this code. Existing prepared
copies retain their previous dylib. The normal Studio does not subscribe to this
reader, so its direct controls and persistence remain the source of edits.

## Review

| Before | After | Why |
| --- | --- | --- |
| The native factory always used stock Bit | `BuddieCursorLibrary` attaches saved settings to cursor views and preloads at service startup | Customization now has a path into the intended renderer |
| Native code had no portable-pack selection path | `BuddieLibrary` validates the manifest and loads only the selected built-in or installed pack | A large collection does not require decoding every buddy |
| Studio settings and native settings would need separate validation | Both readers share bounded manifest parsing, pack path checks and settings ranges | Imported packs and edits keep the same interpretation |
| Reloading a character would reset its motion | `BuddieView.applySavedCharacter:preservingMotion:` swaps the prepared model while retaining gait, turn, blink and press state for the same artwork revision | Palette/proportion edits do not restart the character's movement |
| No live-save notification path | A directory watcher follows atomic saves, first-time folder creation and directory replacement | No file reads are added to the 60 Hz animation loop |
| Artwork changes could perform recoloring during a frame | The selected appearance is prepared on a serial worker before publication | The selected-pack loader records zero calls on the main thread |
| An earlier decode could finish after a newer edit | The worker rechecks the current selection before publishing | Rapid changes cannot publish the deliberately superseded test result |
| A missing or malformed save had no native recovery policy | Existing views retain the last good appearance; a later valid save recovers | A failed import does not blank a working cursor |
| No subscription lifecycle existed | Weak view references, cancellation, generation checks and closed watch descriptors | Retired views and stopped subscriptions can be released |

**Performance:** file observation is event-driven, with a 100 ms debounce after
filesystem notifications. Studio already debounces ordinary edits by 250 ms.
Only settings that affect the selected character trigger artwork loading;
Reduced Motion and unrelated buddy edits reuse the existing prepared appearance.
This establishes the selected-pack loader's thread placement, not a CPU/battery
benchmark or a claim about all AppKit startup work. The view's initial bundled
Bit fallback still uses its existing initializer.

**Interruptibility and timing:** automated checks preserve the current gait phase,
planted foot coordinates, body pose and facing progress through a live anatomy
and palette edit. The new subscription adds no transition or positional spring.
New characters and new imported artwork revisions use the existing reset path.

**Accessibility:** Studio's saved Reduced Motion state reaches all registered
cursor views, including views created after the initial load. The renderer also
continues to respect the system preference.

**Decision: approve this settings bridge within the checked scope; block final
live-integration signoff.** At this review, native cursor visibility, path transfer,
tiny-window legibility, input events and screenshot exclusion were unverified.
The later [native layout review](native-layout.md) establishes visibility in
the authorized Lab session and records the remaining motion gaps.

## Evidence and reproduction

Run `bash scripts/test-cursor-library.sh`. It builds the actual dylib, then uses
isolated temporary libraries and the real Bit/Miso artwork. The test exercises:

- First save into nonexistent nested folders, repeated atomic saves, and library-directory replacement.
- Saved palette/anatomy equality with Studio, motion continuity, and two simultaneous cursor views.
- Imported packs and reimports, unavailable selections, malformed manifests, and recovery.
- An unrelated missing import, Reduced Motion without decoding, and deliberately slow obsolete artwork loading.
- Stopping/restarting, releasing retired views, and subscription teardown.

The test never changes the user's collection. Existing pack/library/motion checks
and the full Cocoa renderer self-test also passed.

The actual isolated service probe at `2026-10-01T05:59:43Z` listed 33 apps through
the original official client and logged `Saved cursor appearance prepared.`
No app permission was granted and no native UI input was performed. All probe
processes were stopped afterward. See [the source-pinned result](evidence/cursor-library.json).

A later user-authorized session displayed Bit during real native clicks and
exposed a separate lazy-layout bug, now fixed. See [that scoped review](native-layout.md).
The evidence above remains the earlier startup/subscription result.
