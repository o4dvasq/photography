# Photography Uploader — Mac App Spec
**Target:** Native SwiftUI Mac app (.app), launchable from Dock  
**Builder:** Cowork / Claude Code  
**Date:** March 10, 2026

---

## Overview

A native macOS app that replaces the command-line `upload.sh` workflow. The user launches the app from the Dock, selects a mode (curriculum week or personal project), and the app handles everything: file separation (JPEG vs RAW), EXIF-based renaming, folder creation, R2 sync, gallery generation, and git push.

---

## Filesystem Paths

All paths are relative to the user's home directory. Dropbox syncs `~/projects/`.

```
~/projects/photography/
├── Inbox/                          ← all new photos land here (JPEG + RAW mixed)
├── curriculum/                     ← organized JPEG curriculum shoots
│   └── YYYY-MM-week-##-slug/
│       ├── YYYYMMDD_w##_001.jpg
│       └── ...
├── projects/                       ← organized JPEG personal projects
│   └── project-slug/
│       ├── YYYYMMDD_slug_001.jpg
│       └── ...
├── raw/                            ← RAW files, mirrored folder structure
│   ├── curriculum/
│   │   └── YYYY-MM-week-##-slug/
│   │       └── YYYYMMDD_w##_001.RAF
│   └── projects/
│       └── project-slug/
│           └── YYYYMMDD_slug_001.RAF
├── photography/                    ← git repo
│   ├── upload.sh                   ← existing (app replaces this)
│   ├── generate_gallery.py         ← app will create this
│   ├── docs/                       ← GitHub Pages gallery output
│   │   ├── index.html
│   │   └── curriculum/
│   │       └── YYYY-MM-week-##-slug/
│   │           └── index.html
│   ├── ARCHITECTURE.md
│   └── upload_log.txt
└── upload_log.txt
```

---

## File Naming Convention

### Curriculum mode
**Format:** `YYYYMMDD_w##_###.ext`

| Segment | Example | Source |
|---------|---------|--------|
| Date | 20250308 | EXIF `DateTimeOriginal`, NOT filesystem date |
| Week | w02 | User input, zero-padded |
| Sequence | 001 | Auto-increment per batch, zero-padded |
| Extension | .jpg / .RAF | Original file extension, lowercased for JPEG |

### Project mode
**Format:** `YYYYMMDD_slug_###.ext`

| Segment | Example | Source |
|---------|---------|--------|
| Date | 20250410 | EXIF `DateTimeOriginal` |
| Slug | salento | User input, lowercased, hyphens for spaces |
| Sequence | 001 | Auto-increment per batch |

---

## App UI Design

### Window
- Fixed-size window, approximately 500×600pt
- No menu bar complexity — single-window app
- App name: **Photo Upload**
- App icon: camera shutter or similar (use SF Symbols for now)

### Main Screen Layout

```
┌─────────────────────────────────────────┐
│  Photo Upload                           │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  Mode:  ○ Curriculum  ○ Project │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ── Curriculum Fields ──                │
│  Week Number: [ 02        ]             │
│  Week Name:   [ leading-lines ]         │
│                                         │
│  ── OR Project Fields ──                │
│  Project Slug: [ salento-colombia ]     │
│                                         │
│  ── Inbox Status ──                     │
│  📷 12 JPEGs found                      │
│  📦 12 RAW files found                  │
│  📁 Inbox: ~/projects/photography/Inbox │
│                                         │
│  ┌─────────────┐  ┌──────────────┐      │
│  │  Dry Run    │  │   Upload ▶   │      │
│  └─────────────┘  └──────────────┘      │
│                                         │
│  ── Log ──                              │
│  ┌─────────────────────────────────┐    │
│  │ [scrolling log output here]     │    │
│  │ Scanning inbox...               │    │
│  │ Found 12 JPEGs, 12 RAFs        │    │
│  │ Extracting EXIF dates...        │    │
│  │ Renaming 20250308_w02_001.jpg   │    │
│  │ ...                             │    │
│  └─────────────────────────────────┘    │
│                                         │
│  [Gallery URL — click to copy]          │
└─────────────────────────────────────────┘
```

### UI Behavior

