#!/usr/bin/env bash
# compact-guard-post.sh — SessionStart hook addon: restore context after compaction
# Detects recent snapshot and injects recovery path as additionalContext
# Pure bash, zero dependencies
# MIT License — github.com/jlceaser/context-guard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/compact-guard-lib.sh"

# Optional: source project's hook logger
source "$HOME/.claude/hooks/hook-logger.sh" 2>/dev/null || true

# ─── Check for recent snapshot ───────────────────────────────

LATEST="$COMPACT_GUARD_DIR/latest.md"
RECOVERY_MSG=""

if [ -f "$LATEST" ]; then
    AGE=$(cg_snapshot_age "$LATEST")

    if [ "$AGE" -lt "$COMPACT_GUARD_MAX_AGE" ]; then
        # Recent snapshot found — this is likely a post-compaction restart

        # Extract key fields from snapshot (markdown table: | Key | Value |)
        # Pattern: strip everything up to "| Key | ", then strip trailing " |"
        cg_extract_field() {
            local key="$1" default="$2"
            local line
            line=$(grep -m1 "| ${key} |" "$LATEST" 2>/dev/null || true)
            if [ -n "$line" ]; then
                echo "$line" | sed "s/.*| ${key} | *//;s/ *|[[:space:]]*$//"
            else
                echo "$default"
            fi
        }

        PROJECT=$(cg_extract_field "Project" "?")
        BRANCH=$(cg_extract_field "Branch" "?")
        DIRTY=$(cg_extract_field "Uncommitted" "0" | sed 's/[^0-9].*//')
        TRIGGER=$(cg_extract_field "Trigger" "?")

        RECOVERY_MSG="POST-COMPACTION RECOVERY: A context compaction just happened (${AGE}s ago, trigger=$TRIGGER). Work state preserved in snapshot. Project=$PROJECT Branch=$BRANCH Dirty=$DIRTY. Read full snapshot: $LATEST"

        hook_log "CompactGuard" "recovery" "age=${AGE}s project=$PROJECT snapshot=$LATEST" 2>/dev/null || true
    fi
fi

# ─── Output ──────────────────────────────────────────────────

if [ -n "$RECOVERY_MSG" ]; then
    echo "$RECOVERY_MSG"
fi

# Note: This script is designed to be called FROM your session-start.sh
# Integration example:
#
#   # In your session-start.sh, add after other context:
#   COMPACT_RECOVERY=$("$HOME/.claude/hooks/compact-guard-post.sh" 2>/dev/null || true)
#   if [ -n "$COMPACT_RECOVERY" ]; then
#       CTX="$CTX | $COMPACT_RECOVERY"
#   fi

exit 0
