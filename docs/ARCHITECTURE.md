# Photography Workflow — Architecture
**Repo:** https://github.com/o4dvasq/photography
**Last updated:** March 22, 2026

---

## Overview

A post-shoot pipeline that organizes, archives, and publishes Fuji X-T50 JPEG photos to a public gallery — enabling persistent coach review without per-session file uploads.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    LOCAL (Mac)                          │
│                                                         │
│  Fuji X-T50                                            │
│      │ SD card / USB / Image Capture                   │
│      ▼                                                  │
│  ~/Documents/Photography/inbox/   ← staging area       │
│      │                                                  │
│  import.sh ──────────────────────────────────────────► │
│      │  (exiftool rename + folder creation)             │
│      ▼                                                  │
│  ~/Documents/Photography/curriculum/YYYY-MM-week-##-name│
│      │                             (iCloud synced)      │
│      │  Photomator references files in place            │
└──────┼──────────────────────────────────────────────────┘
       │ rclone sync (upload.sh)
       ▼
┌─────────────────────────────────────────────────────────┐
│              CLOUDFLARE R2 (cloud storage)              │
│                                                         │
│  Bucket: oscar-photography                              │
│  curriculum/2025-03-week-02-edge-to-edge-lines/         │
│      ├── 20250308_w02_001.jpg                           │
│      └── ...                                            │
│                                                         │
│  Public URL base:                                       │
│  https://pub-f7fa9781c49c409dbf4dfad2df808122.r2.dev   │
└─────────────────────────────────────────────────────────┘
       │ generate_gallery.py reads folder structure
       ▼
┌─────────────────────────────────────────────────────────┐
│            GITHUB PAGES (public gallery)                │
│                                                         │
│  https://o4dvasq.github.io/photography/                 │
│      /index.html          ← all weeks/projects          │
│      /curriculum/                                       │
│          /2025-03-week-02-edge-to-edge-lines/           │
│              /index.html  ← thumbnail grid              │
└─────────────────────────────────────────────────────────┘
```

---

## Infrastructure

### Cloudflare R2
| Property | Value |
|---|---|
| Bucket name | oscar-photography |
| Account ID | 1d83c25c1ff525735d3b68ab95b95054 |
| S3 Endpoint | https://1d83c25c1ff525735d3b68ab95b95054.r2.cloudflarestorage.com |
| Public Dev URL | https://pub-f7fa9781c49c409dbf4dfad2df808122.r2.dev |
| Public access | Enabled |

### rclone
| Property | Value |
|---|---|
| Remote name | r2 |
| Type | S3 / Cloudflare |
| Status | Installed, configured, tested |

### GitHub Pages
| Property | Value |
|---|---|
| Repo | https://github.com/o4dvasq/photography |
| Pages source | main branch → /docs folder |
| Gallery URL | https://o4dvasq.github.io/photography/ |
| Status | Repo created, Pages not yet enabled |

---

## Filesystem Layout

```
~/Dropbox/projects/photography/     ← git repo root (this repo)
├── CLAUDE.md
├── README.md
├── import.sh                       ← Stage 1: import from inbox
├── upload.sh                       ← Stage 2: sync to R2
├── lessons.txt                     ← curriculum lesson list
├── projects.txt                    ← auto-maintained project list
└── docs/
    ├── ARCHITECTURE.md             ← this file
    ├── PROJECT_STATE.md
    ├── DECISIONS.md
    ├── CONTEXT_HANDOFF.md
    ├── PHOTOGRAPHY_CURRICULUM.md
    └── specs/
        ├── README.md
        ├── photography-uploader-spec.md  ← future feature
        └── implemented/
            └── photography-workflow-spec.md

~/Documents/Photography/            ← iCloud synced (NOT in git)
├── inbox/                          ← all new photos land here
├── curriculum/                     ← 20-week course photos
│   └── 2025-03-week-02-edge-to-edge-lines/
└── projects/                       ← personal/travel work
```

---

## File Naming Convention

**Format:** `YYYYMMDD_w##_###.jpg`

| Segment | Example | Notes |
|---|---|---|
| Date | 20250308 | From EXIF, not filesystem date |
| Week | w02 | Zero-padded |
| Sequence | 001 | Zero-padded, per-shoot |

**Project files:** `YYYYMMDD_projectslug_###.jpg`

Original Fuji filenames (DSCF####.jpg) are not preserved after rename.

---

## Scripts

### import.sh
**Language:** Bash
**Dependencies:** exiftool (Homebrew)

Interactive menu-driven import. Shows numbered list of lessons (from lessons.txt) and projects (from projects.txt). Reads EXIF dates, renames files, moves from inbox to curriculum/project folders. Supports multi-session imports with auto-incrementing sequence numbers.

### upload.sh
**Language:** Bash
**Dependencies:** rclone, exiftool (Homebrew)

Zero-argument upload. Compares local JPEG counts against R2 file counts to find un-synced folders. Shows pending list, user picks one. Syncs via rclone, triggers gallery regeneration and git push.

### generate_gallery.py
**Language:** Python 3
**Status:** Not yet built

Walks ~/Documents/Photography/curriculum/ and projects/, reads R2 public URLs, generates static HTML gallery under docs/.

---

## Post-Shoot Workflow

```
1. Shoot (max 10 frames/day, Acros B&W JPEG)
2. Import: drag JPEGs to ~/Documents/Photography/inbox/
3. Run: ./import.sh  → renames + moves to curriculum/project folder
4. Curate in Photomator, delete rejects
5. Run: ./upload.sh  → syncs to R2, regenerates gallery
6. Paste gallery URL into coaching chat
```

---

## Build Status

| Step | Description | Status |
|---|---|---|
| 1 | import.sh | ✅ Built — needs real-world test |
| 2 | upload.sh | ✅ Built — needs real-world test |
| 3 | generate_gallery.py | 🔲 Not started |
| 4 | Gallery HTML template | 🔲 Not started |
| 5 | GitHub Pages enable | 🔲 Not started |

---

## Dependencies

| Tool | Install | Purpose |
|---|---|---|
| rclone | `brew install rclone` | R2 sync |
| exiftool | `brew install exiftool` | EXIF date extraction |
| Python 3 | Pre-installed on macOS | Gallery generator |
| git | Pre-installed on macOS | GitHub Pages deploy |
