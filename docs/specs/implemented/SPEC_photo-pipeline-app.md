SPEC: Photo Pipeline macOS App | Project: photography | Date: 2026-03-30 | Status: Ready for implementation

---

# 1. Objective

Build a native macOS menubar app that manages the full photography post-processing pipeline for a Fuji X-T series shooter using Photomator. The app replaces all existing shell scripts (import.sh, upload.sh) and the R2/GitHub Pages gallery pipeline with a clean UI covering three jobs: SD card import with RAW/JPEG splitting, Instagram-optimized resizing, and iCloud Photos handoff.

No Python. No launchd. No terminal. No external dependencies. Everything lives in the app.

---

# 2. Scope

## In scope

- SD card detection and import (RAW/JPEG split into dated session folders)
- Instagram-optimized JPEG resizing from Photomator exports
- iCloud Photos import via PhotoKit for iPhone transfer
- Persistent menubar icon with background SD card monitoring
- Preferences for all configurable paths and settings

## Out of scope (v1)

- Portfolio website upload / R2 sync / gallery generation
- Glass feed integration
- Batch file renaming or metadata editing
- RAW file preview or editing (Photomator handles this)
- iPhone companion app

## Retires

This app fully replaces the existing shell-based pipeline. The following are retired:

- `import.sh` (replaced by Import tab)
- `upload.sh` (no longer needed; R2 sync pipeline retired)
- `generate_gallery.py` (never built; gallery pipeline retired)
- `lessons.txt`, `projects.txt` (curriculum/project organization replaced by date-based sessions)
- R2 bucket workflow, GitHub Pages gallery, rclone dependency
- `~/Documents/Photography/` folder structure (inbox/, curriculum/, projects/)

The git repo at `~/Dropbox/projects/photography/` remains as the project home for this spec, build notes, and future gallery work if revisited.

---

# 3. Business Rules

- **Copy, never move from SD card.** The card remains the source of truth until the user manually formats it.
- **RAW files are first-class.** Photomator edits RAFs directly. Both RAW and JPEG are organized and preserved.
- **No upscaling.** If a source image is already <= 1080px on its long edge, copy it to Instagram-Staged as-is without scaling.
- **No cropping or padding.** Instagram handles native landscape and portrait aspect ratios. The app preserves aspect ratio exactly.
- **GPS metadata stripped** from all Instagram exports by default (configurable).
- **Re-import prevention.** Files already sent to Photos.app are tracked in an internal log and skipped on subsequent runs.

---

# 4. Data Model / Schema Changes

## Folder structure

The app owns and creates this structure. The base path (`~/Photography/`) is configurable in Preferences.

```
~/Photography/
  Imports/
    YYYY-MM-DD/              ← created per import session
      RAW/                   ← .RAF files (Fuji raw)
      JPEG/                  ← in-camera JPEGs (film simulation output)
    YYYY-MM-DD-b/            ← collision suffix if same-day re-import
  Exports/
    Portfolio/               ← full-res edited JPEGs (Photomator export destination)
    Instagram-Staged/        ← resized output, ready for Photos import
```

### Date folder collision handling

If `YYYY-MM-DD` already exists, append `-b`, `-c`, ... `-z`. If all 26 suffixes are exhausted (extremely unlikely), append `-27`, `-28`, etc.

### App state file

The app stores its internal state (import log, Photos import history) at:

```
~/Library/Application Support/PhotoPipeline/
  state.json               ← tracks which files have been sent to Photos
  import_history.json      ← log of all import sessions (date, counts, source volume)
```

---

# 5. UI / Interface

## Technology choices

- **SwiftUI** — native macOS app, minimum macOS 13 (Ventura)
- **PhotoKit** — for importing finished files into Photos.app / iCloud
- **Core Image / vImage** — for high-quality JPEG resizing
- No external dependencies or scripts

## App structure

Single-window app with a persistent menubar icon for background SD card monitoring. Main window has two tabs: **Import** and **Export**. Preferences accessible via standard Cmd-,.

