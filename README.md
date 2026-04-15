# Spritkit

A native iOS toolkit for pixel artists and game developers — pixelate photos, scale sprites, extract palettes, slice sprite sheets, and preview animations.

## Features

### Pixelate
Transform any photo into pixel art using Core Image's `CIPixellate` filter with adjustable block size and real-time preview.

### Scale Sprite
Upscale or downscale sprites using nearest-neighbor interpolation to preserve crisp pixel edges — no blurry anti-aliasing.

### Extract Palette
Analyze any image and extract its color palette using a median-cut algorithm with automatic deduplication and frequency ranking.

### Sprite Sheet Cutter
Slice sprite sheets into individual frames via grid mode (rows × columns × padding) or automatic bounding-box detection. Save frames individually or in bulk to Photos.

### Animation Preview
Organize cut frames into named animation clips (walk cycle, attack, idle, etc.) with color-coded tags, adjustable FPS, and loop / ping-pong / one-shot playback modes.

## Tech Stack

| | |
|---|---|
| **Language** | Swift |
| **UI Framework** | SwiftUI |
| **Architecture** | MVVM (Model-View-ViewModel) |
| **Concurrency** | Swift Concurrency (async/await, Task, Sendable) |
| **Image Processing** | Core Image (CIFilter), Core Graphics (CGImage, CGContext) |
| **Platform** | iOS (iPhone & iPad) |

## Architecture

```
Spritkit/
├── Models/          Sprite, Palette, SpriteSheet, AnimationClip, ExportPayload
├── ViewModels/      One @ObservableObject VM per operation
├── Views/
│   ├── Pixelate/
│   ├── ScaleSprite/
│   ├── ExtractPalette/
│   ├── SpriteSheetCutter/
│   ├── AnimationPreview/
│   └── Shared/      ImagePicker, SpriteCanvas, ExportSheet
├── Services/        ImageProcessingService (stateless, off main thread)
└── Utilities/       CGImage extensions, Color+Hex
```

- **Views** contain zero processing logic — pure presentation
- **ViewModels** manage state via `ObservableObject` / `@Published` and call into services via `async/await`
- **ImageProcessingService** is a stateless enum with static methods, running all processing off the main thread via `Task.detached`
- **Models** are `Codable` and `Sendable` for safe concurrency and serialization

## Companion App

Spritkit is the operations companion to **Spritfill**, an iOS app for creating sprites and fill-by-number artwork. Both apps share compatible model formats:

- Hex-based color palettes (`[String]` arrays)
- Pixel grid format (`"clear"` / `"#RRGGBB"`)
- Standardized canvas sizes (8×8 through 128×128)

This enables seamless round-trip workflows between sprite creation and sprite processing.

## License

All rights reserved.
