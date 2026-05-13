# CLAUDE.md — Photography Workflow

## What This Is
A native macOS menubar app that manages the full photography post-processing pipeline for a Fuji X-T series shooter. Handles SD card import with RAW/JPEG splitting, Instagram-optimized resizing, and iCloud Photos handoff for iPhone transfer.

## Repo
https://github.com/o4dvasq/photography

## Key Files
```
~/Dropbox/projects/photography/     ← git repo root
├── CLAUDE.md                       ← you are here
├── PhotoPipeline/                  ← Xcode project (created manually)
│   ├── PhotoPipeline.xcodeproj
│   └── PhotoPipeline/
│       ├── PhotoPipelineApp.swift
│       ├── ContentView.swift
│       ├── Views/                  ← ImportView, ExportView, PreferencesView
│       ├── Models/                 ← AppState, ImportSession, ExportFile
│       └── Services/               ← SDCardDetector, FileImporter, ImageResizer, etc.
└── docs/
    ├── PROJECT_STATE.md            ← current project state (update every session)
    ├── DECISIONS.md                ← append-only decision log
    ├── ARCHITECTURE.md             ← system architecture
    ├── Specs-history.md            ← spec completion log
    └── specs/
        ├── SPEC_[feature-name].md  ← ready to implement
        └── implemented/            ← completed specs

~/Photography/                      ← photography storage (NOT in git, configurable)
├── Imports/
│   └── YYYY-MM-DD/
│       ├── RAW/                    ← .RAF files
│       └── JPEG/                   ← in-camera JPEGs
└── Exports/
    ├── Portfolio/                  ← Photomator export destination
    └── Instagram-Staged/           ← resized output (1080px long edge)
```

## Stack
| Layer | Tool |
|---|---|
| Platform | Native macOS app (SwiftUI) |
| Camera | Fuji X-T50, RAW+JPEG mode, Acros B&W |
| Local archive | ~/Photography/ (configurable base path) |
| Curation | Photomator (edits RAFs in place from Imports/.../RAW/) |
| SD card detection | NSWorkspace volume mount notifications |
| Image processing | Core Image, vImage, ImageIO |
| iPhone transfer | PhotoKit → iCloud Photos → iPhone auto-sync |
| Dependencies | None (zero external dependencies) |

## Workflow
1. Shoot with Fuji X-T50 (RAW+JPEG mode)
2. Insert SD card → Photo Pipeline detects and notifies
3. Import tab: select card, confirm date, click Import
   → RAFs go to ~/Photography/Imports/YYYY-MM-DD/RAW/
   → JPEGs go to ~/Photography/Imports/YYYY-MM-DD/JPEG/
4. Open Photomator → edit RAFs from Imports/.../RAW/
5. Export finished JPEGs to ~/Photography/Exports/Portfolio/
6. Export tab: click "Export to Instagram"
   → Resized JPEGs (1080px long edge, GPS stripped) appear in Instagram-Staged/
7. Export tab: click "Send to Photos"
   → Files import to Photos.app, sync to iPhone via iCloud
8. Open Instagram on iPhone → images available in Photos picker

## Active Constraints
- macOS 13 (Ventura) minimum — uses SwiftUI, PhotoKit
- Photography root is ~/Photography/ by default (configurable in Preferences)
- App is NOT sandboxed (personal use, distributed as standalone .app)
- No external dependencies — no Homebrew, no exiftool, no rclone, no Python
- Date-based session folders (YYYY-MM-DD) with collision suffixes (-b, -c, ...) if needed
- Instagram resize: 1080px long edge max, no upscaling if source already <= 1080px
- GPS metadata stripped from Instagram exports by default (configurable)
- PhotoKit requires Photos permission — app handles denial gracefully with clear UI

## Configuration Inventory

`docs/CONFIG_INVENTORY.md` — canonical list of hosting, build steps, and source files for this repo (minimal inventory; native macOS app, no backend, no secrets).

## Retired Components
- import.sh, upload.sh (replaced by native app)
- lessons.txt, projects.txt (curriculum structure replaced by date-based sessions)
- R2/GitHub Pages gallery pipeline (deferred, may be revisited)
- ~/Documents/Photography/ (replaced by ~/Photography/)
