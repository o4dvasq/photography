# PROJECT_STATE.md
**Last updated:** March 30, 2026
**Session:** Native macOS app implementation

---

## What's Built and Working

### Photo Pipeline App (Native macOS)
- **PhotoPipelineApp.swift** — SwiftUI menubar app entry point with SD card detection
- **Import tab** — SD card auto-detection, RAW/JPEG split into dated session folders, progress tracking
- **Export tab** — Instagram-optimized resize (1080px long edge), PhotoKit import to iCloud Photos
- **Preferences** — Configurable paths, auto-open behavior, GPS stripping, JPEG quality
- **Services layer** — SDCardDetector, CardScanner, FileImporter, ImageResizer, PhotosImporter, StateManager
- **Models** — AppState, ImportSession, ExportFile
- **Folder structure** — `~/Photography/Imports/YYYY-MM-DD/{RAW,JPEG}`, `~/Photography/Exports/{Portfolio,Instagram-Staged}`

### Retired Components
- **import.sh, upload.sh** — Replaced by native app
- **lessons.txt, projects.txt** — Curriculum structure replaced by date-based sessions
- **R2/GitHub Pages gallery pipeline** — Deferred (may be revisited)
- **generate_gallery.py** — Never built; pipeline retired
- **~/Documents/Photography/** — Replaced by `~/Photography/`

### Repository
- **Location:** `~/Dropbox/projects/photography/` (git repo root)
- **Remote:** https://github.com/o4dvasq/photography
- **Structure:** Swift source code in `PhotoPipeline/`, docs in `docs/`, specs in `docs/specs/`

---

## What Was Just Completed (March 30, 2026)

### Native App Implementation
- Complete SwiftUI codebase for macOS menubar app
- SD card detection via NSWorkspace volume mount notifications
- RAW/JPEG file import with date-based folder organization
- Collision handling for same-day re-imports (suffixes: -b, -c, ... -z, -27, ...)
- Instagram resize with EXIF orientation correction and GPS stripping
- PhotoKit integration for iCloud Photos import
- Permission handling with clear UI for Photos access denial
- State persistence (import history, Photos import log, preferences)

### Architecture Shift
- Replaced shell scripts with native code (zero external dependencies)
- Changed from lesson-based to date-based organization
- Integrated RAW files as first-class workflow (Photomator edits RAFs directly)
- Moved from R2 public gallery to private iCloud Photos sync

---

## Known Limitations

### Manual Setup Required
- Xcode project must be created manually and source files added
- App must be compiled in Xcode (no CLI build tested yet)
- No automated tests (acceptance criteria verification requires manual testing)

### PhotoKit Considerations
- Requires macOS 13 (Ventura) minimum
- Photos permission must be granted by user for Send to Photos feature
- Import tracking prevents duplicates but relies on file paths (renames break tracking)

### SD Card Detection
- Detects removable volumes via NSWorkspace
- May trigger on non-SD removable media (USB drives, etc.)
- No filtering by DCIM folder presence (scans any selected volume)

---

## Next Steps

### Immediate (Testing Phase)
1. Create Xcode project, add Swift source files
2. Build and run on macOS 13+ test machine
3. Test SD card detection with actual Fuji X-T50 card
4. Verify RAW/JPEG split, date folder creation, collision handling
5. Test Instagram resize with various image orientations and dimensions
6. Test PhotoKit import to iCloud Photos
7. Verify state persistence across app restarts

### Short-Term Enhancements
1. Add keyboard shortcuts for Import/Export actions
2. Implement drag-and-drop for manual folder selection
3. Add notification on import/export completion
4. Show storage space available before import
5. Add "Reveal in Finder" for Instagram-Staged folder

### Deferred (Future Consideration)
- Portfolio website upload (R2 sync + gallery generation)
- Glass feed integration
- Batch metadata editing
- RAW preview in app (Photomator handles this)
- iPhone companion app

---

## Open Design Questions

None. Core workflow decisions finalized in SPEC_photo-pipeline-app.md.
