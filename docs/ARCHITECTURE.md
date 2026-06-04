# Photography Workflow — Architecture
**Repo:** https://github.com/o4dvasq/photography
**Last updated:** March 30, 2026

---

## Overview

A native macOS app that manages the full photography post-processing pipeline for a Fuji X-T series shooter. Handles SD card import with RAW/JPEG splitting, Instagram-optimized resizing, and iCloud Photos handoff for iPhone transfer.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 PHOTO PIPELINE APP                      │
│              (Native macOS menubar app)                 │
│                                                         │
│  ┌──────────────┐                                       │
│  │  Import Tab  │                                       │
│  └──────────────┘                                       │
│         │                                               │
│  SD card auto-detect (NSWorkspace)                      │
│         │                                               │
│         ▼                                               │
│  Copy (never move) from SD card                         │
│         │                                               │
│         ▼                                               │
│  ~/Photography/Imports/YYYY-MM-DD/                      │
│      ├── RAW/      ← .RAF files                         │
│      └── JPEG/     ← in-camera JPEGs                    │
│         │                                               │
│         ▼                                               │
│  Photomator edits RAFs in place                         │
│         │                                               │
│         ▼                                               │
│  User exports finished JPEGs to:                        │
│  ~/Photography/Exports/Portfolio/                       │
│         │                                               │
│         ▼                                               │
│  ┌──────────────┐                                       │
│  │  Export Tab  │                                       │
│  └──────────────┘                                       │
│         │                                               │
│    ┌────┴────┐                                          │
│    ▼         ▼                                          │
│  Resize    Send to Photos (PhotoKit)                    │
│    │         │                                          │
│    ▼         │                                          │
│  ~/Photography/Exports/Instagram-Staged/                │
│    (1080px long edge, GPS stripped)                     │
│         │    │                                          │
│         └────┘                                          │
│              ▼                                          │
│       iCloud Photos Library                             │
│              │                                          │
│              ▼                                          │
│        iPhone (auto-sync)                               │
└─────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| Platform | macOS 13 (Ventura) minimum |
| UI Framework | SwiftUI |
| Image Processing | Core Image, vImage, CGImage |
| Photos Integration | PhotoKit (PHPhotoLibrary) |
| SD Card Detection | NSWorkspace volume mount notifications |
| State Persistence | JSON files in ~/Library/Application Support/PhotoPipeline/ |
| Dependencies | None (zero external dependencies) |

### Retired Infrastructure

The following components were part of the previous shell-based pipeline and are no longer used:

- **Cloudflare R2** — Bucket "oscar-photography" retired, public gallery pipeline removed
- **rclone** — No longer needed, dependency removed
- **exiftool** — No longer needed, dependency removed
- **GitHub Pages** — Gallery feature deferred
- **Python/generate_gallery.py** — Never built, pipeline retired

---

## Filesystem Layout

### Git Repository (Dropbox-synced, .git excluded)

```
~/Dropbox/projects/photography/     ← git repo root
├── CLAUDE.md                       ← project instructions
├── .gitignore
├── import.sh                       ← RETIRED (replaced by app)
├── upload.sh                       ← RETIRED (replaced by app)
├── lessons.txt                     ← RETIRED
├── projects.txt                    ← RETIRED
├── PhotoPipeline/                  ← Xcode project (created manually)
│   ├── PhotoPipeline.xcodeproj
│   └── PhotoPipeline/
│       ├── PhotoPipelineApp.swift
│       ├── ContentView.swift
│       ├── Views/
│       │   ├── ImportView.swift
│       │   ├── ExportView.swift
│       │   └── PreferencesView.swift
│       ├── Models/
│       │   ├── AppState.swift
│       │   ├── ImportSession.swift
│       │   └── ExportFile.swift
│       └── Services/
│           ├── SDCardDetector.swift
│           ├── CardScanner.swift
│           ├── FileImporter.swift
│           ├── ImageResizer.swift
│           ├── PhotosImporter.swift
│           └── StateManager.swift
└── docs/
    ├── ARCHITECTURE.md             ← this file
    ├── PROJECT_STATE.md
    ├── DECISIONS.md
    ├── CONTEXT_HANDOFF.md
    ├── PHOTOGRAPHY_CURRICULUM.md
    ├── Specs-history.md
    └── specs/
        ├── README.md
        └── implemented/
            └── SPEC_photo-pipeline-app.md

### Photography Storage (NOT in git, configurable in app preferences)

```
~/Photography/                      ← default base path
├── Imports/
│   ├── 2026-03-30/                 ← dated session folders
│   │   ├── RAW/                    ← .RAF files from camera
│   │   └── JPEG/                   ← in-camera JPEGs
│   └── 2026-03-30-b/               ← collision suffix if re-import same day
└── Exports/
    ├── Portfolio/                  ← Photomator export destination (full-res edited JPEGs)
    └── Instagram-Staged/           ← resized output (1080px long edge, GPS stripped)
