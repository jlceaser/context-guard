#!/usr/bin/env bash
# Context Guard — Self-Test Suite
# Validates installation, hook functionality, and snapshot integrity
# MIT License — github.com/jlceaser/context-guard

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

echo -e "${BOLD}Context Guard — Self-Test${NC}"
echo ""

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}WARN${NC} $1"; WARN=$((WARN + 1)); }
skip() { echo -e "  ${DIM}SKIP${NC} $1"; }

HOOKS_DIR="$HOME/.claude/hooks"
SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"
GUARD_DIR="$HOME/.claude/compact-guard"
SETTINGS="$HOME/.claude/settings.json"

# ─── 1. File Installation ────────────────────────────────────

echo -e "${CYAN}1. File Installation${NC}"

for file in compact-guard-lib.sh compact-guard-pre.sh compact-guard-post.sh compact-guard-stop.sh; do
    if [ -f "$HOOKS_DIR/$file" ]; then
        pass "$file installed"
    else
        fail "$file not found in $HOOKS_DIR"
    fi
done

for skill in cg-snapshot cg-restore cg-context-status cg-setup cg-annotate cg-recall; do
    if [ -f "$SKILLS_DIR/$skill/SKILL.md" ]; then
        pass "Skill: $skill (plugin format)"
    elif [ -f "$SKILLS_DIR/$skill.md" ]; then
        pass "Skill: $skill (flat format)"
    else
        warn "Skill $skill not found (optional)"
    fi
done

if [ -f "$AGENTS_DIR/context-keeper.md" ]; then
    pass "Agent: context-keeper.md"
else
    warn "Agent context-keeper.md not found (optional)"
fi

if [ -d "$GUARD_DIR" ]; then
    pass "Data directory exists"
else
    fail "Data directory $GUARD_DIR missing"
fi

# ─── 2. Script Syntax ────────────────────────────────────────

echo ""
echo -e "${CYAN}2. Script Syntax${NC}"

for file in compact-guard-lib.sh compact-guard-pre.sh compact-guard-post.sh compact-guard-stop.sh; do
    if [ -f "$HOOKS_DIR/$file" ]; then
        if bash -n "$HOOKS_DIR/$file" 2>/dev/null; then
            pass "$file syntax OK"
        else
            fail "$file has syntax errors"
        fi
    fi
done

# ─── 3. Library Functions ────────────────────────────────────

echo ""
echo -e "${CYAN}3. Library Functions${NC}"

# Source the library in a subshell to test
if (
    source "$HOOKS_DIR/compact-guard-lib.sh" 2>/dev/null

    # Test version
    [ -n "$COMPACT_GUARD_VERSION" ] || exit 1

    # Test JSON escape
    RESULT=$(cg_escape_json 'hello "world"')
    echo "$RESULT" | grep -q 'hello \\"world\\"' || exit 1

    # Test format_age
    [ "$(cg_format_age 30)" = "30s" ] || exit 1
    [ "$(cg_format_age 120)" = "2m" ] || exit 1
    [ "$(cg_format_age 7200)" = "2h" ] || exit 1

    # Test platform detection
    PLAT=$(cg_platform)
    [ -n "$PLAT" ] || exit 1

    # Test classify_file
    [ "$(cg_classify_file 'core/src/main.cpp')" = "core" ] || exit 1
    [ "$(cg_classify_file 'qml/Main.qml')" = "ui" ] || exit 1
    [ "$(cg_classify_file 'CMakeLists.txt')" = "build" ] || exit 1
    [ "$(cg_classify_file 'test/unit_test.cpp')" = "test" ] || exit 1
    [ "$(cg_classify_file '.github/workflows/ci.yml')" = "ci" ] || exit 1

    # Test session counter
    [ -n "$(cg_session_number)" ] || exit 1

    exit 0
); then
    pass "Library functions work correctly"
else
    fail "Library function tests failed"
fi

# ─── 4. Settings Configuration ───────────────────────────────

echo ""
echo -e "${CYAN}4. Settings Configuration${NC}"

