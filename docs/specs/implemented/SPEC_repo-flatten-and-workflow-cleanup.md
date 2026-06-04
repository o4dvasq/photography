SPEC: Repo Flatten & Workflow Cleanup | Project: photography | Date: 2026-03-22 | Status: Ready for implementation

---

## 1. Objective

Flatten the nested git repo structure so the Dropbox project folder IS the git repo, clean up migration artifacts, properly file all specs, delete leftover photo folders, and ensure the project is fully compatible with the Claude Workflow System (`/code start`, `/feedback-loop`, etc.).

## 2. Scope

Repo restructuring, file moves, and cleanup. No application code changes. No changes to `import.sh`, `upload.sh`, or the HTML gallery.

## 3. Business Rules

- The inner `photography/photography/` directory contains the real git repo (GitHub remote: `https://github.com/o4dvasq/photography.git`). Its contents must become the project root.
- The parent-level `.git` (no remote) is an orphan — delete it.
- The parent-level `Inbox/`, `curriculum/`, `projects/` folders contain leftover photos — delete them. The canonical photo storage is `~/Documents/Photography/` (iCloud), not Dropbox.
- The parent-level `upload_log.txt` and `README.md` are also leftovers — delete them.
- The `from-crm-cleanup/` directory is a migration artifact — sort its contents and delete the directory.
- CLAUDE.md must remain ≤80 lines.
- Implemented specs go in `docs/specs/implemented/`.

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

None.

## 6. Integration Points

- GitHub remote must still work after flattening (same repo URL, same branch)
- Scripts (`import.sh`, `upload.sh`) reference `$HOME/Documents/Photography` as PHOTOGRAPHY_ROOT — this is correct and should NOT change

## 7. Constraints

- Do not modify application code (`import.sh`, `upload.sh`, `index.html` or gallery files)
- CLAUDE.md ≤80 lines
- Preserve full git history from the inner repo
- The `.claude/` directory from the inner repo must be preserved at the new root

## 8. Acceptance Criteria

### Phase 1: Delete leftover files at parent level

- [ ] `Inbox/` directory deleted (contains ~50 leftover Fuji RAW/JPG files)
- [ ] `curriculum/` directory deleted
- [ ] `projects/` directory deleted
- [ ] `upload_log.txt` deleted
- [ ] Parent-level `README.md` deleted (inner repo has its own)
- [ ] Parent-level `.gitignore` deleted (inner repo has its own if needed)

### Phase 2: Flatten the repo

- [ ] Parent-level `.git/` directory deleted (orphan, no remote)
- [ ] Inner `photography/` directory contents moved up to project root
- [ ] Inner `photography/` empty directory removed
- [ ] Project root now contains: `.git/`, `.claude/`, `CLAUDE.md`, `README.md`, `docs/`, `import.sh`, `upload.sh`, `lessons.txt`, `projects.txt`
- [ ] `git remote -v` from project root shows `https://github.com/o4dvasq/photography.git`
- [ ] `git log` from project root shows full commit history
- [ ] `git status` shows the moved files (will need to be committed)

### Phase 3: Sort from-crm-cleanup contents

The `from-crm-cleanup/` directory is at the OLD parent level (`photography/docs/specs/from-crm-cleanup/`). After flattening, it will no longer be inside the repo. Its contents need to be sorted BEFORE or DURING the flatten:

- [ ] `photography-workflow-spec.md` → `docs/specs/implemented/` (this is the same spec as the one at repo root)
- [ ] `photography-uploader-spec.md` → `docs/specs/` (future feature, not yet implemented)
- [ ] `PHOTOGRAPHY_CURRICULUM.md` → `docs/` (reference document)
- [ ] `CONTEXT_HANDOFF.md` → `docs/` (reference document)
- [ ] `CLAUDE.md` from from-crm-cleanup → DELETE (stale duplicate of inner repo's CLAUDE.md)
- [ ] `PROJECT_STATE.md` from from-crm-cleanup → DELETE (stale duplicate)
- [ ] `DECISIONS.md` from from-crm-cleanup → DELETE (stale duplicate)
- [ ] `ARCHITECTURE.md` from from-crm-cleanup → DELETE (stale duplicate)
- [ ] `from-crm-cleanup/` directory deleted
- [ ] Parent-level `docs/` directory deleted (should be empty after sorting)

### Phase 4: Organize specs in the repo

- [ ] `docs/specs/implemented/` directory created
- [ ] `photography-workflow-spec.md` moved from repo root to `docs/specs/implemented/`
- [ ] `docs/specs/README.md` kept or updated

### Phase 5: Update stale docs

- [ ] `docs/ARCHITECTURE.md` reviewed and updated (flagged as stale in PROJECT_STATE.md)
- [ ] `docs/PROJECT_STATE.md` updated to reflect new folder structure and current state

### Phase 6: Finalize

- [ ] `.gitignore` exists at project root with appropriate entries (including .DS_Store, .venv, __pycache__, etc.)
- [ ] All changes committed with descriptive message
- [ ] `git push` succeeds
- [ ] `/feedback-loop` run successfully

## 9. Files Likely Touched

```
# DELETE (parent-level leftovers)
Inbox/                                          (DELETE - ~50 photo files)
curriculum/                                     (DELETE)
projects/                                       (DELETE)
upload_log.txt                                  (DELETE)
README.md (parent level)                        (DELETE)
.gitignore (parent level)                       (DELETE)
.git/ (parent level, orphan)                    (DELETE)

# DELETE (stale from-crm-cleanup copies)
docs/specs/from-crm-cleanup/CLAUDE.md           (DELETE)
docs/specs/from-crm-cleanup/PROJECT_STATE.md    (DELETE)
docs/specs/from-crm-cleanup/DECISIONS.md        (DELETE)
docs/specs/from-crm-cleanup/ARCHITECTURE.md     (DELETE)
docs/specs/from-crm-cleanup/                    (DELETE dir after sorting)

# MOVE (from inner photography/ up to root)
photography/* → ./                              (MOVE all contents up)
photography/.git/ → ./.git/                     (MOVE - this becomes the real root .git)
photography/.claude/ → ./.claude/               (MOVE)

# MOVE (sort from-crm-cleanup)
from-crm-cleanup/photography-workflow-spec.md   → docs/specs/implemented/
from-crm-cleanup/photography-uploader-spec.md   → docs/specs/
from-crm-cleanup/PHOTOGRAPHY_CURRICULUM.md      → docs/
from-crm-cleanup/CONTEXT_HANDOFF.md             → docs/

# MOVE (repo root cleanup)
photography-workflow-spec.md (repo root)        → docs/specs/implemented/

# CREATE
docs/specs/implemented/                         (CREATE dir)

# UPDATE
docs/ARCHITECTURE.md                            (UPDATE - currently stale)
docs/PROJECT_STATE.md                           (UPDATE - reflect new structure)
```

---

## Implementation Notes

The flatten operation is delicate because of the nested `.git` directories. Recommended approach:

1. First, copy the valuable files OUT of `from-crm-cleanup/` to a temp location
2. Delete all parent-level leftovers (Inbox, curriculum, projects, upload_log.txt, parent README, parent .gitignore)
3. Delete the parent `.git/` (the orphan)
4. Move everything from `photography/` up one level (including `photography/.git/`)
5. Remove the now-empty `photography/` directory
6. Sort the from-crm-cleanup files into their proper locations
7. Create `docs/specs/implemented/`, move the workflow spec there
8. Update docs, commit, push
