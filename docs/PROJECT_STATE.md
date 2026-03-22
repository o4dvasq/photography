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
- **Repo structure** — Flattened. ~/Dropbox/projects/photography/ IS the git repo root. GitHub remote confirmed working.
- **docs/** — Organized: ARCHITECTURE.md (current), PROJECT_STATE.md, DECISIONS.md, CONTEXT_HANDOFF.md, PHOTOGRAPHY_CURRICULUM.md, specs/ with implemented/ subdirectory.

## What Was Just Completed (March 22, 2026)
- Flattened nested git repo: inner `photography/photography/` moved to project root, GitHub remote preserved
- Deleted parent-level leftovers: Inbox/, curriculum/, projects/, upload_log.txt, stale README, .gitignore, orphan .git
- Sorted from-crm-cleanup/ into proper locations, deleted stale duplicate docs
- Created docs/specs/implemented/ and filed completed specs there
- Updated ARCHITECTURE.md to reflect two-script pipeline and correct repo location

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
