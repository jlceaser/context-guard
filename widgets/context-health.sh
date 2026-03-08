#!/usr/bin/env bash
# context-health.sh — StatusLine widget for context guard
# Shows: context %, snapshot count, last snapshot age
# Pure bash, zero dependencies
# MIT License — github.com/jlceaser/context-guard

# Read JSON from stdin (Claude Code status line payload)
INPUT=$(cat 2>/dev/null || echo "{}")

# Extract remaining percentage
REMAINING=$(echo "$INPUT" | sed -n 's/.*"remaining_percentage"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' | head -1)

if [ -z "$REMAINING" ]; then
    echo ""
    exit 0
fi

# Round to integer
REMAINING_INT=$(printf "%.0f" "$REMAINING" 2>/dev/null || echo "0")
USED=$((100 - REMAINING_INT))

# Context health indicator
if [ "$REMAINING_INT" -gt 60 ]; then
    ICON="●"   # green — healthy
elif [ "$REMAINING_INT" -gt 30 ]; then
    ICON="◐"   # yellow — moderate
elif [ "$REMAINING_INT" -gt 15 ]; then
    ICON="◑"   # orange — low
else
    ICON="○"   # red — critical
fi

# Snapshot info
GUARD_DIR="${COMPACT_GUARD_DIR:-$HOME/.claude/compact-guard}"
SNAP_COUNT=0
SNAP_AGE=""

if [ -d "$GUARD_DIR" ]; then
    SNAP_COUNT=$(ls "$GUARD_DIR"/snapshot-*.md 2>/dev/null | wc -l | tr -d ' ')
    LATEST=$(ls -t "$GUARD_DIR"/snapshot-*.md 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        MTIME=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null || echo "0")
        NOW=$(date +%s)
        AGE_SEC=$((NOW - MTIME))
        if [ "$AGE_SEC" -lt 60 ]; then
            SNAP_AGE="${AGE_SEC}s"
        elif [ "$AGE_SEC" -lt 3600 ]; then
            SNAP_AGE="$((AGE_SEC / 60))m"
        elif [ "$AGE_SEC" -lt 86400 ]; then
            SNAP_AGE="$((AGE_SEC / 3600))h"
        else
            SNAP_AGE="$((AGE_SEC / 86400))d"
        fi
    fi
fi

# Build status line segment
STATUS="$ICON ${REMAINING_INT}%"
[ "$SNAP_COUNT" -gt 0 ] && STATUS="$STATUS | ${SNAP_COUNT}snap"
[ -n "$SNAP_AGE" ] && STATUS="$STATUS(${SNAP_AGE})"

echo "$STATUS"
