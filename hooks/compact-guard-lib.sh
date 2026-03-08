#!/usr/bin/env bash
# compact-guard-lib.sh — Shared functions for Claude Compact Guard
# Pure bash, zero dependencies, cross-platform (Linux/macOS/Windows Git Bash)
# MIT License — github.com/jlceaser/claude-compact-guard

COMPACT_GUARD_VERSION="2.0.0"
COMPACT_GUARD_DIR="${COMPACT_GUARD_DIR:-$HOME/.claude/compact-guard}"
COMPACT_GUARD_MAX_SNAPSHOTS="${COMPACT_GUARD_MAX_SNAPSHOTS:-10}"
COMPACT_GUARD_MAX_AGE="${COMPACT_GUARD_MAX_AGE:-900}"  # 15 minutes

# Ensure storage directory exists
mkdir -p "$COMPACT_GUARD_DIR" 2>/dev/null

# ─── Git State ────────────────────────────────────────────────

cg_git_root() {
    git rev-parse --show-toplevel 2>/dev/null || echo ""
}

cg_git_branch() {
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && echo "?" && return
    git -C "$root" branch --show-current 2>/dev/null || echo "detached"
}

cg_git_last_commits() {
    local root="${1:-$(cg_git_root)}"
    local count="${2:-5}"
    [ -z "$root" ] && return
    git -C "$root" log --oneline -"$count" 2>/dev/null || true
}

cg_git_dirty_count() {
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && echo "0" && return
    git -C "$root" status --porcelain 2>/dev/null | wc -l | tr -d ' '
}

cg_git_staged_files() {
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && return
    git -C "$root" diff --cached --name-only 2>/dev/null || true
}

cg_git_modified_files() {
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && return
    git -C "$root" status --porcelain 2>/dev/null | head -20 | sed 's/^...//'
}

cg_git_diff_stat() {
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && return
    git -C "$root" diff --stat HEAD 2>/dev/null || true
}

# ─── Worktree Detection ──────────────────────────────────────

cg_is_worktree() {
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && return 1
    [ -f "$root/.git" ] && return 0
    return 1
}

cg_worktree_list() {
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && return
    git -C "$root" worktree list 2>/dev/null || true
}

cg_worktree_count() {
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && echo "0" && return
    git -C "$root" worktree list 2>/dev/null | wc -l | tr -d ' '
}

# ─── Domain Classification ───────────────────────────────────

cg_classify_file() {
    local file="$1"
    case "$file" in
        core/*|*/core/*)           echo "core" ;;
        src/*|*/src/*)             echo "src" ;;
        lib/*|*/lib/*)             echo "lib" ;;
        qml/*|*.qml)              echo "ui" ;;
        ui/*|*/ui/*)              echo "ui" ;;
        components/*|*/components/*) echo "ui" ;;
        .github/*|.gitlab-ci*)    echo "ci" ;;
        CMake*|cmake*|justfile|Makefile|*.cmake) echo "build" ;;
        docs/*|*.md|CHANGELOG*)   echo "docs" ;;
        scripts/*|*.py|*.sh)      echo "scripts" ;;
        test*/*|*_test.*|*_spec.*|*_test/*) echo "test" ;;
        *.json|*.yaml|*.yml|*.toml) echo "config" ;;
        hooks/*|skills/*|agents/*|rules/*) echo "infra" ;;
        *)                         echo "other" ;;
    esac
}

cg_classify_changes() {
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && return

    local -A domains
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local domain
        domain=$(cg_classify_file "$file")
        domains[$domain]=$(( ${domains[$domain]:-0} + 1 ))
    done < <(git -C "$root" status --porcelain 2>/dev/null | sed 's/^...//')

    for domain in "${!domains[@]}"; do
        echo "$domain:${domains[$domain]}"
    done | sort -t: -k2 -rn
}

# ─── Snapshot Management ─────────────────────────────────────

cg_snapshot_path() {
    local slug
    slug=$(date '+%Y%m%d-%H%M%S')
    echo "$COMPACT_GUARD_DIR/snapshot-${slug}.md"
}

cg_latest_snapshot() {
    ls -t "$COMPACT_GUARD_DIR"/snapshot-*.md 2>/dev/null | head -1
}

cg_cleanup_snapshots() {
    ls -t "$COMPACT_GUARD_DIR"/snapshot-*.md 2>/dev/null | tail -n +"$(( COMPACT_GUARD_MAX_SNAPSHOTS + 1 ))" | while read -r old; do
        rm -f "$old"
    done
}

cg_snapshot_age() {
    local file="$1"
    [ ! -f "$file" ] && echo "99999" && return
    local mtime now
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo "0")
    now=$(date +%s)
    echo $(( now - mtime ))
}

cg_snapshot_count() {
    ls "$COMPACT_GUARD_DIR"/snapshot-*.md 2>/dev/null | wc -l | tr -d ' '
}

# ─── Context Health ───────────────────────────────────────────

cg_format_age() {
    local seconds="$1"
    if [ "$seconds" -lt 60 ]; then
        echo "${seconds}s"
    elif [ "$seconds" -lt 3600 ]; then
        echo "$(( seconds / 60 ))m"
    elif [ "$seconds" -lt 86400 ]; then
        echo "$(( seconds / 3600 ))h"
    else
        echo "$(( seconds / 86400 ))d"
    fi
}

# ─── JSON Helpers (pure bash) ────────────────────────────────

cg_json_extract() {
    local json="$1"
    local field="$2"
    echo "$json" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

cg_escape_json() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# ─── Markdown Table Field Extraction ──────────────────────────

cg_extract_field() {
    local key="$1" file="$2" default="${3:-}"
    local line
    line=$(grep -m1 "| ${key} |" "$file" 2>/dev/null || true)
    if [ -n "$line" ]; then
        echo "$line" | sed "s/.*| ${key} | *//;s/ *|[[:space:]]*$//"
    else
        echo "$default"
    fi
}