```

### App State (NOT in git)

```
~/Library/Application Support/PhotoPipeline/
├── state.json                      ← preferences
├── import_history.json             ← log of all import sessions
└── photos_import_log.json          ← tracks files sent to Photos.app
```

---

## File Naming Convention

The app preserves original Fuji filenames (DSCF####.jpg, DSCF####.RAF) during import. No renaming occurs.

Exported files for Instagram receive a `_ig` suffix:
- Original: `DSCF0042.jpg`
- Instagram export: `DSCF0042_ig.jpg`

---

## Post-Shoot Workflow

```
1. Shoot with Fuji X-T50 (RAW+JPEG mode, Acros B&W film simulation)
2. Insert SD card → Photo Pipeline detects and notifies
3. Import tab: select card, confirm date, click Import
   → RAFs go to ~/Photography/Imports/YYYY-MM-DD/RAW/
   → JPEGs go to ~/Photography/Imports/YYYY-MM-DD/JPEG/
4. Open Photomator → edit RAFs from Imports/.../RAW/
5. Export finished JPEGs to ~/Photography/Exports/Portfolio/
6. Export tab: click "Export to Instagram"
   → Resized JPEGs appear in ~/Photography/Exports/Instagram-Staged/
7. Export tab: click "Send to Photos"
   → Files import to Photos.app, sync to iPhone via iCloud
8. Open Instagram on iPhone → images available in Photos picker
```

---

## App Architecture Details

### Import Flow (ImportView + Services)

1. **SDCardDetector** monitors NSWorkspace for volume mount notifications
2. On SD card detection: post macOS notification, badge menubar icon
3. **CardScanner** recursively scans `DCIM/` for `.RAF` and `.JPG`/`.JPEG` files (case-insensitive)
4. User selects session date (defaults to today), clicks Import
5. **FileImporter** creates `Imports/YYYY-MM-DD/{RAW,JPEG}` with collision suffix if needed
6. Files are **copied** (not moved) from SD card to destination folders
7. **ImportSession** recorded in import_history.json
8. User offered "Reveal RAW folder in Finder" to start Photomator edits

### Export Flow (ExportView + Services)

1. **ExportView** scans `Exports/Portfolio/` for new JPEGs
2. User clicks "Export to Instagram"
3. **ImageResizer** processes each file:
   - Read EXIF orientation tag, apply rotation correction
   - If long edge <= 1080px: copy as-is to Instagram-Staged
   - Otherwise: resize to 1080px long edge, preserve aspect ratio
   - Strip GPS metadata if enabled in preferences
   - Save as `filename_ig.jpg` with configurable JPEG quality
4. User clicks "Send to Photos"
5. **PhotosImporter** checks permission status:
   - Not determined: request permission with explanation
   - Denied: show banner with "Open Settings" button
   - Authorized: proceed with import
6. **PhotoKit** imports files from Instagram-Staged into Photos library
7. **StateManager** records imported file paths to prevent duplicates
8. iCloud Photos syncs to iPhone automatically

### State Persistence (StateManager)

All state stored as JSON in `~/Library/Application Support/PhotoPipeline/`:

- **state.json** — user preferences (paths, flags, export settings)
- **import_history.json** — array of ImportSession objects (date, counts, source volume)
- **photos_import_log.json** — set of file paths already sent to Photos.app

### Menubar Behavior (AppDelegate)

- Persistent menubar icon (camera glyph) even when main window closed
- Menu items: Open / Import from SD / Export pending / Quit
- Badge icon when SD card detected
- App can run in background with main window closed

---

## Permissions Required

| Permission | Framework | Prompt Timing | Denial Behavior |
|---|---|---|---|
| Photos (add-only) | PhotoKit | First use of "Send to Photos" | Banner shown on Export tab, "Export to Instagram" still works |
| Removable volumes | NSWorkspace | First SD card access | System handles prompt, no app-level fallback needed |

No network access required or requested. App is fully local.

---

## Build Status

| Component | Status |
|---|---|
| Swift source files | ✅ Complete |
| Xcode project creation | 🔲 Manual setup required |
| Compilation | 🔲 Not yet attempted |
| SD card detection | 🔲 Needs real-world testing |
| Import with collision handling | 🔲 Needs testing |
| Instagram resize + GPS strip | 🔲 Needs testing |
| PhotoKit import | 🔲 Needs testing |
| State persistence | 🔲 Needs testing |
| Menubar behavior | 🔲 Needs testing |

---

## Dependencies

**None.** The app has zero external dependencies. All functionality implemented using macOS frameworks:
- SwiftUI (UI)
- AppKit (menubar, file dialogs, workspace notifications)
- Core Image / vImage (image resize)
- ImageIO (EXIF reading, JPEG encoding, metadata stripping)
- PhotoKit (Photos library import)
- Foundation (JSON persistence, file management)
