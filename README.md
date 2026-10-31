# PsrShot 📸

[![Build and Release PsrShot](https://github.com/tonyzidc/PsrShot/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/tonyzidc/PsrShot/actions/workflows/build-and-release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**PsrShot** is an ultra-lightweight, zero-dependency, native macOS menu-bar screenshot and annotation tool. 
The entire compiled binary is under **400 KB**, memory footprint is **< 30 MB idle**, and it provides instant capture, smooth drawing tools, hardware-accelerated image compression, and direct S3 cloud storage upload.

---

## ✨ Features

- **Global Hotkey:** Trigger instant screenshot capture with `Cmd + Shift + X` (fully customizable in Preferences) via Carbon API without needing Accessibility permissions.
- **Interactive Fullscreen Overlay (`NSPanel`):** Floats above all windows (`.screenSaver` level) with a frozen snapshot of the screen and dimmed mask over the unselected area.
- **8-Point Resize Handles & Move:** Precision resizing from 4 corners and 4 edges, real-time dimension badge (`1920 × 1080 px`), and dragging to move the selection box.
- **Rich Annotation Suite:**
  - 🔲 **Rectangle:** Outlined or filled bounding boxes
  - ↗️ **Arrow:** Directing arrows with mathematically calculated arrowhead vertices
  - ✏️ **Freehand Pen:** Smooth Bezier curves with vertex downsampling for high-speed fluidity
  - 🔤 **Text:** Inline text editing with dark background plate for crisp contrast on any background
  - 👁️ **Blur / Pixelate:** Fast mosaic pixelation shader (`CIPixellate`) to obscure sensitive info (passwords, emails, keys)
  - 🎨 **Palette & Swatches:** Red, Blue, Green, Yellow, and White with high-contrast indicator rings
  - ↩️ **Undo:** `Cmd + Z` undo stack
- **Floating HUD Toolbar:** Anchored dynamically to the selection box:
  - 📋 **Copy (`Cmd + C`):** Crops retina image directly to the clipboard
  - 💾 **Save (`Cmd + S`):** Exports to disk via `NSSavePanel` (PNG, JPEG, WebP, HEIC)
  - ☁️ **Upload to S3 (`Cmd + U`):** Uploads to any S3-compatible cloud storage, copies public link to clipboard, and sends a native macOS notification
  - ❌ **Dismiss (`ESC`):** Closes overlay instantly and frees all memory
- **Format & Compression Options:**
  - Supports **PNG** (lossless), **JPEG**, **WebP**, and **HEIC**
  - Hardware-accelerated lossy compression slider (10% to 100%) powered by native `ImageIO`
- **S3-Compatible Cloud Storage:**
  - Works with **AWS S3, Cloudflare R2, MinIO, Wasabi, DigitalOcean Spaces, Backblaze B2**
  - Zero external SDKs: Pure Swift AWS SigV4 implementation with Apple's native `CryptoKit`
  - Built-in connection tester and auto-upload toggle
- **Zero-Dependency & Ultra-Lightweight:** Pure native Swift & AppKit, binary ~283 KB, memory footprint < 30 MB idle.

---

## 🚀 Download & Installation

### Option 1: Download from GitHub Releases
Download the latest `PsrShot.dmg` or `PsrShot-macOS.zip` directly from [GitHub Releases](https://github.com/tonyzidc/PsrShot/releases).
Drag `PsrShot.app` into your `/Applications` folder.

### Option 2: Build from Source
```bash
git clone https://github.com/tonyzidc/PsrShot.git
cd PsrShot
make app
open PsrShot.app
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd + Shift + X` | Global Hotkey to capture active screen (customizable) |
| `Cmd + C` | Copy cropped retina screenshot to clipboard |
| `Cmd + S` | Save screenshot to disk (PNG, JPG, WebP, HEIC) |
| `Cmd + U` | Upload screenshot to S3 cloud storage & copy view link |
| `Cmd + Z` | Undo last drawn annotation |
| `ESC` | Dismiss overlay / cancel |

---

## 🧪 Testing & Verification

Run automated test suite:
```bash
make test
# or
swift test
```

Run bundle integrity verification:
```bash
make verify
# or
./scripts/verify_app_bundle.sh
```

---

## 📄 License
MIT License. See [LICENSE](LICENSE) for details.
