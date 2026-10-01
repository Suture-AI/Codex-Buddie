# Character animation validation — 2026-09-30

Tested on Apple Silicon macOS with the local Xcode toolchain.

- Pure C motion checks passed: identical gait phase over equal paths at 30, 60
  and 120 Hz; world-planted contact; click anchor unchanged; reduced motion;
  teleport reset; exact curved arrival; continuous velocity when retargeting.
- Character checks passed for all three generated PNG packs, independent preset
  copies, export/import of tuned geometry and artwork, refusal to overwrite an
  existing pack, procedural fallback, schema/ranges, missing files, remote paths,
  traversal, symlink escape and invalid colors.
- Native renderer harness passed: software/fog replacement, retained dimensions,
  detached original artwork, repeated assignments, unrelated windows untouched,
  and fallback for unknown renderers.
- Seven existing Mach-O tests passed. No native service was patched or launched
  as part of this animation update.
- The generated PNGs have transparent and opaque pixels. Barely visible alpha
  noise was removed, images cropped, and antialiased assets downsampled to 512 px.

![Idle, walking, turning and click poses](media/motion-contact.png)

The [motion recording](media/buddies-walking.gif) comes from 720 deterministic
frames rendered by the same `BuddieView` used in the studio, at 60 samples/sec,
encoded to 30 fps for viewing. It includes an interrupted trajectory and explicit
press/release per character. It demonstrates the controlled renderer, not native
Codex replacement, actual screen refresh performance, or a live CUA task.

Reproduce the recording after building:

```sh
".build/Codex Buddie Lab.app/Contents/MacOS/BuddieLab" --export-frames .build/motion-frames
ffmpeg -framerate 60 -i .build/motion-frames/frame-%04d.png \
  -vf 'fps=30,scale=630:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=sierra2_4a' \
  -loop 0 docs/media/buddies-walking.gif
```

Remaining product gates: supported live renderer integration, verified native
movement/press/drag/visibility signals, browser and picture-in-picture surfaces,
multi-display accuracy, lifecycle/performance profiling, durable collection
management, and signed distribution. The native IPC signing blocker still
applies. No claim of seamless replacement in stock Codex is made by this update.