## Menubar behavior

- Menubar icon: camera glyph (SF Symbols)
- Menu items: Open Photo Pipeline / Import from SD / Export pending / Quit
- When SD card is detected: badge on menubar icon + macOS notification
- App can run with the main window closed; menubar keeps it alive in the background

## Tab 1: Import

| Element | Description |
|---|---|
| Source volume | Auto-detected on card mount, or manually chosen via folder picker |
| Session date | Today's date, editable |
| Files found | Scan result: N RAF files, M JPEG files |
| Destination preview | Shows target folder paths before import begins |
| Import button | Disabled until source is confirmed and files are found |
| Progress bar | Per-file progress during copy |
| Log | Scrollable list of copied files with pass/fail status |

### Import logic

1. User plugs in SD card. App detects volume mount via `NSWorkspace.didMountNotificationName` and posts a macOS notification: "SD card detected. Open Photo Pipeline?"
2. App scans the card for `.RAF` and `.JPG`/`.JPEG` files (case-insensitive, recursive scan of DCIM directory).
3. Creates `Imports/YYYY-MM-DD/RAW/` and `Imports/YYYY-MM-DD/JPEG/`. Applies collision suffix if the date folder already exists.
4. **Copies** (does not move) `.RAF` files to `RAW/`, JPEG files to `JPEG/`. All other extensions are skipped silently.
5. On completion: shows summary (N RAF, M JPEG copied) and offers to reveal the RAW folder in Finder (since Photomator will edit RAFs there).

## Tab 2: Export

| Element | Description |
|---|---|
| Watch folder | `~/Photography/Exports/Portfolio/` (configurable) |
| Pending files | List of new JPEGs in Portfolio not yet processed |
| Export to Instagram | Button: resizes selected or all pending files |
| Send to Photos | Button: imports staged files into Photos.app via PhotoKit |
| Export + Send | One-tap action combining both steps |
| Output log | Per-file log showing input dimensions, output dimensions, or "skipped (already <= 1080px)" |

### Instagram resize logic

1. Read EXIF orientation tag and apply rotation correction before any processing.
2. Detect orientation: landscape (width > height), portrait (height > width), or square.
3. If long edge is already <= 1080px, copy the file as-is to Instagram-Staged (no resampling). Log as "skipped resize."
4. Otherwise, scale so the long edge = 1080px. Preserve aspect ratio exactly. No cropping. No padding or letterboxing.
5. Export as JPEG, quality 90, with filename suffix `_ig` (e.g., `DSC_0042_ig.jpg`).
6. Save to `Exports/Instagram-Staged/`. Never overwrite originals in Portfolio.
7. Strip GPS metadata from output files. Preserve orientation tag.

### iCloud Photos import logic

1. Use **PhotoKit** (`PHPhotoLibrary`) to import files from `Instagram-Staged/` into the default Photos library.
2. Request Photos permission on first use of the Export tab. Present a clear explanation: "Photo Pipeline needs access to your Photos library to add images for iPhone sync via iCloud."
3. **If permission denied:** Show a persistent banner on the Export tab explaining that Send to Photos is unavailable, with a button to open System Settings > Privacy > Photos. The Export to Instagram button continues to work independently.
4. On success, files appear in Photos.app and sync to iPhone via iCloud automatically.
5. Record each imported file path + timestamp in `state.json`. On subsequent runs, skip files already in the log.

## Preferences (Cmd-,)

| Setting | Default |
|---|---|
| Base photography folder | `~/Photography/` |
| Auto-open app on SD card detection | On |
| Show menubar icon | On |
| Strip GPS metadata from Instagram exports | On |
| Instagram long-edge target (px) | 1080 |
| JPEG export quality | 90 |

---

# 6. Integration Points

