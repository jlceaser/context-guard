#!/usr/bin/env bash
# compact-guard-pre.sh — PreCompact hook: comprehensive work state snapshot
# Captures: git state, disk state, build health, worktrees, environment, Claude ecosystem
# Pure bash, zero dependencies
# MIT License — github.com/jlceaser/context-guard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/compact-guard-lib.sh"

# Optional: source project's hook logger if available
source "$HOME/.claude/hooks/hook-logger.sh" 2>/dev/null || true

# ─── Read trigger info from stdin ────────────────────────────

INPUT=$(cat 2>/dev/null || echo "{}")
TRIGGER=$(cg_json_extract "$INPUT" "trigger")
[ -z "$TRIGGER" ] && TRIGGER="unknown"

# ─── Gather state: GIT ───────────────────────────────────────

ROOT=$(cg_git_root)
PROJECT=""
BRANCH="?"
DIRTY=0
LAST_COMMIT=""

if [ -n "$ROOT" ] && [ -e "$ROOT/.git" ]; then
    PROJECT=$(basename "$ROOT")
    BRANCH=$(cg_git_branch "$ROOT")
    LAST_COMMIT=$(git -C "$ROOT" log --oneline -1 2>/dev/null || echo "none")
    DIRTY=$(cg_git_dirty_count "$ROOT")
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
SNAPSHOT_FILE=$(cg_snapshot_path)

# ─── Gather state: DISK ─────────────────────────────────────

