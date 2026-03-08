#!/usr/bin/env bash
# compact-guard-stop.sh — Stop hook: session bookmark before exit
# Captures what changed SINCE last snapshot, creating a delta bookmark
# Increments session counter for cross-session tracking
# Pure bash, zero dependencies
# MIT License — github.com/jlceaser/context-guard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/compact-guard-lib.sh"

source "$HOME/.claude/hooks/hook-logger.sh" 2>/dev/null || true

# ─── Increment session counter ───────────────────────────────

NEW_SESSION=$(cg_increment_session)

# ─── Gather session delta ──────────────────────────────────

ROOT=$(cg_git_root)
PROJECT=""
BRANCH="?"
DIRTY=0

if [ -n "$ROOT" ] && [ -e "$ROOT/.git" ]; then
    PROJECT=$(basename "$ROOT")
    BRANCH=$(cg_git_branch "$ROOT")
    DIRTY=$(cg_git_dirty_count "$ROOT")
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
BOOKMARK_FILE="$COMPACT_GUARD_DIR/session-bookmark.md"

# ─── Worktree detection ───────────────────────────────────

WORKTREES=""
if [ -n "$ROOT" ]; then
    WORKTREES=$(git -C "$ROOT" worktree list 2>/dev/null | grep -v "(bare)" || true)
fi

# ─── Detect what changed since last snapshot ───────────────

LAST_SNAPSHOT=$(cg_latest_snapshot)
DELTA_FILES=""
if [ -n "$LAST_SNAPSHOT" ] && [ -n "$ROOT" ]; then
    # Files modified after last snapshot
    DELTA_FILES=$(find "$ROOT" -maxdepth 4 \
        -not -path '*/build/*' \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/__pycache__/*' \
        -not -path '*/vcpkg_installed/*' \
        -not -path '*/.next/*' \
        -not -path '*/dist/*' \
        -not -path '*/target/*' \
        -newer "$LAST_SNAPSHOT" \
        -type f 2>/dev/null | head -20 | sed "s|$ROOT/||" || true)
fi

# ─── Write session bookmark ────────────────────────────────

{
    echo "# Session Bookmark"
    echo ""
    echo "> Saved at session end. Use to resume work in next session."
    echo ""
    echo "| Field | Value |"
    echo "|-------|-------|"
    echo "| Time | $TIMESTAMP |"
    echo "| Session | #$((NEW_SESSION - 1)) |"
    echo "| Project | $PROJECT |"
    echo "| Branch | $BRANCH |"
    echo "| Uncommitted | $DIRTY files |"
    echo "| Context Guard | v${COMPACT_GUARD_VERSION} |"
    echo ""

    if [ -n "$DELTA_FILES" ]; then
        echo "## Files Changed Since Last Snapshot"
        echo ""
        echo '```'
        echo "$DELTA_FILES"
        echo '```'
        echo ""
    fi

    if [ -n "$ROOT" ] && [ "$DIRTY" -gt 0 ]; then
        echo "## Uncommitted Work"
        echo ""
        echo '```'
        cg_git_modified_files "$ROOT"
        echo '```'
        echo ""

        DIFF_STAT=$(cg_git_diff_stat "$ROOT")
        if [ -n "$DIFF_STAT" ]; then
            echo '```'
            echo "$DIFF_STAT"
            echo '```'
            echo ""
        fi
    fi

    # Worktree state
    if [ -n "$WORKTREES" ]; then
        WORKTREE_COUNT=$(echo "$WORKTREES" | wc -l | tr -d ' ')
        if [ "$WORKTREE_COUNT" -gt 1 ]; then
            echo "## Active Worktrees ($WORKTREE_COUNT)"
            echo ""
            echo '```'
            echo "$WORKTREES"
            echo '```'
            echo ""
        fi
    fi

    # Stashes
    if [ -n "$ROOT" ]; then
        STASH_COUNT=$(git -C "$ROOT" stash list 2>/dev/null | wc -l | tr -d ' ')
        if [ "$STASH_COUNT" -gt 0 ]; then
            echo "## Stashes ($STASH_COUNT)"
            echo ""
            echo '```'
            git -C "$ROOT" stash list 2>/dev/null | head -5
            echo '```'
            echo ""
        fi
    fi

    echo "---"
    echo "*[Context Guard](https://github.com/jlceaser/context-guard) v${COMPACT_GUARD_VERSION} — Session #$((NEW_SESSION - 1))*"
} > "$BOOKMARK_FILE"

hook_log "ContextGuard" "bookmark" "session=#$((NEW_SESSION - 1)) project=$PROJECT dirty=$DIRTY" 2>/dev/null || true
exit 0
