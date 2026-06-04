# Photography Portfolio Workflow — Claude Code Build Spec

## Overview

Build a post-shoot upload pipeline that:
1. Organizes Fuji X-T50 JPEGs on the local filesystem by date + project
2. Renames files with a consistent date+week+sequence convention
3. Syncs to Cloudflare R2 for persistent public hosting
4. Auto-generates a static GitHub Pages gallery so a coach can browse all frames by lesson without file uploads in chat

---

## System Stack

| Layer | Tool | Purpose |
|---|---|---|
| Local archive | macOS Finder | Master source of truth |
| Visual browser | Photomator | Non-destructive, references files in place |
| Cloud storage | Cloudflare R2 | Public hosting, free egress |
| Gallery UI | GitHub Pages (static HTML) | Browsable by coach via URL |
| Upload automation | Bash script + rclone | One-command sync |

---

## Folder Structure

```
~/Photography/
├── inbox/                          ← all raw imports land here first
├── curriculum/
│   ├── 2025-03-week-02-edge-to-edge-lines/
│   │   ├── 20250308_w02_001.jpg
│   │   ├── 20250308_w02_002.jpg
│   │   └── ...
│   ├── 2025-03-week-03-[name]/
│   └── ...
└── projects/                       ← for non-curriculum personal work
    └── 2025-04-salento-colombia/
```

---

## File Naming Convention

**Format:** `YYYYMMDD_w##_###.jpg`

**Examples:**
- `20250308_w02_001.jpg`
- `20250308_w02_002.jpg`
- For project folders (non-curriculum): `20250410_salento_001.jpg`

Original Fuji filenames (DSCF####.jpg) are discarded after rename. Keep originals in `inbox/` until confirmed synced.

---

## Script: `upload.sh`

### Usage
```bash
./upload.sh --week 02 --name "edge-to-edge-lines"
# or for a project:
./upload.sh --project "salento-colombia"
```

### What it does (in order)
1. Reads all `.jpg` / `.JPG` files from `~/Photography/inbox/`
2. Creates destination folder: `~/Photography/curriculum/YYYY-MM-week-##-name/` (date auto-detected from EXIF)
3. Renames files to `YYYYMMDD_w##_###.jpg` using EXIF date
4. Moves renamed files from inbox → destination folder
5. Syncs destination folder to R2 bucket via `rclone`
6. Regenerates `index.html` gallery page (see below)
7. Pushes updated gallery to GitHub Pages
8. Prints the gallery URL to terminal

### Dependencies
- `rclone` (install via Homebrew: `brew install rclone`)
- `exiftool` (install via Homebrew: `brew install exiftool`)
- `git` (already present on Mac)

---

## Cloudflare R2 Setup

1. Create a Cloudflare account at cloudflare.com
2. Navigate to R2 → Create bucket → name it `oscar-photography`
3. Enable public access on the bucket
4. Create an API token with R2 read/write permissions
5. Configure rclone:

```bash
rclone config
# Name: r2
# Type: s3
# Provider: Cloudflare
# Access Key ID: [from Cloudflare dashboard]
# Secret Access Key: [from Cloudflare dashboard]
# Endpoint: https://[account-id].r2.cloudflarestorage.com
```

**R2 folder structure mirrors local:**
```
oscar-photography/
├── curriculum/
│   ├── 2025-03-week-02-edge-to-edge-lines/
│   └── ...
└── projects/
```

---

## GitHub Pages Gallery

**Repo:** existing GitHub repo (add a `/docs` folder or `gh-pages` branch)

### Gallery structure
- `/` → index listing all weeks/projects as cards with date, week number, shot count
- `/week-02/` → grid of all thumbnails for that week, click → full-res on R2

### Auto-generation
`upload.sh` runs `generate_gallery.py` after each sync, which:
1. Reads the R2 bucket manifest (or local folder structure)
2. Writes `docs/index.html` and `docs/[week-slug]/index.html`
3. `git add docs/ && git commit -m "gallery: add week-02" && git push`

### Gallery HTML features
- Responsive CSS grid, no JS framework — loads fast
- Each thumbnail links to full-res R2 URL
- Week/project label, date, shot count visible on card
- Single HTML file per week — no build toolchain needed

---

## Two-Device Sync (Laptop + Desktop)

Since Photomator references files in place, keep `~/Photography/` synced between devices via one of:
- **iCloud Drive** (easiest — move `~/Photography/` into `~/Library/Mobile Documents/`)
- **Dropbox** or **Syncthing** if you prefer to keep it outside iCloud

The R2 bucket is the canonical cloud copy regardless — the local filesystem is just your working layer.

---

## What the Coach Sees

Oscar pastes a URL like:
```
https://oscar-photography.pages.dev/curriculum/2025-03-week-02-edge-to-edge-lines/
```

Coach sees a responsive grid of every frame from the shoot, organized chronologically. Can view full-res by clicking any thumbnail. No file uploads needed in chat.

For a focused critique session, Oscar can also say: *"Look at frames 004, 007, and 009 specifically"* — coach fetches only those R2 URLs.

---

## Build Order for Claude Code

1. **Write `upload.sh`** — inbox scan, EXIF rename, folder creation, rclone sync
2. **Write `generate_gallery.py`** — reads local folder structure, outputs static HTML
3. **Set up rclone config helper** — interactive script to walk through R2 credentials
4. **Create gallery HTML template** — responsive, clean, no dependencies
5. **Wire together and test** with a sample batch of Fuji JPEGs
6. **Document** one-time setup steps (rclone, R2 bucket, GitHub Pages enable)

---

## Notes

- Script should be idempotent — safe to run twice on same inbox without duplicating files
- Add a `--dry-run` flag that shows what would happen without moving/uploading anything
- Inbox is cleared only after successful R2 sync confirmation
- Keep a simple `upload_log.txt` in `~/Photography/` tracking what was synced when
