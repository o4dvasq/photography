#!/usr/bin/env bash
# upload.sh — Stage 2: Sync curated photos to R2 and regenerate gallery
#
# Auto-detects folders with pending uploads. Just run: ./upload.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PHOTOGRAPHY_ROOT="$HOME/Documents/Photography"
CURRICULUM_DIR="$PHOTOGRAPHY_ROOT/curriculum"
PROJECTS_DIR="$PHOTOGRAPHY_ROOT/projects"
LOG_FILE="$PHOTOGRAPHY_ROOT/upload_log.txt"
R2_REMOTE="r2:oscar-photography"
GALLERY_SCRIPT="$(dirname "$0")/generate_gallery.py"
GALLERY_URL_BASE="https://oscar-photography.pages.dev"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() {
    echo "$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

check_dependency() {
    if ! command -v "$1" &>/dev/null; then
        echo "Error: '$1' is not installed. Install with: brew install $1"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
check_dependency rclone
check_dependency git

# ---------------------------------------------------------------------------
# Scan for folders that need syncing
# ---------------------------------------------------------------------------
echo "Checking for folders to upload..."
echo ""

declare -a PENDING_FOLDERS=()
declare -a PENDING_TYPES=()
declare -a PENDING_LOCAL_COUNTS=()
declare -a PENDING_R2_COUNTS=()

check_folder() {
    local DIR="$1"
    local TYPE="$2"

    [[ -d "$DIR" ]] || return

    local FOLDER_NAME
    FOLDER_NAME=$(basename "$DIR")

    local LOCAL_COUNT
    LOCAL_COUNT=$(find "$DIR" -maxdepth 1 -iname "*.jpg" 2>/dev/null | wc -l | tr -d ' ')
    [[ "$LOCAL_COUNT" -eq 0 ]] && return

    local R2_PATH="${R2_REMOTE}/${TYPE}/${FOLDER_NAME}"
    local R2_COUNT
    R2_COUNT=$(rclone ls "$R2_PATH" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$LOCAL_COUNT" -ne "$R2_COUNT" ]]; then
        PENDING_FOLDERS+=("$DIR")
        PENDING_TYPES+=("$TYPE")
        PENDING_LOCAL_COUNTS+=("$LOCAL_COUNT")
        PENDING_R2_COUNTS+=("$R2_COUNT")
    fi
}

for DIR in "$CURRICULUM_DIR"/*/; do
    check_folder "$DIR" "curriculum"
done

for DIR in "$PROJECTS_DIR"/*/; do
    check_folder "$DIR" "projects"
done

# ---------------------------------------------------------------------------
# Handle results
# ---------------------------------------------------------------------------
if [[ ${#PENDING_FOLDERS[@]} -eq 0 ]]; then
    echo "Everything is synced — nothing to upload."
    exit 0
fi

if [[ ${#PENDING_FOLDERS[@]} -eq 1 ]]; then
    echo "One folder needs syncing:"
    echo ""
    FOLDER_NAME=$(basename "${PENDING_FOLDERS[0]}")
    echo "  ${FOLDER_NAME} (${PENDING_LOCAL_COUNTS[0]} local, ${PENDING_R2_COUNTS[0]} on R2)"
    echo ""
    read -rp "Upload now? [Y/n]: " CONFIRM
    if [[ "${CONFIRM,,}" == "n" ]]; then
        echo "Aborted."
        exit 0
    fi
    SELECTED=0
else
    echo "Folders with pending changes:"
    echo ""
    for i in "${!PENDING_FOLDERS[@]}"; do
        NUM=$((i + 1))
        FOLDER_NAME=$(basename "${PENDING_FOLDERS[$i]}")
        printf "  %2d) %s (%s local, %s on R2)\n" "$NUM" "$FOLDER_NAME" "${PENDING_LOCAL_COUNTS[$i]}" "${PENDING_R2_COUNTS[$i]}"
    done
    echo ""
    read -rp "Which folder? " CHOICE
    SELECTED=$((CHOICE - 1))

    if [[ "$SELECTED" -lt 0 || "$SELECTED" -ge ${#PENDING_FOLDERS[@]} ]]; then
        echo "Invalid choice."
        exit 1
    fi
fi

DEST_FOLDER="${PENDING_FOLDERS[$SELECTED]}"
TYPE="${PENDING_TYPES[$SELECTED]}"
FOLDER_NAME=$(basename "$DEST_FOLDER")
R2_DEST="${R2_REMOTE}/${TYPE}/${FOLDER_NAME}"
GALLERY_URL="${GALLERY_URL_BASE}/${TYPE}/${FOLDER_NAME}/"
COMMIT_MSG="gallery: update ${FOLDER_NAME}"

echo ""
echo "Uploading: $FOLDER_NAME"
echo "  Local: ${PENDING_LOCAL_COUNTS[$SELECTED]} files"
echo "  R2:    ${PENDING_R2_COUNTS[$SELECTED]} files"

# ---------------------------------------------------------------------------
# Step 1: Sync to R2
# ---------------------------------------------------------------------------
echo ""
echo "Syncing to R2..."

if rclone sync "$DEST_FOLDER" "$R2_DEST" --progress --checksum; then
    log "Synced $DEST_FOLDER → $R2_DEST (${PENDING_LOCAL_COUNTS[$SELECTED]} files)"
else
    echo "Error: rclone sync failed."
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: Regenerate gallery and push to GitHub Pages
# ---------------------------------------------------------------------------
if [[ -f "$GALLERY_SCRIPT" ]]; then
    echo ""
    echo "Regenerating gallery..."
    python3 "$GALLERY_SCRIPT"
    log "Gallery regenerated"
else
    echo "Note: generate_gallery.py not found — skipping gallery step."
fi

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
DOCS_DIR="$SCRIPT_DIR/docs"

if [[ -d "$DOCS_DIR" ]]; then
    echo "Pushing gallery to GitHub Pages..."
    cd "$SCRIPT_DIR"
    git add docs/
    if git diff --cached --quiet; then
        echo "Gallery unchanged — nothing to commit."
    else
        git commit -m "$COMMIT_MSG"
        git push
        log "Pushed gallery: $COMMIT_MSG"
    fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "Done."
echo "Gallery URL: $GALLERY_URL"
