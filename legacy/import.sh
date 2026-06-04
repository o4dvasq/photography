#!/usr/bin/env bash
# import.sh — Stage 1: Rename and organize inbox JPEGs
#
# Interactive. Just run: ./import.sh
# Then curate in Photomator. When done, run: ./upload.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PHOTOGRAPHY_ROOT="$HOME/Documents/Photography"
INBOX="$PHOTOGRAPHY_ROOT/inbox"
CURRICULUM_DIR="$PHOTOGRAPHY_ROOT/curriculum"
PROJECTS_DIR="$PHOTOGRAPHY_ROOT/projects"
LOG_FILE="$PHOTOGRAPHY_ROOT/upload_log.txt"
LESSONS_FILE="$SCRIPT_DIR/lessons.txt"
PROJECTS_FILE="$SCRIPT_DIR/projects.txt"

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
check_dependency exiftool

# ---------------------------------------------------------------------------
# Check inbox
# ---------------------------------------------------------------------------
INBOX_FILES=()
while IFS= read -r -d '' f; do
    INBOX_FILES+=("$f")
done < <(find "$INBOX" -maxdepth 1 \( -iname "*.jpg" \) -print0 | sort -z)

if [[ ${#INBOX_FILES[@]} -eq 0 ]]; then
    echo "No JPEG files found in $INBOX — nothing to import."
    exit 0
fi

echo "Found ${#INBOX_FILES[@]} file(s) in inbox."
echo ""

# ---------------------------------------------------------------------------
# Load lessons list
# ---------------------------------------------------------------------------
if [[ ! -f "$LESSONS_FILE" ]]; then
    echo "Error: lessons.txt not found at $LESSONS_FILE"
    exit 1
fi

declare -a LESSONS=()
while IFS= read -r line; do
    [[ -n "$line" ]] && LESSONS+=("$line")
done < "$LESSONS_FILE"

# ---------------------------------------------------------------------------
# Load projects list
# ---------------------------------------------------------------------------
declare -a PROJECTS=()
if [[ -f "$PROJECTS_FILE" ]]; then
    while IFS= read -r line; do
        [[ -n "$line" ]] && PROJECTS+=("$line")
    done < "$PROJECTS_FILE"
fi

# ---------------------------------------------------------------------------
# Prompt: what are we shooting?
# ---------------------------------------------------------------------------
echo "Which lesson are we on?"
echo ""
echo "  CURRICULUM:"
for i in "${!LESSONS[@]}"; do
    NUM=$((i + 1))
    printf "  %2d) %s\n" "$NUM" "${LESSONS[$i]}"
done

echo ""
echo "  PROJECTS:"
if [[ ${#PROJECTS[@]} -gt 0 ]]; then
    for i in "${!PROJECTS[@]}"; do
        NUM=$((${#LESSONS[@]} + i + 1))
        printf "  %2d) %s\n" "$NUM" "${PROJECTS[$i]}"
    done
fi
NEW_PROJECT_NUM=$((${#LESSONS[@]} + ${#PROJECTS[@]} + 1))
printf "  %2d) + New project\n" "$NEW_PROJECT_NUM"

echo ""
read -rp "Choice: " CHOICE

# ---------------------------------------------------------------------------
# Resolve choice
# ---------------------------------------------------------------------------
DEST_TYPE=""
SLUG=""

if [[ "$CHOICE" -ge 1 && "$CHOICE" -le ${#LESSONS[@]} ]]; then
    DEST_TYPE="curriculum"
    SLUG="${LESSONS[$((CHOICE - 1))]}"
elif [[ "$CHOICE" -ge $((${#LESSONS[@]} + 1)) && "$CHOICE" -lt "$NEW_PROJECT_NUM" ]]; then
    DEST_TYPE="project"
    PROJECT_INDEX=$((CHOICE - ${#LESSONS[@]} - 1))
    SLUG="${PROJECTS[$PROJECT_INDEX]}"
elif [[ "$CHOICE" -eq "$NEW_PROJECT_NUM" ]]; then
    DEST_TYPE="project"
    echo ""
    read -rp "Project slug (e.g. salento-colombia): " SLUG
    if [[ -z "$SLUG" ]]; then
        echo "Error: Project name cannot be empty."
        exit 1
    fi
    # Slugify: lowercase, spaces to hyphens, strip non-alphanumeric
    SLUG=$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    echo "$SLUG" >> "$PROJECTS_FILE"
    echo "Added \"$SLUG\" to projects list."
else
    echo "Invalid choice."
    exit 1
fi

echo ""
echo "→ ${DEST_TYPE}: ${SLUG}"
echo ""
read -rp "Continue? [Y/n]: " CONFIRM
if [[ "${CONFIRM,,}" == "n" ]]; then
    echo "Aborted."
    exit 0
fi

# ---------------------------------------------------------------------------
# Determine EXIF date
# ---------------------------------------------------------------------------
FIRST_FILE="${INBOX_FILES[0]}"
EXIF_DATE=$(exiftool -DateTimeOriginal -d "%Y%m%d" -S -s "$FIRST_FILE" 2>/dev/null || true)

if [[ -z "$EXIF_DATE" ]]; then
    echo "Warning: No EXIF DateTimeOriginal found — falling back to file modification date."
    EXIF_DATE=$(date -r "$FIRST_FILE" '+%Y%m%d')
fi

EXIF_YEAR="${EXIF_DATE:0:4}"
EXIF_MONTH="${EXIF_DATE:4:2}"

# ---------------------------------------------------------------------------
# Resolve destination folder
# ---------------------------------------------------------------------------
if [[ "$DEST_TYPE" == "curriculum" ]]; then
    BASE_DIR="$CURRICULUM_DIR"
    # Check if a folder for this lesson already exists (any date prefix)
    EXISTING=$(ls -d "$BASE_DIR"/*-"$SLUG" 2>/dev/null | head -1 || true)
else
    BASE_DIR="$PROJECTS_DIR"
    EXISTING=$(ls -d "$BASE_DIR"/*-"$SLUG" 2>/dev/null | head -1 || true)
fi

if [[ -n "$EXISTING" && -d "$EXISTING" ]]; then
    DEST_FOLDER="$EXISTING"
    echo "Adding to existing folder: $(basename "$DEST_FOLDER")"
else
    DEST_FOLDER="$BASE_DIR/${EXIF_YEAR}-${EXIF_MONTH}-${SLUG}"
    echo "Creating new folder: $(basename "$DEST_FOLDER")"
    mkdir -p "$DEST_FOLDER"
    log "Created folder: $DEST_FOLDER"
fi

# ---------------------------------------------------------------------------
# Determine next sequence number (supports adding to existing folders)
# ---------------------------------------------------------------------------
EXISTING_MAX=$(find "$DEST_FOLDER" -maxdepth 1 -iname "*.jpg" -print0 2>/dev/null \
    | xargs -0 -I{} basename {} \
    | grep -oE '_[0-9]{3}\.jpg$' \
    | grep -oE '[0-9]{3}' \
    | sort -n \
    | tail -1 || true)

if [[ -n "$EXISTING_MAX" ]]; then
    SEQUENCE=$((10#$EXISTING_MAX + 1))
else
    SEQUENCE=1
fi

# ---------------------------------------------------------------------------
# Build name prefix based on type
# ---------------------------------------------------------------------------
if [[ "$DEST_TYPE" == "curriculum" ]]; then
    # Extract lesson number from lessons list for filename prefix
    LESSON_NUM=0
    for i in "${!LESSONS[@]}"; do
        if [[ "${LESSONS[$i]}" == "$SLUG" ]]; then
            LESSON_NUM=$((i + 1))
            break
        fi
    done
    LESSON_PADDED=$(printf "%02d" "$LESSON_NUM")
    NAME_TAG="w${LESSON_PADDED}"
else
    NAME_TAG="$SLUG"
fi

# ---------------------------------------------------------------------------
# Rename and move files
# ---------------------------------------------------------------------------
declare -a MOVES=()

for SRC in "${INBOX_FILES[@]}"; do
    FILE_EXIF_DATE=$(exiftool -DateTimeOriginal -d "%Y%m%d" -S -s "$SRC" 2>/dev/null || true)
    if [[ -z "$FILE_EXIF_DATE" ]]; then
        FILE_EXIF_DATE=$(date -r "$SRC" '+%Y%m%d')
    fi

    NEW_NAME="${FILE_EXIF_DATE}_${NAME_TAG}_$(printf "%03d" "$SEQUENCE").jpg"
    DEST_FILE="$DEST_FOLDER/$NEW_NAME"

    if [[ -f "$DEST_FILE" ]]; then
        echo "  Skipping (already exists): $NEW_NAME"
        ((SEQUENCE++)) || true
        continue
    fi

    MOVES+=("$SRC|$DEST_FILE")
    ((SEQUENCE++)) || true
done

if [[ ${#MOVES[@]} -eq 0 ]]; then
    echo "All files already in destination — nothing to move."
else
    echo "Moving ${#MOVES[@]} file(s):"
    for PAIR in "${MOVES[@]}"; do
        SRC="${PAIR%%|*}"
        DST="${PAIR##*|}"
        echo "  $(basename "$SRC") → $(basename "$DST")"
        mv "$SRC" "$DST"
    done
    log "Imported ${#MOVES[@]} files to $DEST_FOLDER"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "Done. Open Photomator to curate, then run:"
echo "  ./upload.sh"
