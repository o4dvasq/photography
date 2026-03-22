# CLAUDE.md — Photography Workflow

## What This Is
A post-shoot pipeline that organizes, archives, and publishes Fuji X-T50 JPEG photos to a public gallery — enabling persistent coach review without per-session file uploads.

## Repo
https://github.com/o4dvasq/photography

## Key Files
```
photography/                        ← git repo root
├── CLAUDE.md                       ← you are here
├── import.sh                       ← Stage 1: interactive import from inbox
├── upload.sh                       ← Stage 2: auto-detect and sync to R2
├── generate_gallery.py             ← builds static HTML gallery (not yet built)
├── lessons.txt                     ← curriculum lesson list (editable)
├── projects.txt                    ← auto-maintained project list
├── docs/
│   ├── PROJECT_STATE.md            ← current project state (update every session)
│   ├── DECISIONS.md                ← append-only decision log
│   ├── ARCHITECTURE.md             ← system architecture
│   └── specs/                      ← feature specs from design sessions
│       └── SPEC_[feature-name].md
└── docs/gallery/                   ← GitHub Pages output (generated)
    ├── index.html
    └── curriculum/
        └── [lesson-slug]/
            └── index.html
```

## Stack
| Layer | Tool |
|---|---|
| Camera | Fuji X-T50, JPEG only, Acros B&W |
| Local archive | ~/Documents/Photography/ (iCloud synced) |
| Curation | Photomator (references files in place) |
| Cloud storage | Cloudflare R2 bucket "oscar-photography" |
| Upload | import.sh + upload.sh + rclone + exiftool |
| Gallery | GitHub Pages — static HTML, no JS framework |
| Gallery generator | generate_gallery.py (not yet built) |

## Workflow
1. Shoot → drag JPEGs to ~/Documents/Photography/inbox/
2. `./import.sh` → interactive menu, renames + moves to curriculum/project folder
3. Curate in Photomator, delete rejects
4. `./upload.sh` → auto-detects pending folders, syncs to R2, regenerates gallery

## Active Constraints
- macOS only (bash 3.x / zsh) — no mapfile, no bash 4+ features
- Photography root is ~/Documents/Photography/ (iCloud synced path)
- Lessons can span multiple weeks — organizing unit is lesson, not week
- lessons.txt is the source of truth for curriculum lesson names
- projects.txt is auto-maintained by import.sh
- Gallery must be pure HTML/CSS — no JS framework, no build toolchain
- R2 public URL base: https://pub-f7fa9781c49c409dbf4dfad2df808122.r2.dev
- GitHub Pages serves from main branch → /docs folder
