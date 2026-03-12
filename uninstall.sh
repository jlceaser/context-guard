#!/usr/bin/env bash
# Context Guard — Uninstaller v3.0
# Removes hooks, skills, agent, and optionally cleans settings.json
# MIT License — github.com/jlceaser/context-guard

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

echo -e "${BOLD}Context Guard — Uninstaller${NC}"
echo ""

HOOKS_DST="$HOME/.claude/hooks"
SKILLS_DST="$HOME/.claude/skills"
AGENTS_DST="$HOME/.claude/agents"
GUARD_DIR="$HOME/.claude/compact-guard"
SETTINGS="$HOME/.claude/settings.json"

KEEP_SNAPSHOTS=false
SKIP_CONFIG=false

for arg in "$@"; do
    case "$arg" in
        --keep-snapshots) KEEP_SNAPSHOTS=true ;;
        --skip-config)    SKIP_CONFIG=true ;;
        --help|-h)
            echo "Usage: bash uninstall.sh [options]"
            echo ""
            echo "Options:"
            echo "  --keep-snapshots  Keep snapshot files"
            echo "  --skip-config     Skip settings.json cleanup"
            echo "  --help            Show this help"
            exit 0
            ;;
    esac
done

# ─── Remove hooks ────────────────────────────────────────────

echo -e "${CYAN}Hooks${NC}"
for file in compact-guard-lib.sh compact-guard-pre.sh compact-guard-post.sh compact-guard-stop.sh context-security-lib.sh security-pre-tool.sh security-post-tool.sh; do
    if [ -f "$HOOKS_DST/$file" ]; then
        rm -f "$HOOKS_DST/$file"
        echo -e "  ${GREEN}✓${NC} Removed $file"
    fi
    if [ -f "$HOOKS_DST/${file}.bak" ]; then
        mv "$HOOKS_DST/${file}.bak" "$HOOKS_DST/$file"
        echo -e "  ${YELLOW}→${NC} Restored backup: $file"
    fi
done

# ─── Remove skills ───────────────────────────────────────────

echo ""
echo -e "${CYAN}Skills${NC}"
# Plugin format (subdirectory)
for skill in cg-snapshot cg-restore cg-context-status cg-setup cg-budget cg-annotate cg-recall cg-security-status cg-security-config; do
    if [ -d "$SKILLS_DST/$skill" ]; then
        rm -rf "$SKILLS_DST/$skill"
        echo -e "  ${GREEN}✓${NC} Removed $skill/"
    fi
done
# Legacy flat format
for file in cg-snapshot.md cg-restore.md cg-context-status.md; do
    if [ -f "$SKILLS_DST/$file" ]; then
        rm -f "$SKILLS_DST/$file"
        echo -e "  ${GREEN}✓${NC} Removed $file"
    fi
done

# ─── Remove agent ────────────────────────────────────────────

echo ""
echo -e "${CYAN}Agent${NC}"
if [ -f "$AGENTS_DST/context-keeper.md" ]; then
    rm -f "$AGENTS_DST/context-keeper.md"
    echo -e "  ${GREEN}✓${NC} Removed context-keeper.md"
fi

# ─── Clean settings.json ─────────────────────────────────────

echo ""
echo -e "${CYAN}Configuration${NC}"

if [ "$SKIP_CONFIG" = true ]; then
    echo -e "  ${DIM}Skipped (--skip-config)${NC}"
elif command -v jq &>/dev/null; then
    cp "$SETTINGS" "${SETTINGS}.pre-uninstall.bak"

    # Remove PreCompact hook entries containing compact-guard
    TMP=$(mktemp)
    jq '
        if .hooks.PreCompact then
            .hooks.PreCompact = [.hooks.PreCompact[] | select(.hooks | all(.command | test("compact-guard") | not))]
            | if .hooks.PreCompact == [] then del(.hooks.PreCompact) else . end
        else . end
        | if .hooks.PreToolUse then
            .hooks.PreToolUse = [.hooks.PreToolUse[] | select(.hooks | all(.command | test("security-pre-tool") | not))]
            | if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end
        else . end
        | if .hooks.PostToolUse then
            .hooks.PostToolUse = [.hooks.PostToolUse[] | select(.hooks | all(.command | test("security-post-tool") | not))]
            | if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end
        else . end
        | if .hooks.Stop then
            .hooks.Stop = [.hooks.Stop[] | .hooks = [.hooks[] | select(.command | test("compact-guard") | not)] | select(.hooks | length > 0)]
            | if .hooks.Stop == [] then del(.hooks.Stop) else . end
        else . end
        | if .env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE then del(.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE) else . end
    ' "$SETTINGS" > "$TMP" 2>/dev/null && mv "$TMP" "$SETTINGS"
    echo -e "  ${GREEN}✓${NC} Cleaned settings.json"
else
    echo -e "  ${YELLOW}→${NC} jq not found — manual cleanup needed:"
    echo "     1. Remove PreCompact hook entries with 'compact-guard'"
    echo "     2. Remove PreToolUse hook entries with 'security-pre-tool'"
    echo "     3. Remove PostToolUse hook entries with 'security-post-tool'"
    echo "     4. Remove Stop hook entries with 'compact-guard'"
    echo "     5. Remove CLAUDE_AUTOCOMPACT_PCT_OVERRIDE from env"
fi

# ─── Clean snapshots ─────────────────────────────────────────

echo ""
echo -e "${CYAN}Data${NC}"
if [ "$KEEP_SNAPSHOTS" = true ]; then
    echo -e "  ${DIM}Snapshots kept (--keep-snapshots)${NC}"
elif [ -d "$GUARD_DIR" ]; then
    SNAP_COUNT=$(ls "$GUARD_DIR"/snapshot-*.md 2>/dev/null | wc -l | tr -d ' ')
    rm -rf "$GUARD_DIR"
    echo -e "  ${GREEN}✓${NC} Removed $GUARD_DIR ($SNAP_COUNT snapshots)"
else
    echo -e "  ${DIM}No data directory found${NC}"
fi

# ─── Clean security data ─────────────────────────────────

SECURITY_DIR="$HOME/.claude/context-guard/security"
if [ -d "$SECURITY_DIR" ]; then
    echo ""
    echo -e "${CYAN}Security Data${NC}"
    SEC_EVENTS=0
    [ -f "$SECURITY_DIR/security.jsonl" ] && SEC_EVENTS=$(wc -l < "$SECURITY_DIR/security.jsonl" 2>/dev/null | tr -d ' ')
    rm -rf "$SECURITY_DIR"
    echo -e "  ${GREEN}✓${NC} Removed $SECURITY_DIR ($SEC_EVENTS events)"
fi

# ─── Clean annotations ───────────────────────────────────────

ANNOT_DIR="$HOME/.claude/annotations"
if [ -d "$ANNOT_DIR" ]; then
    echo ""
    echo -e "${CYAN}Annotations${NC}"
    read -r -p "  Keep annotations in $ANNOT_DIR? [Y/n] " KEEP_ANNOT
    KEEP_ANNOT="${KEEP_ANNOT:-Y}"
    if [[ "$KEEP_ANNOT" =~ ^[Nn] ]]; then
        rm -rf "$ANNOT_DIR"
        echo -e "  ${GREEN}✓${NC} Removed $ANNOT_DIR"
    else
        echo -e "  ${DIM}Annotations kept${NC}"
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}Uninstall complete.${NC}"
echo ""
