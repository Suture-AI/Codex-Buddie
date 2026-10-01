# Custom sprite packs

Create a folder with `pack.json` and `sprite.png`, then choose **Load sprite pack…** from the Buddie menu. Files remain where you put them. This prototype loads them into memory; it does not install or synchronize packs, and selections are not saved across launches.

Example layout: 8 columns × 2 rows of 128 × 128 pixel frames, yielding a 1024 × 256 PNG. Row 0 is idle and row 1 is movement. The first frame is at the top-left. Include transparent padding consistently, center the character in every frame, and keep its baseline fixed.

```json
{
  "version": 1,
  "name": "My Buddie",
  "image": "sprite.png",
  "frameWidth": 128,
  "frameHeight": 128,
  "columns": 8,
  "rows": 2,
  "fps": 10,
  "states": {
    "idle": { "row": 0, "frames": 6 },
    "moving": { "row": 1, "frames": 8 }
  }
}
```

Limits: PNG only, at most 20 MB, at most 4096 × 4096 decoded pixels; frames at most 512 × 512; 1–32 columns; 1–16 rows; 1–30 frames per second. Image dimensions must match the declared grid. The manifest is limited to 64 KB. Absolute paths, parent traversal and symlinks escaping the pack directory are rejected. A pack contains no scripts or network URLs.

Artwork is currently displayed in a 64 × 64 point square. Square frames are recommended to avoid stretching. Movement chooses the `moving` row; otherwise the app uses `idle`. Reduced Motion displays the first frame of the current row. The original vector presets additionally turn with horizontal movement; custom sprites retain their authored orientation.

The gray cursor's true hotspot has not been calibrated, so packs do not declare a functional click hotspot yet. Animation is purely visual; it never changes the agent's input coordinates.

To generate a character later, use the grid above as a strict output contract, then verify transparency, frame alignment, consistent anatomy and animation continuity before importing. Image generation is not built into this prototype.