if [ -f "$SETTINGS" ]; then
    pass "settings.json exists"

    if grep -q "compact-guard-pre" "$SETTINGS" 2>/dev/null; then
        pass "PreCompact hook configured"
    else
        fail "PreCompact hook not in settings.json"
    fi

    if grep -q "compact-guard-stop" "$SETTINGS" 2>/dev/null; then
        pass "Stop hook configured"
    else
        warn "Stop hook not in settings.json (optional)"
    fi

    if grep -q "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "$SETTINGS" 2>/dev/null; then
        VALUE=$(grep "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "$SETTINGS" | sed 's/.*: *"//;s/".*//')
        if [ "$VALUE" -le 90 ] 2>/dev/null; then
            pass "Autocompact override: ${VALUE}%"
        else
            warn "Autocompact override is ${VALUE}% (recommended: 80)"
        fi
    else
        fail "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE not set"
    fi

    # Validate JSON
    if command -v jq &>/dev/null; then
        if jq empty "$SETTINGS" 2>/dev/null; then
            pass "settings.json is valid JSON"
        else
            fail "settings.json has invalid JSON"
        fi
    else
        skip "JSON validation (jq not available)"
    fi
else
    fail "settings.json not found"
fi

# ─── 5. Dry-Run Snapshot ─────────────────────────────────────

echo ""
echo -e "${CYAN}5. Dry-Run Snapshot${NC}"

# Run pre-hook with manual trigger
SNAP_OUTPUT=$(echo '{"trigger":"self_test"}' | bash "$HOOKS_DIR/compact-guard-pre.sh" 2>/dev/null || echo "HOOK_FAILED")

if echo "$SNAP_OUTPUT" | grep -q "systemMessage" 2>/dev/null; then
    pass "PreCompact hook executes successfully"

    # Verify snapshot was created
    LATEST="$GUARD_DIR/latest.md"
    if [ -f "$LATEST" ]; then
        pass "Snapshot file created"

        # Verify snapshot structure
        SECTIONS=0
        grep -q "## Session Info" "$LATEST" 2>/dev/null && SECTIONS=$((SECTIONS + 1))
        grep -q "## 1. Git State" "$LATEST" 2>/dev/null && SECTIONS=$((SECTIONS + 1))
        grep -q "## 2. Disk State" "$LATEST" 2>/dev/null && SECTIONS=$((SECTIONS + 1))
        grep -q "## 4. Environment" "$LATEST" 2>/dev/null && SECTIONS=$((SECTIONS + 1))
        grep -q "## Recovery" "$LATEST" 2>/dev/null && SECTIONS=$((SECTIONS + 1))

        if [ "$SECTIONS" -ge 4 ]; then
            pass "Snapshot structure: ${SECTIONS}/5 core sections"
        else
            warn "Snapshot structure: only ${SECTIONS}/5 sections found"
        fi

        # Check version in snapshot
        if grep -q "v0\.3\." "$LATEST" 2>/dev/null || grep -q "v3\." "$LATEST" 2>/dev/null; then
            pass "Snapshot version: v0.3.x"
        else
            warn "Snapshot version mismatch"
        fi

        # Check diff content section (if dirty)
        if git status --porcelain 2>/dev/null | head -1 | grep -q .; then
            if grep -q "### Diff Content" "$LATEST" 2>/dev/null; then
                pass "Diff content captured"
            else
                warn "Diff content not captured (may be clean repo)"
            fi
        else
            skip "Diff content test (clean repo)"
        fi
    else
        fail "Snapshot file not created"
    fi

    # Check systemMessage content
    if echo "$SNAP_OUTPUT" | grep -q "CONTEXT GUARD:" 2>/dev/null; then
        pass "systemMessage contains recovery info"
    else
        warn "systemMessage format unexpected"
    fi
else
    fail "PreCompact hook failed: $SNAP_OUTPUT"
fi

# ─── 6. Post-Hook Recovery ───────────────────────────────────

echo ""
echo -e "${CYAN}6. Post-Hook Recovery${NC}"

POST_OUTPUT=$(bash "$HOOKS_DIR/compact-guard-post.sh" 2>/dev/null || echo "")
if [ -n "$POST_OUTPUT" ]; then
    if echo "$POST_OUTPUT" | grep -q "RECOVERY\|RESUME" 2>/dev/null; then
        pass "Post-hook detects recent snapshot"
    else
        warn "Post-hook output unexpected: $(echo "$POST_OUTPUT" | head -1)"
    fi
else
    pass "Post-hook: no recovery needed (expected for fresh test)"
fi

# ─── 7. Plugin Structure ─────────────────────────────────────

echo ""
echo -e "${CYAN}7. Plugin Structure${NC}"

# Check plugin manifest
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_JSON="$SCRIPT_DIR/.claude-plugin/plugin.json"
HOOKS_JSON="$SCRIPT_DIR/.claude-plugin/hooks/hooks.json"
MARKETPLACE_JSON="$SCRIPT_DIR/.claude-plugin/marketplace.json"

if [ -f "$PLUGIN_JSON" ]; then
    pass "plugin.json exists"
    if command -v jq &>/dev/null && jq empty "$PLUGIN_JSON" 2>/dev/null; then
        pass "plugin.json is valid JSON"
        VERSION=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null)
        pass "Plugin version: $VERSION"
    fi
else
    warn "plugin.json not found (manual install mode)"
fi

if [ -f "$HOOKS_JSON" ]; then
    pass "hooks.json exists"
    if command -v jq &>/dev/null && jq empty "$HOOKS_JSON" 2>/dev/null; then
        pass "hooks.json is valid JSON"
        HOOK_COUNT=$(jq '.hooks | keys | length' "$HOOKS_JSON" 2>/dev/null)
        pass "Hook events: $HOOK_COUNT (PreCompact, Stop)"
    fi