- **SD card:** Detected via `NSWorkspace.didMountNotificationName`. No launchd daemon.
- **Photomator:** No integration. Photomator reads/edits files in place from `Imports/YYYY-MM-DD/RAW/`. User exports finished JPEGs to `Exports/Portfolio/` manually.
- **Photos.app / iCloud:** PhotoKit (`PHPhotoLibrary`) for programmatic import. Files sync to iPhone automatically via iCloud Photos.

---

# 7. Constraints

- macOS 13 (Ventura) minimum. Test PhotoKit behavior on macOS 14 (Sonoma) as implementation details can vary.
- Personal use only. Distribute as standalone `.app`. No App Store, no sandboxing. This simplifies filesystem access.
- No external dependencies: no exiftool, no rclone, no Python, no Homebrew tools.
- Camera is Fuji X-T series. Fuji raw files use the `.RAF` extension.
- Prefer SwiftUI native components. No Electron, no embedded webviews.

### Permissions required

| Permission | Why | When prompted |
|---|---|---|
| Photos | PhotoKit import into iCloud Photos library | First use of Export tab's Send to Photos |
| Removable volumes | SD card read access | First SD card import |

No network access required or requested. App is fully local.

---

# 8. Acceptance Criteria

- [ ] SD card mount triggers notification and auto-populates Import tab source
- [ ] Import copies RAFs to `RAW/` and JPEGs to `JPEG/`, preserving originals on card
- [ ] Date folder collision creates `-b`, `-c` suffixes correctly
- [ ] Import log shows per-file pass/fail and final summary counts
- [ ] Instagram resize produces correct dimensions (long edge = 1080px, aspect preserved)
- [ ] Images already <= 1080px are copied without resampling
- [ ] GPS metadata is stripped from Instagram exports
- [ ] EXIF orientation is applied before resize (no rotated output)
- [ ] PhotoKit import adds files to Photos.app successfully
- [ ] Re-running Send to Photos skips previously imported files
- [ ] Permission denial for Photos shows clear banner with Settings link; Export to Instagram still works
- [ ] Menubar icon persists when main window is closed
- [ ] Preferences changes take effect without app restart
- [ ] App launches and runs without any Homebrew tools or external dependencies
- [ ] Feedback loop prompt has been run

---

# 9. Files Likely Touched

This is a new Xcode project. Suggested structure:

```
PhotoPipeline/
├── PhotoPipeline.xcodeproj
├── PhotoPipeline/
│   ├── PhotoPipelineApp.swift        ← App entry point, menubar setup
│   ├── ContentView.swift             ← Tab container (Import / Export)
│   ├── Views/
│   │   ├── ImportView.swift          ← Import tab UI
│   │   ├── ExportView.swift          ← Export tab UI
│   │   ├── PreferencesView.swift     ← Cmd-, preferences window
│   │   └── MenuBarView.swift         ← Menubar icon and menu
│   ├── Models/
│   │   ├── ImportSession.swift       ← Model for an import session (date, counts, paths)
│   │   ├── ExportFile.swift          ← Model for a pending export file
│   │   └── AppState.swift            ← Observable state: preferences, import history, Photos log
│   ├── Services/
│   │   ├── SDCardDetector.swift      ← NSWorkspace volume mount observer
│   │   ├── CardScanner.swift         ← Scans SD card for RAF/JPEG files
│   │   ├── FileImporter.swift        ← Copy + organize into dated folders
│   │   ├── ImageResizer.swift        ← Core Image / vImage resize + metadata strip
│   │   ├── PhotosImporter.swift      ← PhotoKit PHPhotoLibrary import
│   │   └── StateManager.swift        ← Read/write state.json and import_history.json
│   └── Assets.xcassets
```

### Existing files affected

- `docs/specs/photography-uploader-spec.md` → move to `docs/specs/implemented/` (retired)
- `docs/PROJECT_STATE.md` → update to reflect new pipeline direction
- `docs/DECISIONS.md` → append entry for pipeline replacement and RAW workflow change
- `docs/ARCHITECTURE.md` → rewrite to reflect new app-based architecture
- `CLAUDE.md` → update Stack table, workflow steps, and active constraints
