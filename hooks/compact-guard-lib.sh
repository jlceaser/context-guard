#!/usr/bin/env bash
# compact-guard-lib.sh — Shared functions for Context Guard
# Pure bash, zero dependencies, cross-platform (Linux/macOS/Windows Git Bash)
# MIT License — github.com/jlceaser/context-guard

COMPACT_GUARD_VERSION="0.4.1"
COMPACT_GUARD_DIR="${COMPACT_GUARD_DIR:-$HOME/.claude/compact-guard}"
COMPACT_GUARD_ANNOT_DIR="${COMPACT_GUARD_ANNOT_DIR:-$HOME/.claude/annotations}"
COMPACT_GUARD_MAX_SNAPSHOTS="${COMPACT_GUARD_MAX_SNAPSHOTS:-10}"
COMPACT_GUARD_MAX_AGE="${COMPACT_GUARD_MAX_AGE:-900}"  # 15 minutes
COMPACT_GUARD_DIFF_LINES="${COMPACT_GUARD_DIFF_LINES:-40}"  # lines of diff per file
COMPACT_GUARD_DIFF_FILES="${COMPACT_GUARD_DIFF_FILES:-8}"   # max files to diff

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

# ─── Diff Capture ─────────────────────────────────────────────

cg_git_diff_content() {
    # Capture actual diff content for modified files (most valuable for recovery)
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && return

    local max_files="$COMPACT_GUARD_DIFF_FILES"
    local max_lines="$COMPACT_GUARD_DIFF_LINES"
    local count=0

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        count=$((count + 1))
        [ "$count" -gt "$max_files" ] && break

        echo "--- $file ---"
        git -C "$root" diff HEAD -- "$file" 2>/dev/null | head -"$max_lines"
        echo ""
    done < <(git -C "$root" diff --name-only HEAD 2>/dev/null)

    # Also capture staged diffs
    local staged_count=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        staged_count=$((staged_count + 1))
        [ "$((count + staged_count))" -gt "$max_files" ] && break

        echo "--- $file (staged) ---"
        git -C "$root" diff --cached -- "$file" 2>/dev/null | head -"$max_lines"
        echo ""
    done < <(git -C "$root" diff --cached --name-only 2>/dev/null)
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
        core/*|*/core/*)                echo "core" ;;
        src/*|*/src/*)                  echo "src" ;;
        lib/*|*/lib/*)                  echo "lib" ;;
        qml/*|*.qml)                    echo "ui" ;;
        ui/*|*/ui/*)                    echo "ui" ;;
        components/*|*/components/*)    echo "ui" ;;
        .github/*|.gitlab-ci*)          echo "ci" ;;
        CMake*|cmake*|justfile|Makefile|*.cmake) echo "build" ;;
        docs/*|*.md|CHANGELOG*)         echo "docs" ;;
        scripts/*|*.py|*.sh)            echo "scripts" ;;
        test*/*|*_test.*|*_spec.*|*_test/*) echo "test" ;;
        *.json|*.yaml|*.yml|*.toml)     echo "config" ;;
        hooks/*|skills/*|agents/*|rules/*) echo "infra" ;;
        *)                              echo "other" ;;
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

# ─── Session Chain ────────────────────────────────────────────

cg_session_file() {
    echo "$COMPACT_GUARD_DIR/.session-counter"
}

cg_session_number() {
    local file
    file=$(cg_session_file)
    if [ -f "$file" ]; then
        cat "$file" 2>/dev/null || echo "1"
    else
        echo "1"
    fi
}

cg_increment_session() {
    local file current next
    file=$(cg_session_file)
    current=$(cg_session_number)
    next=$((current + 1))
    echo "$next" > "$file"
    echo "$next"
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

# ─── Platform Detection ──────────────────────────────────────

cg_platform() {
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*)  echo "windows" ;;
        Darwin*)                echo "macos" ;;
        Linux*)                 echo "linux" ;;
        *)                      echo "unknown" ;;
    esac
}

cg_is_windows() {
    [ "$(cg_platform)" = "windows" ]
}

# ─── Settings.json Helpers ────────────────────────────────────

cg_settings_path() {
    echo "$HOME/.claude/settings.json"
}

cg_has_hook() {
    local hook_name="$1"
    local settings
    settings=$(cg_settings_path)
    [ -f "$settings" ] && grep -q "$hook_name" "$settings" 2>/dev/null
}

cg_has_env() {
    local var_name="$1"
    local settings
    settings=$(cg_settings_path)
    [ -f "$settings" ] && grep -q "$var_name" "$settings" 2>/dev/null
}

# ─── Telemetry ───────────────────────────────────────────────

COMPACT_GUARD_TELEMETRY="${COMPACT_GUARD_DIR}/telemetry.jsonl"

cg_telemetry_log() {
    # Usage: cg_telemetry_log "event_type" "status" "details"
    # event_type: snapshot|recovery|bookmark|restore_manual
    # status: ok|fail|skip
    local event="$1" status="$2" details="${3:-}"
    local ts session
    ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    session=$(cg_session_number)
    local root branch dirty
    root=$(cg_git_root)
    branch=$(cg_git_branch "$root")
    dirty=$(cg_git_dirty_count "$root")

    local escaped_details
    escaped_details=$(cg_escape_json "$details")

    echo "{\"ts\":\"$ts\",\"event\":\"$event\",\"status\":\"$status\",\"session\":$session,\"branch\":\"$branch\",\"dirty\":$dirty,\"details\":\"$escaped_details\"}" >> "$COMPACT_GUARD_TELEMETRY" 2>/dev/null || true
}

cg_telemetry_stats() {
    # Output summary stats from telemetry log
    [ ! -f "$COMPACT_GUARD_TELEMETRY" ] && echo "No telemetry data." && return

    local total snapshots recoveries bookmarks snap_ok snap_fail rec_ok rec_fail

    total=$(wc -l < "$COMPACT_GUARD_TELEMETRY" | tr -d ' \r\n')
    snapshots=$(grep -c '"event":"snapshot"' "$COMPACT_GUARD_TELEMETRY" 2>/dev/null | tr -d ' \r\n') || snapshots=0
    recoveries=$(grep -c '"event":"recovery"' "$COMPACT_GUARD_TELEMETRY" 2>/dev/null | tr -d ' \r\n') || recoveries=0
    bookmarks=$(grep -c '"event":"bookmark"' "$COMPACT_GUARD_TELEMETRY" 2>/dev/null | tr -d ' \r\n') || bookmarks=0

    snap_ok=$(grep '"event":"snapshot".*"status":"ok"' "$COMPACT_GUARD_TELEMETRY" 2>/dev/null | wc -l | tr -d ' \r\n') || snap_ok=0
    snap_fail=$(grep '"event":"snapshot".*"status":"fail"' "$COMPACT_GUARD_TELEMETRY" 2>/dev/null | wc -l | tr -d ' \r\n') || snap_fail=0
    rec_ok=$(grep '"event":"recovery".*"status":"ok"' "$COMPACT_GUARD_TELEMETRY" 2>/dev/null | wc -l | tr -d ' \r\n') || rec_ok=0
    rec_fail=$(grep '"event":"recovery".*"status":"fail"' "$COMPACT_GUARD_TELEMETRY" 2>/dev/null | wc -l | tr -d ' \r\n') || rec_fail=0

    local success_rate="N/A"
    if [ "$snapshots" -gt 0 ] 2>/dev/null; then
        success_rate="$(( snap_ok * 100 / snapshots ))%"
    fi

    echo "total=$total | snapshots=$snapshots ($snap_ok ok, $snap_fail fail) | recoveries=$recoveries ($rec_ok ok, $rec_fail fail) | bookmarks=$bookmarks | success=$success_rate"
}

cg_telemetry_cleanup() {
    # Keep last 200 entries
    [ ! -f "$COMPACT_GUARD_TELEMETRY" ] && return
    local count
    count=$(wc -l < "$COMPACT_GUARD_TELEMETRY" | tr -d ' ')
    if [ "$count" -gt 200 ]; then
        tail -200 "$COMPACT_GUARD_TELEMETRY" > "$COMPACT_GUARD_TELEMETRY.tmp"
        mv "$COMPACT_GUARD_TELEMETRY.tmp" "$COMPACT_GUARD_TELEMETRY"
    fi
}

# ─── Active Task Detection ───────────────────────────────────

cg_detect_active_task() {
    # Infer what the user was working on from git + file signals
    local root="${1:-$(cg_git_root)}"
    [ -z "$root" ] && return

    local task_hints=""

    # 1. Recent commit messages (last 3) — shows trajectory
    local recent_msgs
    recent_msgs=$(git -C "$root" log --oneline -3 --format='%s' 2>/dev/null || true)
    if [ -n "$recent_msgs" ]; then
        task_hints="Recent commits: $recent_msgs"
    fi

    # 2. Uncommitted changes scope — shows current focus
    local scope
    scope=$(cg_classify_changes "$root" | head -3 | paste -sd', ' -)
    if [ -n "$scope" ]; then
        task_hints="${task_hints:+$task_hints | }Active domains: $scope"
    fi

    # 3. Branch name often encodes task
    local branch
    branch=$(cg_git_branch "$root")
    case "$branch" in
        feat/*|fix/*|refactor/*|chore/*|build/*|ci/*|docs/*|test/*)
            task_hints="${task_hints:+$task_hints | }Branch task: $branch"
            ;;
    esac

    # 4. Check for TODO/FIXME in recent diffs
    local todo_count
    todo_count=$(git -C "$root" diff HEAD 2>/dev/null | grep -c '^\+.*\(TODO\|FIXME\|HACK\|XXX\)' 2>/dev/null | tr -d ' \r\n') || todo_count=0
    if [ "$todo_count" -gt 0 ] 2>/dev/null; then
        task_hints="${task_hints:+$task_hints | }Open TODOs in diff: $todo_count"
    fi

    echo "$task_hints"
}

# ─── Budget Zones ────────────────────────────────────────────

cg_estimate_zone() {
    # Estimate context budget zone from conversation signals
    # Returns: GREEN|YELLOW|ORANGE|RED
    # Heuristic: uses tool call count approximation from hook log
    local log_file="$HOME/.claude/hooks/logs/hook-events.log"
    local zone="GREEN"

    if [ ! -f "$log_file" ]; then
        echo "$zone"
        return
    fi

    # Count today's tool calls as proxy for context usage
    local today
    today=$(date '+%Y-%m-%d')
    local tool_calls
    tool_calls=$(grep -c "$today" "$log_file" 2>/dev/null | tr -d ' \r\n') || tool_calls=0

    # Check if compaction happened recently (strongest signal)
    local latest_snap
    latest_snap=$(cg_latest_snapshot)
    if [ -n "$latest_snap" ]; then
        local snap_age
        snap_age=$(cg_snapshot_age "$latest_snap")
        if [ "$snap_age" -lt 300 ] 2>/dev/null; then
            # Compaction within 5 min = was in RED, now fresh
            echo "GREEN"
            return
        fi
    fi

    # Heuristic zones based on tool call volume
    if [ "$tool_calls" -gt 80 ] 2>/dev/null; then
        zone="RED"
    elif [ "$tool_calls" -gt 50 ] 2>/dev/null; then
        zone="ORANGE"
    elif [ "$tool_calls" -gt 30 ] 2>/dev/null; then
        zone="YELLOW"
    fi

    echo "$zone"
}