RECENT_DISK_FILES=""
if [ -n "$ROOT" ] && [ -e "$ROOT/.git/HEAD" ]; then
    RECENT_DISK_FILES=$(find "$ROOT" -maxdepth 4 \
        -not -path '*/build/*' \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/__pycache__/*' \
        -not -path '*/vcpkg_installed/*' \
        -newer "$ROOT/.git/HEAD" \
        -type f 2>/dev/null | head -30 | sed "s|$ROOT/||" || true)
fi

# ─── Gather state: BUILD ────────────────────────────────────

BUILD_STATE="unknown"
BUILD_DIR=""
BUILD_AGE=""
if [ -n "$ROOT" ]; then
    for dir in build/dev build/debug build/release build; do
        if [ -d "$ROOT/$dir" ]; then
            BUILD_DIR="$dir"
            NEWEST=$(find "$ROOT/$dir" -maxdepth 2 \( -name '*.exe' -o -name '*.dll' -o -name '*.o' \) 2>/dev/null | head -1)
            if [ -n "$NEWEST" ]; then
                BUILD_STATE="exists"
                ARTIFACT_TIME=$(stat -c %Y "$NEWEST" 2>/dev/null || stat -f %m "$NEWEST" 2>/dev/null || echo "0")
                NOW=$(date +%s)
                BUILD_AGE="$(( (NOW - ARTIFACT_TIME) / 60 ))min ago"
            else
                BUILD_STATE="empty"
            fi
            break
        fi
    done
    [ -z "$BUILD_DIR" ] && BUILD_STATE="no build dir"
fi

# ─── Gather state: PROJECT STRUCTURE ─────────────────────────

UNTRACKED=""
if [ -n "$ROOT" ]; then
    UNTRACKED=$(git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null | head -15 || true)
fi

BRANCHES=""
if [ -n "$ROOT" ]; then
    BRANCHES=$(git -C "$ROOT" branch --list 2>/dev/null | head -10 | sed 's/^..//' || true)
fi

# ─── Gather state: WORKTREES ─────────────────────────────────

WORKTREES=""
WORKTREE_COUNT=0
if [ -n "$ROOT" ]; then
    WORKTREES=$(git -C "$ROOT" worktree list 2>/dev/null || true)
    if [ -n "$WORKTREES" ]; then
        WORKTREE_COUNT=$(echo "$WORKTREES" | wc -l | tr -d ' ')
    fi
fi

# ─── Gather state: ENVIRONMENT ───────────────────────────────

DISK_USAGE=""
if [ -n "$ROOT" ]; then
    DISK_USAGE=$(du -sh "$ROOT" 2>/dev/null | cut -f1 || echo "?")
fi

ENV_SNAPSHOT=""
[ -n "${VCPKG_ROOT:-}" ] && ENV_SNAPSHOT="VCPKG_ROOT=$VCPKG_ROOT"
[ -n "${CMAKE_PREFIX_PATH:-}" ] && ENV_SNAPSHOT="$ENV_SNAPSHOT CMAKE_PREFIX_PATH=set"
[ -n "${VIRTUAL_ENV:-}" ] && ENV_SNAPSHOT="$ENV_SNAPSHOT VENV=active"

# ─── Gather state: CLAUDE ECOSYSTEM ─────────────────────────

MEMORY_DIR="$HOME/.claude/projects"
RECENT_MEMORY=""
if [ -d "$MEMORY_DIR" ] && [ -n "$ROOT" ] && [ -e "$ROOT/.git/HEAD" ]; then
    RECENT_MEMORY=$(find "$MEMORY_DIR" -name "*.md" -newer "$ROOT/.git/HEAD" 2>/dev/null | head -5 | sed "s|$HOME/||" || true)
fi

PREV_BOOKMARK=""
if [ -f "$COMPACT_GUARD_DIR/session-bookmark.md" ]; then
    PREV_BOOKMARK="exists"
fi

# ─── Write structured snapshot ───────────────────────────────

{
    echo "# Compact Guard Snapshot"
    echo ""
    echo "> Comprehensive work state captured before context compaction."
    echo "> Read this file after compaction to restore full working context."
    echo ""
    echo "## Session Info"
    echo ""
    echo "| Field | Value |"
    echo "|-------|-------|"
    echo "| Time | $TIMESTAMP |"
    echo "| Trigger | $TRIGGER |"
    echo "| Working Dir | $PWD |"
    echo "| Compact Guard | v${COMPACT_GUARD_VERSION} |"
    echo ""
    echo "## 1. Git State"
    echo ""
    echo "| Field | Value |"
    echo "|-------|-------|"
    echo "| Project | $PROJECT |"
    echo "| Branch | $BRANCH |"
    echo "| Last Commit | $LAST_COMMIT |"
    echo "| Uncommitted | $DIRTY files |"
    echo ""

    # Domain breakdown
    if [ -n "$ROOT" ] && [ "$DIRTY" -gt 0 ]; then
        echo "### Changes by Domain"
        echo ""
        echo "| Domain | Files |"
        echo "|--------|-------|"
        while IFS=: read -r domain count; do
            [ -z "$domain" ] && continue
            echo "| $domain | $count |"
        done < <(cg_classify_changes "$ROOT")
        echo ""
    fi

    # Modified files
    if [ -n "$ROOT" ] && [ "$DIRTY" -gt 0 ]; then
        echo "### Modified Files (git)"
        echo ""
        echo '```'
        cg_git_modified_files "$ROOT"
        echo '```'
        echo ""
    fi

    # Staged files
    STAGED=$(cg_git_staged_files "$ROOT")
    if [ -n "$STAGED" ]; then
        echo "### Staged for Commit"
        echo ""
        echo '```'
        echo "$STAGED"
        echo '```'
        echo ""
    fi

    # Diff stat
    if [ -n "$ROOT" ] && [ "$DIRTY" -gt 0 ]; then
        DIFF_STAT=$(cg_git_diff_stat "$ROOT")
        if [ -n "$DIFF_STAT" ]; then
            echo "### Change Summary (diff --stat)"
            echo ""
            echo '```'
            echo "$DIFF_STAT"
            echo '```'
            echo ""
        fi
    fi

    # Untracked files
    if [ -n "$UNTRACKED" ]; then
        echo "### Untracked Files (potential new work)"
        echo ""
        echo '```'
        echo "$UNTRACKED"
        echo '```'
        echo ""
    fi

    # Recent commits
    if [ -n "$ROOT" ]; then
        echo "### Recent Commits"
        echo ""
        echo '```'
        cg_git_last_commits "$ROOT" 8
        echo '```'
        echo ""
    fi

    # Branches
    if [ -n "$BRANCHES" ]; then
        echo "### Active Branches"
        echo ""
        echo '```'
        echo "$BRANCHES"
        echo '```'
        echo ""
    fi

    # ─── Section 2: Disk State ───────────────────────────────

    echo "## 2. Disk State"
    echo ""
    echo "| Field | Value |"
    echo "|-------|-------|"
    echo "| Project Size | $DISK_USAGE |"
    echo "| Build Dir | ${BUILD_DIR:-none} |"
    echo "| Build State | $BUILD_STATE |"
    [ -n "$BUILD_AGE" ] && echo "| Last Build | $BUILD_AGE |"
    echo ""

    if [ -n "$RECENT_DISK_FILES" ]; then
        echo "### Recently Modified Files (disk)"
        echo ""
        echo "Files modified since last commit (not just git-tracked):"
        echo ""
        echo '```'
        echo "$RECENT_DISK_FILES"
        echo '```'
        echo ""
    fi

    # ─── Section 3: Worktrees ────────────────────────────────

    if [ "$WORKTREE_COUNT" -gt 1 ]; then
        echo "## 3. Worktrees ($WORKTREE_COUNT)"
        echo ""
        echo '```'
        echo "$WORKTREES"
        echo '```'
        echo ""

        # Capture dirty state of each worktree
        while IFS= read -r wt_line; do
            WTP=$(echo "$wt_line" | awk '{print $1}')
            WTB=$(echo "$wt_line" | sed 's/.*\[//;s/\]//')
            [ "$WTP" = "$ROOT" ] && continue  # skip main
            WTD=$(git -C "$WTP" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            if [ "$WTD" -gt 0 ]; then
                echo "### Worktree: $WTB ($WTD uncommitted)"
                echo ""
                echo '```'
                git -C "$WTP" status --porcelain 2>/dev/null | head -10 | sed 's/^...//'
                echo '```'
                echo ""
            fi
        done <<< "$WORKTREES"
    fi

    # ─── Section 4: Environment ──────────────────────────────

    echo "## 4. Environment"
    echo ""
    echo "| Field | Value |"
    echo "|-------|-------|"
    echo "| Platform | $(uname -s 2>/dev/null || echo '?') |"
    echo "| Shell | $SHELL |"
    [ -n "$ENV_SNAPSHOT" ] && echo "| Key Vars | $ENV_SNAPSHOT |"

    # Stashes
    if [ -n "$ROOT" ]; then
        STASH_COUNT=$(git -C "$ROOT" stash list 2>/dev/null | wc -l | tr -d ' ')
        if [ "$STASH_COUNT" -gt 0 ]; then
            echo ""
            echo "### Stashes ($STASH_COUNT)"
            echo ""
            echo '```'
            git -C "$ROOT" stash list 2>/dev/null | head -5
            echo '```'
        fi
    fi
    echo ""

    # ─── Section 5: Claude Ecosystem State ───────────────────

    HAS_ECOSYSTEM=false

    if [ -n "$RECENT_MEMORY" ] || [ -n "$PREV_BOOKMARK" ]; then
        echo "## 5. Claude Ecosystem"
        echo ""
        HAS_ECOSYSTEM=true
    fi

    if [ -n "$RECENT_MEMORY" ]; then
        echo "### Recently Updated Memory Files"
        echo ""
        echo '```'
        echo "$RECENT_MEMORY"
        echo '```'
        echo ""
    fi

    if [ -n "$PREV_BOOKMARK" ]; then
        echo "### Previous Session Bookmark"
        echo ""
        echo "A session bookmark exists at: \`$COMPACT_GUARD_DIR/session-bookmark.md\`"
        echo "Read it for context from the previous session."
        echo ""
    fi

    # ─── Recovery instructions ───────────────────────────────

    echo "## Recovery"
    echo ""
    echo "After compaction, this snapshot was automatically saved."
    echo "If context was lost, read this file to restore working state:"
    echo ""
    echo '```bash'
    echo "# Claude will automatically detect this file via SessionStart hook"
    echo "# Or manually: Read $SNAPSHOT_FILE"
    echo '```'
    echo ""
    echo "---"
    echo "*[Context Guard](https://github.com/jlceaser/context-guard) v${COMPACT_GUARD_VERSION}*"

} > "$SNAPSHOT_FILE"

# Write latest pointer
cp "$SNAPSHOT_FILE" "$COMPACT_GUARD_DIR/latest.md"

# Cleanup old snapshots
cg_cleanup_snapshots

# ─── Build systemMessage for compaction ──────────────────────

DOMAIN_SUMMARY=""
if [ -n "$ROOT" ] && [ "$DIRTY" -gt 0 ]; then
    DOMAIN_SUMMARY=$(cg_classify_changes "$ROOT" | head -5 | paste -sd', ' -)
fi

SYS_PARTS="COMPACT GUARD: project=$PROJECT branch=$BRANCH dirty=$DIRTY build=$BUILD_STATE trigger=$TRIGGER"
[ -n "$LAST_COMMIT" ] && SYS_PARTS="$SYS_PARTS last=$LAST_COMMIT"
[ -n "$DOMAIN_SUMMARY" ] && SYS_PARTS="$SYS_PARTS domains=[$DOMAIN_SUMMARY]"
[ "$WORKTREE_COUNT" -gt 1 ] && SYS_PARTS="$SYS_PARTS worktrees=$WORKTREE_COUNT"

if [ -n "$ROOT" ] && [ "$DIRTY" -gt 0 ]; then
    MOD_LIST=$(cg_git_modified_files "$ROOT" | head -8 | paste -sd', ' - | cut -c1-200)
    SYS_PARTS="$SYS_PARTS files=[$MOD_LIST]"
fi

SYS_PARTS="$SYS_PARTS | Snapshot: $SNAPSHOT_FILE"

SYS_MSG=$(cg_escape_json "$SYS_PARTS")

hook_log "CompactGuard" "snapshot" "trigger=$TRIGGER dirty=$DIRTY build=$BUILD_STATE file=$SNAPSHOT_FILE" 2>/dev/null || true

echo "{\"systemMessage\":\"$SYS_MSG\"}"
exit 0