1. **On launch:** Immediately scan `~/projects/photography/Inbox/` and display file counts (JPEG vs RAW)
2. **Mode toggle:** Show/hide curriculum vs project fields based on selection
3. **Week Name field:** Auto-slugify as user types (lowercase, hyphens for spaces, strip special chars)
4. **Dry Run button:** Runs the full pipeline logic but moves nothing; outputs plan to log
5. **Upload button:** Runs the full pipeline; button disabled until mode + required fields are filled
6. **Log area:** Real-time scrolling output of each step
7. **Gallery URL:** Shown after successful upload; click copies to clipboard
8. **Validation:**
   - Inbox must contain at least 1 JPEG
   - Week number must be 1–52
   - Week name / project slug must be non-empty
   - Warn (don't block) if destination folder already exists (append to it)

---

## Pipeline Logic (What the App Does)

This is the sequence of operations when the user clicks "Upload":

### Step 1: Scan Inbox
- Read all files from `~/projects/photography/Inbox/`
- Separate by extension:
  - **JPEG:** `.jpg`, `.JPG`, `.jpeg`, `.JPEG`
  - **RAW:** `.RAF`, `.raf` (Fuji RAW format)
  - **Other:** Log warning, skip file
- Sort files by EXIF `DateTimeOriginal` (oldest first) for consistent sequencing

### Step 2: Extract EXIF Dates
- For each JPEG and RAW file, extract `DateTimeOriginal` using `exiftool`
- Command: `exiftool -DateTimeOriginal -s3 -d "%Y%m%d" filename`
- If EXIF date missing, fall back to file modification date with a warning in the log

### Step 3: Build Destination Folder Name

**Curriculum mode:**
```
YYYY-MM-week-##-slug
```
Where `YYYY-MM` comes from the EXIF date of the first file in the batch.

Example: `2025-03-week-02-leading-lines`

**Project mode:**
```
project-slug
```
Example: `salento-colombia`

### Step 4: Create Folders
- JPEG destination:
  - Curriculum: `~/projects/photography/curriculum/YYYY-MM-week-##-slug/`
  - Project: `~/projects/photography/projects/slug/`
- RAW destination (mirrored):
  - Curriculum: `~/projects/photography/raw/curriculum/YYYY-MM-week-##-slug/`
  - Project: `~/projects/photography/raw/projects/slug/`
- Create directories if they don't exist (`mkdir -p` equivalent)

### Step 5: Rename and Move Files
- Rename each file using the naming convention above
- Sequence numbers are continuous across the batch (JPEG and RAW get matching numbers if they share the same EXIF timestamp)
- **Matching logic:** For each JPEG, look for a RAW file with the same EXIF `DateTimeOriginal` (within 1-second tolerance). Matched pairs get the same sequence number. Unmatched RAWs get their own sequence numbers after all matched pairs.
- Move JPEGs to JPEG destination folder
- Move RAWs to RAW destination folder
- Log each file: `old_name → new_name`

### Step 6: Sync to Cloudflare R2
- Only sync the JPEG folder (RAW files stay local/Dropbox only)
- Command:
```
rclone sync "JPEG_DEST_FOLDER" "r2:oscar-photography/curriculum/FOLDER_NAME/"
```
or for projects:
```
rclone sync "JPEG_DEST_FOLDER" "r2:oscar-photography/projects/FOLDER_NAME/"
```
- Stream rclone stdout/stderr to the log area
- Verify exit code 0 before proceeding

### Step 7: Generate Gallery
- Run the gallery generator (see Gallery Generator section below)
- This produces/updates HTML files in `~/projects/photography/photography/docs/`

### Step 8: Git Commit and Push
- Working directory: `~/projects/photography/photography/`
- Commands:
```
git add docs/
git commit -m "Gallery update: FOLDER_NAME"
git push origin main
```
- Stream output to log

### Step 9: Log Entry
- Append to `~/projects/photography/upload_log.txt`:
```
YYYY-MM-DD HH:MM | mode | folder_name | ## JPEGs | ## RAWs | gallery_url
```

### Step 10: Display Gallery URL
- Curriculum: `https://o4dvasq.github.io/photography/curriculum/FOLDER_NAME/`
- Project: `https://o4dvasq.github.io/photography/projects/FOLDER_NAME/`
- Show in the UI as a clickable/copyable link

---

## Gallery Generator

This replaces the not-yet-built `generate_gallery.py`. Implement it as a Python script at `~/projects/photography/photography/generate_gallery.py` that the Swift app calls.

### What It Produces

**Per-folder page** (`docs/curriculum/FOLDER_NAME/index.html` or `docs/projects/FOLDER_NAME/index.html`):
- Responsive CSS grid of thumbnails
- Each thumbnail links to full-res image on R2
- Header with week/project name, date range, shot count
- No JavaScript framework — pure HTML/CSS

**Index page** (`docs/index.html`):
- Cards for each week/project
- Each card shows: name, date range, shot count, first image as thumbnail
- Sorted reverse-chronological (newest first)
- Separate sections for "Curriculum" and "Projects"

### R2 URL Pattern
```
https://pub-f7fa9781c49c409dbf4dfad2df808122.r2.dev/curriculum/FOLDER_NAME/FILENAME.jpg
https://pub-f7fa9781c49c409dbf4dfad2df808122.r2.dev/projects/FOLDER_NAME/FILENAME.jpg
```

### HTML Template Requirements
- Responsive: 3 columns desktop, 2 tablet, 1 mobile
- Dark background (#1a1a1a or similar) — photos pop on dark
- Minimal chrome — the images are the UI
- Thumbnail size: CSS `object-fit: cover` in fixed-aspect containers
- Clicking a thumbnail opens full-res in new tab
- No external dependencies (no CDN, no JS libraries)
- Gallery page title: week name or project name
- Each image shows filename on hover (for coach reference)

### Gallery Generator Invocation
The Swift app calls:
```
python3 ~/projects/photography/photography/generate_gallery.py
```

The script walks `~/projects/photography/curriculum/` and `~/projects/photography/projects/`, reads the JPEG filenames in each folder, and generates all HTML into `~/projects/photography/photography/docs/`.

---

## Dependencies & Prerequisites

The app assumes these are already installed on the Mac (they are):

| Tool | Location | Purpose |
|------|----------|---------|
| exiftool | `/opt/homebrew/bin/exiftool` | EXIF date extraction |
| rclone | `/opt/homebrew/bin/rclone` | R2 sync (already configured as remote `r2`) |
| python3 | `/usr/bin/python3` or `/opt/homebrew/bin/python3` | Gallery generator |
| git | `/usr/bin/git` | GitHub Pages deploy |

The app should check for these on launch and show a clear error if any are missing.

---

## Xcode Project Structure

```
PhotoUpload/
├── PhotoUpload.xcodeproj
├── PhotoUpload/
│   ├── PhotoUploadApp.swift          ← App entry point
│   ├── ContentView.swift             ← Main window UI
│   ├── Models/
│   │   ├── UploadMode.swift          ← Enum: .curriculum / .project
│   │   ├── InboxFile.swift           ← Model for scanned file (path, type, exifDate)
│   │   └── UploadConfig.swift        ← Holds user inputs (week, name, slug)
│   ├── Services/
│   │   ├── InboxScanner.swift        ← Scans inbox, separates JPEG/RAW
│   │   ├── ExifReader.swift          ← Calls exiftool, parses dates
│   │   ├── FileOrganizer.swift       ← Rename + move logic
│   │   ├── R2Syncer.swift            ← Calls rclone
│   │   ├── GalleryGenerator.swift    ← Calls generate_gallery.py
│   │   └── GitPusher.swift           ← git add/commit/push
│   ├── Utilities/
│   │   ├── ShellRunner.swift         ← Process() wrapper with streaming output
│   │   └── SlugFormatter.swift       ← Text → URL slug
│   └── Assets.xcassets
└── generate_gallery.py               ← Bundled or installed separately
```

### Key Implementation Notes

**ShellRunner.swift** — This is the core utility. Every external tool call goes through it:
- Wraps `Process` and `Pipe`
- Streams stdout/stderr line-by-line to a callback (for real-time log updates)
- Returns exit code
- Sets `PATH` to include `/opt/homebrew/bin` (critical for finding exiftool/rclone)

**App Sandbox** — The app needs filesystem access:
- Disable App Sandbox in entitlements (or use a very permissive sandbox)
- The app reads/writes to `~/projects/photography/` and calls CLI tools
- This is a personal-use app, not going to the App Store

**Async/Concurrency:**
- All pipeline steps run on a background thread/Task
- UI updates (log, progress, button states) on @MainActor
- Each step is a separate async function that can be awaited in sequence
- Cancel button should be available during upload (kills running Process)

---

## generate_gallery.py — Full Specification

Place this file at `~/projects/photography/photography/generate_gallery.py`.

### Behavior

1. Walk `~/projects/photography/curriculum/` — each subdirectory is a week
2. Walk `~/projects/photography/projects/` — each subdirectory is a project
3. For each folder:
   - List all `.jpg` files, sorted alphabetically
   - Extract date range from filenames (first and last date in `YYYYMMDD` prefix)
   - Count total images
   - Generate `docs/{curriculum|projects}/FOLDER_NAME/index.html`
4. Generate `docs/index.html` with cards linking to each folder page
5. Output directory: `~/projects/photography/photography/docs/`

### HTML Output — Per-Folder Page

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{FOLDER_DISPLAY_NAME}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: #1a1a1a; color: #e0e0e0; font-family: -apple-system, system-ui, sans-serif; }
        header { padding: 2rem; text-align: center; }
        header h1 { font-size: 1.5rem; font-weight: 300; letter-spacing: 0.05em; text-transform: uppercase; }
        header p { color: #888; margin-top: 0.5rem; font-size: 0.9rem; }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 4px;
            padding: 4px;
        }
        .grid a {
            display: block;
            position: relative;
            aspect-ratio: 3/2;
            overflow: hidden;
        }
        .grid img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            transition: transform 0.3s ease;
        }
        .grid a:hover img { transform: scale(1.02); }
        .grid a::after {
            content: attr(data-filename);
            position: absolute;
            bottom: 0;
            left: 0;
            right: 0;
            padding: 0.5rem;
            background: rgba(0,0,0,0.7);
            font-size: 0.75rem;
            color: #ccc;
            opacity: 0;
            transition: opacity 0.3s;
        }
        .grid a:hover::after { opacity: 1; }
        .back { display: block; text-align: center; padding: 2rem; color: #888; text-decoration: none; }
        .back:hover { color: #fff; }
    </style>
</head>
<body>
    <header>
        <h1>{FOLDER_DISPLAY_NAME}</h1>
        <p>{DATE_RANGE} · {COUNT} frames</p>
    </header>
    <div class="grid">
        <!-- One per image -->
        <a href="{R2_FULL_URL}" target="_blank" data-filename="{FILENAME}">
            <img src="{R2_FULL_URL}" loading="lazy" alt="{FILENAME}">
        </a>
    </div>
    <a href="../../" class="back">← All galleries</a>
</body>
</html>
```

### HTML Output — Index Page

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Oscar's Photography</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: #1a1a1a; color: #e0e0e0; font-family: -apple-system, system-ui, sans-serif; }
        header { padding: 3rem 2rem 1rem; text-align: center; }
        header h1 { font-size: 1.8rem; font-weight: 300; letter-spacing: 0.1em; text-transform: uppercase; }
        section { padding: 1rem 2rem; }
        section h2 { font-size: 0.9rem; font-weight: 400; text-transform: uppercase; letter-spacing: 0.1em; color: #888; margin-bottom: 1rem; border-bottom: 1px solid #333; padding-bottom: 0.5rem; }
        .cards {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
            gap: 1.5rem;
            margin-bottom: 3rem;
        }
        .card {
            display: block;
            text-decoration: none;
            color: inherit;
            background: #222;
            border-radius: 4px;
            overflow: hidden;
            transition: background 0.2s;
        }
        .card:hover { background: #2a2a2a; }
        .card-img { aspect-ratio: 16/9; overflow: hidden; }
        .card-img img { width: 100%; height: 100%; object-fit: cover; }
        .card-info { padding: 1rem; }
        .card-info h3 { font-size: 1rem; font-weight: 500; margin-bottom: 0.25rem; }
        .card-info p { font-size: 0.8rem; color: #888; }
    </style>
</head>
<body>
    <header>
        <h1>Oscar's Photography</h1>
    </header>
    <section>
        <h2>Curriculum</h2>
        <div class="cards">
            <!-- One per curriculum folder, reverse-chronological -->
            <a class="card" href="curriculum/{FOLDER_NAME}/">
                <div class="card-img">
                    <img src="{R2_FIRST_IMAGE_URL}" loading="lazy" alt="{FOLDER_DISPLAY_NAME}">
                </div>
                <div class="card-info">
                    <h3>{FOLDER_DISPLAY_NAME}</h3>
                    <p>{DATE_RANGE} · {COUNT} frames</p>
                </div>
            </a>
        </div>
    </section>
    <section>
        <h2>Projects</h2>
        <div class="cards">
            <!-- One per project folder, reverse-chronological -->
        </div>
    </section>
</body>
</html>
```

### Display Name Formatting

Convert folder slug to display name:
- `2025-03-week-02-leading-lines` → `Week 02 — Leading Lines`
- `salento-colombia` → `Salento Colombia`

Logic: 
- Curriculum: Extract week number, strip date prefix, title-case the slug remainder
- Projects: Title-case, replace hyphens with spaces

---

## Error Handling

| Scenario | App Behavior |
|----------|-------------|
| Inbox empty | Disable Upload button, show "No files in Inbox" |
| exiftool not found | Show alert on launch: "exiftool not installed. Run: brew install exiftool" |
| rclone not found | Same pattern |
| rclone fails | Show error in log, stop pipeline, don't proceed to gallery/git |
| git push fails | Log the error, still show gallery URL (local preview works) |
| EXIF date missing | Fall back to file modification date, log warning |
| Destination folder exists | Append files (continue sequence numbering from highest existing) |
| Mixed dates in batch | Use first file's date for folder name prefix, still rename each file with its own EXIF date |

---

## Nice-to-Haves (Future)

These are NOT in scope for v1 but are worth noting for later:

- Thumbnail preview of inbox contents before upload
- Drag-and-drop files onto the app window
- Menu bar mode (background app with menu bar icon)
- Auto-detect when SD card is inserted
- R2 upload progress bar (parse rclone `--progress` output)
- Open gallery in browser after push
- Integration with Photomator for RAW editing workflow