else
    warn "hooks.json not found"
fi

if [ -f "$MARKETPLACE_JSON" ]; then
    pass "marketplace.json exists"
else
    warn "marketplace.json not found"
fi

# Check skills in plugin format
SKILL_COUNT=0
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    [ -f "$skill_dir/SKILL.md" ] && SKILL_COUNT=$((SKILL_COUNT + 1))
done
if [ "$SKILL_COUNT" -gt 0 ]; then
    pass "Skills in plugin format: $SKILL_COUNT"
else
    warn "No skills in plugin format"
fi

# Check agent format
if [ -f "$SCRIPT_DIR/agents/context-keeper.md" ]; then
    if head -1 "$SCRIPT_DIR/agents/context-keeper.md" | grep -q "^---" 2>/dev/null; then
        pass "Agent has YAML frontmatter"
    else
        warn "Agent missing YAML frontmatter"
    fi
fi

# ─── 8. Plugin Compatibility ─────────────────────────────────

echo ""
echo -e "${CYAN}8. Plugin Compatibility${NC}"

# Check context-mode
if grep -q "context-mode" "$SETTINGS" 2>/dev/null; then
    pass "context-mode plugin detected"
    if grep -q "pretooluse.mjs" "$SETTINGS" 2>/dev/null; then
        pass "context-mode hooks configured"
    else
        warn "context-mode hooks may need configuration"
    fi
else
    skip "context-mode not installed"
fi

# Check hookify
if grep -q "hookify" "$SETTINGS" 2>/dev/null; then
    pass "hookify plugin detected"
else
    skip "hookify not installed"
fi

# ─── 9. Cross-Platform ───────────────────────────────────────

echo ""
echo -e "${CYAN}9. Cross-Platform${NC}"

# Verify stat command works
TMPFILE=$(mktemp)
echo "test" > "$TMPFILE"
AGE_RESULT=$(stat -c %Y "$TMPFILE" 2>/dev/null || stat -f %m "$TMPFILE" 2>/dev/null || echo "FAIL")
rm -f "$TMPFILE"

if [ "$AGE_RESULT" != "FAIL" ]; then
    pass "stat command compatible"
else
    fail "stat command not working"
fi

# Verify date works
if date '+%Y%m%d-%H%M%S' &>/dev/null; then
    pass "date format compatible"
else
    fail "date format not working"
fi

# Platform detection
(
    source "$HOOKS_DIR/compact-guard-lib.sh" 2>/dev/null
    PLAT=$(cg_platform)
    echo "$PLAT"
) | while read -r plat; do
    pass "Platform: $plat"
done

# ─── 10. Annotation Layer ────────────────────────────────────

echo ""
echo -e "${CYAN}10. Annotation Layer${NC}"

ANNOT_DIR="$HOME/.claude/annotations"
if [ -d "$ANNOT_DIR" ]; then
    pass "Annotations directory exists: $ANNOT_DIR"
else
    warn "Annotations directory missing (run install.sh to create)"
fi

# Test annotation write/read in a temp location
ANNOT_TMP=$(mktemp -d)
TEST_ANNOT_FILE="$ANNOT_TMP/test-topic.md"
printf '# Annotations: test-topic\n' > "$TEST_ANNOT_FILE"
DATE=$(date +%Y-%m-%d)
printf '\n## %s\n' "$DATE" >> "$TEST_ANNOT_FILE"
printf -- '- test annotation entry\n' >> "$TEST_ANNOT_FILE"

if [ -f "$TEST_ANNOT_FILE" ] && grep -q "test annotation entry" "$TEST_ANNOT_FILE" 2>/dev/null; then
    pass "Annotation write/read works"
else
    fail "Annotation write/read failed"
fi

# Verify format
if grep -q "^## $DATE" "$TEST_ANNOT_FILE" 2>/dev/null; then
    pass "Annotation date format correct"
else
    fail "Annotation date format incorrect"
fi

rm -rf "$ANNOT_TMP"

# Check COMPACT_GUARD_ANNOT_DIR constant
if (
    source "$HOOKS_DIR/compact-guard-lib.sh" 2>/dev/null
    [ -n "$COMPACT_GUARD_ANNOT_DIR" ] || exit 1
    exit 0
); then
    pass "COMPACT_GUARD_ANNOT_DIR constant defined"
else
    fail "COMPACT_GUARD_ANNOT_DIR missing from lib"
fi

# ─── Summary ─────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
TOTAL=$((PASS + FAIL + WARN))
echo -e "${BOLD}Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC} (${TOTAL} total)"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo -e "${RED}Some tests failed. Run the installer to fix:${NC}"
    echo "  bash install.sh"
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo -e "${YELLOW}All tests passed with warnings.${NC}"
    exit 0
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
