# BUILD_GUIDE.md — Photo Pipeline App
**Date:** 2026-03-30
**For:** Claude Code (implementation fixes after Cowork cleanup)

---

## Project Location

```
~/Dropbox/projects/photography/PhotoPipeline/PhotoPipeline.xcodeproj
```

Swift source files are in `PhotoPipeline/PhotoPipeline/` with subdirectories: Models/, Services/, Views/.

The Xcode project uses `PBXFileSystemSynchronizedRootGroup` (auto-sync with filesystem). No manual file reference management needed. Just write files to the correct paths and Xcode picks them up automatically.

---

## What's Already Done (Cowork, March 30)

- Xcode project created and configured
- All 14 Swift source files written
- App Sandbox disabled (personal use, needs filesystem + Photos access)
- Hardened Runtime disabled (no notarization needed)
- Deployment target set to macOS 13.0
- Duplicate folders cleaned up (were Models 2/3, Services 2/3, Views 2/3)
- Nested .git removed from PhotoPipeline/

---

## Blocking Compile Fixes (Must Fix Before Build)

Read the spec at `docs/specs/SPEC_photo-pipeline-app.md` for full context.

### 1. StateManager.swift — Type mismatch

The method that returns already-imported file paths returns `[]`, which Swift infers as `[String]` (Array), but the return type is `Set<String>`. Change to `Set<String>()`.

### 2. FileImporter.swift — Force-unwrap crash

In the collision suffix increment logic, `lastChar.asciiValue!` force-unwraps an optional. If the character is non-ASCII this crashes. Add a guard with fallback to numeric suffix ("27", "28", etc.).

### 3. ImageResizer.swift — URL construction (2 locations)

Uses `URL(string:)` for file paths. This fails on paths with spaces or special characters. Replace both occurrences with `URL(fileURLWithPath:)`.

### 4. ExportFile.swift — Unreliable image dimensions

The `dimensions` computed property uses `NSImage.representations` which can return incorrect or nil sizes. Replace with CGImageSource:

```swift
var dimensions: (width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
          let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
          let height = properties[kCGImagePropertyPixelHeight as String] as? Int else {
        return nil
    }
    return (width, height)
}
```

---

## High Priority Fixes (Functional Issues)

### 5. PhotosImporter.swift — Race condition

`importedCount` and `failedCount` are modified inside `performChanges` closures without synchronization. Use a serial DispatchQueue or actor to protect these counters.

### 6. ExportView.swift — UI thread safety

The `photosPermissionStatus` state update inside the permission request callback may fire on a background thread. Wrap in `DispatchQueue.main.async` or use `@MainActor`.

### 7. ExportFile.swift — Hardcoded 1080px

The `needsResize` property hardcodes 1080px. It should read from AppState preferences or accept the target as a parameter.

---

## Build Settings (Already Configured)

| Setting | Value | Notes |
|---|---|---|
| ENABLE_APP_SANDBOX | NO | Needs filesystem + Photos access |
| ENABLE_HARDENED_RUNTIME | NO | No notarization needed |
| MACOSX_DEPLOYMENT_TARGET | 13.0 | Ventura minimum per spec |
| DEVELOPMENT_TEAM | 7BT67JPC78 | Already set |
| PRODUCT_BUNDLE_IDENTIFIER | o4dvasq.PhotoPipeline | Already set |

---

## File Tree (Current Clean State)

```
PhotoPipeline/
├── PhotoPipeline.xcodeproj/
│   └── project.pbxproj
└── PhotoPipeline/
    ├── Assets.xcassets/
    ├── ContentView.swift
    ├── PhotoPipelineApp.swift
    ├── Models/
    │   ├── AppState.swift
    │   ├── ExportFile.swift
    │   └── ImportSession.swift
    ├── Services/
    │   ├── CardScanner.swift
    │   ├── FileImporter.swift
    │   ├── ImageResizer.swift
    │   ├── PhotosImporter.swift
    │   ├── SDCardDetector.swift
    │   └── StateManager.swift
    └── Views/
        ├── ExportView.swift
        ├── ImportView.swift
        └── PreferencesView.swift
```

---

## Build & Test Workflow

1. Fix blocking issues (items 1-4 above)
2. Cmd-B to build, resolve any remaining compiler errors
3. Fix high-priority issues (items 5-7)
4. Cmd-R to run
5. Test against acceptance criteria in `docs/specs/SPEC_photo-pipeline-app.md`

---

## Test Checklist

- [ ] SD card mount triggers notification and auto-populates Import tab
- [ ] Import copies RAFs to RAW/ and JPEGs to JPEG/
- [ ] Date folder collision creates -b, -c suffixes
- [ ] Instagram resize: long edge = 1080px, aspect preserved
- [ ] Images <= 1080px copied without resampling
- [ ] GPS metadata stripped from Instagram exports
- [ ] EXIF orientation applied before resize
- [ ] PhotoKit import adds files to Photos.app
- [ ] Re-running Send to Photos skips previously imported files
- [ ] Photos permission denial shows banner, Export to Instagram still works
- [ ] Menubar icon persists when main window is closed
- [ ] Preferences persist across app restart
