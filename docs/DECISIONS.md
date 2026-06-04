# DECISIONS.md
Append-only log of key implementation decisions. Never overwrite — only add new entries at the bottom.

---

## March 8, 2026 — Initial Pipeline Build

**Task:** Build post-shoot upload pipeline

**Decisions:**
- **Cloudflare R2 over S3/Backblaze:** Free egress, simple public URL, rclone-compatible. No vendor lock-in concern for a photo gallery.
- **rclone over aws-cli:** Already supports R2 natively, handles sync with checksums, widely used.
- **exiftool for EXIF dates:** Reliable, handles Fuji-specific metadata, installed via Homebrew.
- **iCloud sync over manual sync:** Desktop & Documents sync handles two-device workflow (MacBook + Desktop) automatically. Photography root is ~/Documents/Photography/.
- **GitHub Pages for gallery:** Free, static HTML, no server to maintain. Serves from /docs folder on main branch.
- **JPEG only, no RAW:** Fuji film simulations are the creative workflow. No Lightroom, no RAW processing.

**Rejected:**
- Cloudflare Pages (unnecessary complexity for static HTML gallery)
- S3 (egress costs for public image serving)

---

## March 8, 2026 — Pipeline Split + Interactive Menus

**Task:** Split upload.sh into import + upload, add interactive menus

**Decisions:**
- **Two-stage pipeline:** import.sh (rename/organize) → Photomator curation → upload.sh (sync to R2). User deletes rejects in Photomator before upload. Previous single-script model didn't allow curation before upload.
- **Lessons, not weeks:** Organizing unit changed from "week number" to "lesson name." A lesson like "edge-to-edge-lines" may span multiple weeks. Folder names use YYYY-MM-slug format. lessons.txt is source of truth.
- **Interactive menus over flags:** User picks from a numbered list instead of remembering --week/--name syntax. Eliminates typo risk and name inconsistency between import and upload.
- **Auto-detect for upload.sh:** Compares local JPEG count vs R2 file count to find un-synced folders. Zero arguments needed.
- **projects.txt auto-maintained:** import.sh appends new project slugs. Shows in menu alongside curriculum lessons.
- **Sequence continuation:** When importing into an existing lesson folder, script reads highest existing sequence number and continues from there.

**Rejected:**
- Config file per folder (.week metadata file) — unnecessary complexity, the folder name itself is the identifier
- rclone --dry-run for comparison — unreliable when source folder doesn't exist yet; replaced with ls-based count comparison

---

## March 22, 2026 — Repo Flatten and Workflow Cleanup

**Task:** Flatten nested git repo, clean up migration artifacts, establish Claude Workflow System compatibility

**Decisions:**
- **Flatten inner repo to project root:** The Dropbox project folder `~/Dropbox/projects/photography/` is now the git repo root. The old structure had an orphan outer `.git` (no remote) wrapping an inner `photography/` dir with the real GitHub-connected `.git`. Flattened so one repo = one folder.
- **Preserve inner repo's git history:** The inner repo's `.git` (with GitHub remote and full commit history) was kept as the authoritative repo. The outer orphan `.git` was deleted.
- **Dropbox syncs source files, git/GitHub syncs git state:** Consistent with all other projects. `.git` dir has xattr Dropbox exclusion applied.
- **from-crm-cleanup/ fully sorted and deleted:** PHOTOGRAPHY_CURRICULUM.md and CONTEXT_HANDOFF.md kept as reference docs in docs/. photography-uploader-spec.md kept as a future spec in docs/specs/. Stale duplicates (CLAUDE.md, PROJECT_STATE.md, DECISIONS.md, ARCHITECTURE.md) deleted.
- **docs/specs/implemented/ created:** Completed specs move here. Keeps docs/specs/ clean — anything there is work not yet done.

---

## March 30, 2026 — Pipeline Replacement: Native macOS App

**Task:** Replace shell-based photography pipeline with a native SwiftUI menubar app

**Decisions:**
- **Native macOS app over shell scripts:** The terminal-based pipeline (import.sh, upload.sh) required too many manual steps and external dependencies (exiftool, rclone, Python). A native app with SD card auto-detection and one-click export eliminates friction.
- **Full replacement, not parallel tool:** The R2/GitHub Pages gallery pipeline, curriculum/lessons organization, and all shell scripts are retired. The new app handles the complete workflow: SD card import, Photomator handoff, Instagram resize, and iCloud Photos sync.
- **RAW files are now first-class:** Reversing the March 8 "JPEG only, no RAW" decision. Photomator now edits RAF files directly. The import step splits RAFs and JPEGs into separate folders within each dated session.
- **Date-based sessions over curriculum/lessons:** Replaced lesson-based folder naming (lessons.txt, projects.txt) with simple YYYY-MM-DD session folders. The curriculum structure added complexity without matching the actual workflow.
- **PhotoKit over AppleScript:** Using PHPhotoLibrary for iCloud Photos import. Reliable across macOS versions, proper permission model, no fragile scripting bridge.
- **Zero external dependencies:** No exiftool, no rclone, no Python, no Homebrew. Core Image/vImage for resize, PhotoKit for Photos import, NSWorkspace for SD detection. Everything ships in the .app.
- **Instagram resize with no-upscale rule:** Scale long edge to 1080px, but if source is already <= 1080px, copy as-is. No cropping, no padding. Strip GPS metadata.

**Retired:**
- import.sh, upload.sh, lessons.txt, projects.txt
- R2 bucket workflow, gallery generation, GitHub Pages gallery
- ~/Documents/Photography/ folder structure
- exiftool, rclone, Python dependencies

---
