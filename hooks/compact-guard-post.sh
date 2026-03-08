#!/usr/bin/env bash
# compact-guard-post.sh — Post-compaction recovery context injection
# Can be used as: (1) SessionStart hook directly, or (2) addon called from session-start.sh
# Detects recent snapshot and outputs recovery path
# Pure bash, zero dependencies
# MIT License — github.com/jlceaser/context-guard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/compact-guard-lib.sh"

# Optional: source project's hook logger
source "$HOME/.claude/hooks/hook-logger.sh" 2>/dev/null || true

# ─── Detect if called as SessionStart hook or addon ──────────

IS_HOOK=false
INPUT=$(cat 2>/dev/null || echo "{}")
if echo "$INPUT" | grep -q "hookEventName" 2>/dev/null; then
    IS_HOOK=true
fi

# ─── Check for recent snapshot ───────────────────────────────

LATEST="$COMPACT_GUARD_DIR/latest.md"
RECOVERY_MSG=""

if [ -f "$LATEST" ]; then
    AGE=$(cg_snapshot_age "$LATEST")

    if [ "$AGE" -lt "$COMPACT_GUARD_MAX_AGE" ]; then
        # Recent snapshot found — this is likely a post-compaction restart
        PROJECT=$(cg_extract_field "Project" "$LATEST" "?")
        BRANCH=$(cg_extract_field "Branch" "$LATEST" "?")
        DIRTY=$(cg_extract_field "Uncommitted" "$LATEST" "0" | sed 's/[^0-9].*//')
        TRIGGER=$(cg_extract_field "Trigger" "$LATEST" "?")
        SESSION=$(cg_extract_field "Session" "$LATEST" "?")

        AGE_FMT=$(cg_format_age "$AGE")
        RECOVERY_MSG="POST-COMPACTION RECOVERY: Context compaction happened ${AGE_FMT} ago (trigger=$TRIGGER, session=$SESSION). Project=$PROJECT Branch=$BRANCH Dirty=$DIRTY. IMPORTANT: Read $LATEST for full state restoration."

        hook_log "ContextGuard" "recovery" "age=${AGE_FMT} project=$PROJECT snapshot=$LATEST" 2>/dev/null || true
        cg_telemetry_log "recovery" "ok" "age=${AGE_FMT} project=$PROJECT"
    fi
fi

# ─── Check for session bookmark ──────────────────────────────

BOOKMARK="$COMPACT_GUARD_DIR/session-bookmark.md"
if [ -f "$BOOKMARK" ] && [ -z "$RECOVERY_MSG" ]; then
    BK_AGE=$(cg_snapshot_age "$BOOKMARK")
    if [ "$BK_AGE" -lt 86400 ]; then  # within 24 hours
        BK_PROJECT=$(cg_extract_field "Project" "$BOOKMARK" "?")
        BK_BRANCH=$(cg_extract_field "Branch" "$BOOKMARK" "?")
        BK_DIRTY=$(cg_extract_field "Uncommitted" "$BOOKMARK" "0" | sed 's/[^0-9].*//')
        BK_AGE_FMT=$(cg_format_age "$BK_AGE")

        RECOVERY_MSG="SESSION RESUME: Previous session ended ${BK_AGE_FMT} ago. Project=$BK_PROJECT Branch=$BK_BRANCH Dirty=$BK_DIRTY. Read $BOOKMARK for session context."

        hook_log "ContextGuard" "resume" "age=${BK_AGE_FMT} project=$BK_PROJECT" 2>/dev/null || true
        cg_telemetry_log "recovery" "ok" "type=resume age=${BK_AGE_FMT}"
    fi
fi

# ─── Output ──────────────────────────────────────────────────

if [ "$IS_HOOK" = true ]; then
    # Called as SessionStart hook — output full JSON
    if [ -n "$RECOVERY_MSG" ]; then
        ESCAPED=$(cg_escape_json "$RECOVERY_MSG")
        echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"$ESCAPED\"}}"
    fi
else
    # Called as addon from session-start.sh — output plain text
    if [ -n "$RECOVERY_MSG" ]; then
        echo "$RECOVERY_MSG"
    fi
fi

exit 0
