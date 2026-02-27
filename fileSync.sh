#!/bin/bash
# =============================================================================
# fileSync.sh — macOS External SSD Sync Script
# Triggered automatically by launchd when a drive is connected.
# Skips silently if the target drive is not mounted.
# =============================================================================

# --- Configuration -----------------------------------------------------------

DRIVE_NAME="SSD Storage"                        # Must match name shown in Finder
BASE="/Volumes/$DRIVE_NAME/"                    # Destination base path on SSD
LOG=~/scripts/fileSync.log                          # Log file location
LOG_MAX_LINES=500                               # Max lines to keep in log

# --- Sync Pairs --------------------------------------------------------------
# Add or remove lines below to configure which folders to sync.
# Format: SOURCE DESTINATION (space separated, no trailing slash on source)

SOURCES=(
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/Downloads"
)

DESTINATIONS=(
    "$BASE/Desktop"
    "$BASE/Documents"
    "$BASE/Downloads"
)

# --- Do Not Edit Below This Line ---------------------------------------------

timestamp() {
    date "+%a %d %b %Y %T %Z"
}

# Check drive is mounted
if [ ! -d "$BASE" ]; then
    echo "$(timestamp): Drive '$DRIVE_NAME' not mounted, skipping." >> "$LOG"
    exit 0
fi

echo "$(timestamp): ========== Sync started ==========" >> "$LOG"

# Run each sync pair
for i in "${!SOURCES[@]}"; do
    SRC="${SOURCES[$i]}/"
    DEST="${DESTINATIONS[$i]}/"

    # Create destination if it doesn't exist
    mkdir -p "$DEST"

    echo "$(timestamp): Syncing $SRC -> $DEST" >> "$LOG"
    rsync -a --delete \
          --exclude='.DS_Store' \
          --exclude='.localized' \
          --exclude='*.tmp' \
          --exclude='.Spotlight-V100' \
          --exclude='.Trashes' \
          "$SRC" "$DEST" >> "$LOG" 2>&1

    STATUS=$?
    if [ $STATUS -eq 0 ]; then
        echo "$(timestamp): OK — $SRC" >> "$LOG"
    else
        echo "$(timestamp): ERROR (exit $STATUS) — $SRC" >> "$LOG"
    fi
done

echo "$(timestamp): ========== Sync complete ==========" >> "$LOG"

# Prune log to keep it manageable
tail -n "$LOG_MAX_LINES" "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"

exit 0
