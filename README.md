# PsrShot 📸

Lightweight, native macOS Screenshot & Annotation app (Lightshot clone) built with Swift, AppKit, ScreenCaptureKit, CoreGraphics, and Carbon.

---

## Features

- **Global Hotkey:** Trigger instant screenshot capture with `Cmd + Shift + X` (customizable in Preferences) via Carbon API without needing Accessibility permissions.
- **Interactive Fullscreen Overlay (`NSPanel`):** Floats above all windows (`.screenSaver` level) with a frozen snapshot of the screen and a dimmed mask over the unselected area.
- **8-Point Resize Handles & Move:** Precision resizing from 4 corners and 4 edges, dimension badge (`1920 × 1080 px`), and dragging to move the selection box.
- **Rich Annotation Tools:**
  - 🔲 **Rectangle:** Outline or filled box
  - ↗️ **Arrow:** Directing arrows with mathematically calculated arrowhead vertices
  - ✏️ **Pen:** Smooth freehand drawing
  - 🔤 **Text:** Inline text editing with background plate for maximum readability
  - 👁️ **Blur / Pixelate:** Fast mosaic pixelation shader (`CIPixellate`) to obscure sensitive info (passwords, emails, keys)
  - 🎨 **Palette & Stroke Sizes:** Red, Blue, Green, Yellow, White with adjustable thickness
  - ↩️ **Undo:** `Cmd + Z` history stack
- **Floating HUD Toolbar:** Anchored dynamically to the selection box, with quick actions:
  - 📋 **Copy (`Cmd + C`):** Crops retina image directly to the clipboard
  - 💾 **Save (`Cmd + S`):** Exports to disk via `NSSavePanel`
  - ☁️ **Upload to S3 (`Cmd + U`):** Uploads to any S3-compatible cloud storage, copies public link to clipboard, and sends a native macOS notification
  - ❌ **Dismiss (`ESC`):** Closes overlay instantly and frees memory
- **Format & Compression Options:**
  - Supports **PNG** (lossless), **JPEG**, **WebP**, and **HEIC**
  - Configurable lossy compression slider (10% to 100%) powered by hardware-accelerated `ImageIO`
- **S3-Compatible Cloud Storage:**
  - Works with **AWS S3, Cloudflare R2, MinIO, Wasabi, DigitalOcean Spaces, Backblaze B2**
  - Zero external SDKs: Pure Swift AWS SigV4 implementation with Apple's native `CryptoKit`
  - Optional auto-upload after screen capture
- **Zero-Dependency & Ultra-Lightweight:** Pure native macOS code, binary < 4 MB, memory footprint < 30 MB idle.

---

## Build & Run

### Prerequisites
- macOS 13.0+
- Xcode 15+ / Command Line Tools (Swift 5.9+)

### Build Standalone App
```bash
make app
# or
./scripts/build_app.sh
```
This generates `PsrShot.app` in the repository root.

### Launch App
```bash
open PsrShot.app
# or
make run
```

### Run Unit Tests
```bash
make test
# or
swift test
```

---

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd + Shift + X` | Global Hotkey to capture screen (customizable) |
| `Cmd + C` | Copy cropped retina screenshot to clipboard |
| `Cmd + S` | Save screenshot to disk (PNG, JPG, WebP, HEIC) |
| `Cmd + U` | Upload screenshot to S3 cloud storage & copy view link |
| `Cmd + Z` | Undo last drawn annotation |
| `ESC` | Dismiss overlay / cancel |

---

## License
MIT
