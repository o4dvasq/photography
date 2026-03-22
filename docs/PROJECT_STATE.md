# PROJECT_STATE.md
**Last updated:** March 22, 2026
**Session:** Repo flatten and workflow cleanup

---

## What's Built and Working
- **import.sh** — Interactive menu-driven import. Shows numbered list of lessons (from lessons.txt) and projects (from projects.txt). Reads EXIF dates, renames files, moves from inbox to curriculum/project folders. Supports multi-session imports into the same lesson folder with auto-incrementing sequence numbers. Slugifies new project names and appends to projects.txt.
- **upload.sh** — Zero-argument upload. Compares local JPEG counts against R2 file counts to find un-synced folders. Shows pending list, user picks one (auto-selects if only one). Syncs via rclone, then triggers gallery regeneration and git push.
- **lessons.txt** — 9 lessons defined (leading-lines through pattern-and-repetition). Editable plain text, one slug per line.
- **projects.txt** — Auto-maintained by import.sh. Starts empty, grows as projects are created.
- **Cloudflare R2** — Bucket "oscar-photography" created, public access enabled, rclone configured with read+write API token.
- **Folder structure** — ~/Documents/Photography/ with inbox/, curriculum/, projects/ all working on iCloud sync.

## What Was Just Completed
- Fixed PHOTOGRAPHY_ROOT path ($HOME/Photography → $HOME/Documents/Photography)
- Replaced bash 4 mapfile with macOS-compatible while-read loop
- Fixed dry-run to skip rclone entirely (was failing on non-existent folder)
- Fixed R2 API token permissions (read-only → read+write)
- Split single upload.sh into two-stage pipeline (import.sh + upload.sh)
- Replaced flag-based interface with interactive menus
- Added lessons.txt / projects.txt as persistent config
- Created CLAUDE.md, PROJECT_STATE.md, DECISIONS.md, docs/specs/ for prompt workflow
- Flattened nested git repo structure: photography/photography/ → photography/ (GitHub remote preserved)
- Sorted docs from from-crm-cleanup/ into proper locations
- Organized docs/specs/ with implemented/ subdirectory

## Known Issues
- generate_gallery.py not yet built — upload.sh skips gallery step gracefully
- GitHub Pages not yet enabled on repo
- Gallery HTML template not yet designed

## Next Up
1. Build generate_gallery.py — reads curriculum/ and projects/ folders, outputs static HTML
2. Design gallery HTML template — responsive grid, thumbnails link to full-res R2 URLs
3. Enable GitHub Pages on /docs folder
4. End-to-end test: import → curate → upload → gallery live at public URL

## Open Design Questions
- Gallery structure: should docs/gallery/ be separate from docs/ root, or should gallery HTML live directly in docs/?
- Thumbnail strategy: generate smaller thumbnails locally before upload, or serve full-res from R2 with CSS scaling?
- Gallery index page: cards with shot count + date range, or simple list?
