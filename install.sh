#!/usr/bin/env bash
# Context Guard — Installer v3.0
# Auto-configures hooks, skills, agent, and settings.json
# MIT License — github.com/jlceaser/context-guard

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

VERSION="0.4.1"

echo -e "${BOLD}Context Guard v${VERSION} — Installer${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_SRC="$SCRIPT_DIR/hooks"
SKILLS_SRC="$SCRIPT_DIR/skills"
AGENTS_SRC="$SCRIPT_DIR/agents"
HOOKS_DST="$HOME/.claude/hooks"
SKILLS_DST="$HOME/.claude/skills"
AGENTS_DST="$HOME/.claude/agents"
GUARD_DIR="$HOME/.claude/compact-guard"
SETTINGS="$HOME/.claude/settings.json"

# ─── Flags ────────────────────────────────────────────────────

SKIP_CONFIG=false
FORCE=false

for arg in "$@"; do
    case "$arg" in
        --skip-config) SKIP_CONFIG=true ;;
        --force)       FORCE=true ;;
        --help|-h)
            echo "Usage: bash install.sh [options]"
            echo ""
            echo "Options:"
            echo "  --skip-config  Skip auto-configuration of settings.json"
            echo "  --force        Overwrite existing files without backup"
            echo "  --help         Show this help"
            exit 0
            ;;
    esac
done

# ─── Preflight checks ───────────────────────────────────────

if [ ! -d "$HOME/.claude" ]; then
    echo -e "${RED}Error: ~/.claude not found. Is Claude Code installed?${NC}"
    exit 1
fi

if [ ! -f "$SETTINGS" ]; then
    echo -e "${RED}Error: settings.json not found at $SETTINGS${NC}"
    exit 1
fi

HAS_JQ=false
if command -v jq &>/dev/null; then
    HAS_JQ=true
fi

# ─── Create directories ─────────────────────────────────────

mkdir -p "$HOOKS_DST"
mkdir -p "$GUARD_DIR"
mkdir -p "$SKILLS_DST" 2>/dev/null || true
mkdir -p "$AGENTS_DST" 2>/dev/null || true

# Create annotations directory
ANNOT_DIR="$HOME/.claude/annotations"
mkdir -p "$ANNOT_DIR"
echo -e "  ${GREEN}✓${NC} Created: $ANNOT_DIR"

echo -e "${GREEN}✓${NC} Directories ready"

# ─── Install hooks ───────────────────────────────────────────

echo ""
echo -e "${CYAN}Hooks${NC}"
for file in compact-guard-lib.sh compact-guard-pre.sh compact-guard-post.sh compact-guard-stop.sh; do
    if [ ! -f "$HOOKS_SRC/$file" ]; then
        continue
    fi
    if [ -f "$HOOKS_DST/$file" ] && [ "$FORCE" != true ]; then
        cp "$HOOKS_DST/$file" "$HOOKS_DST/${file}.bak"
        echo -e "  ${YELLOW}→${NC} Backed up existing $file"
    fi
    cp "$HOOKS_SRC/$file" "$HOOKS_DST/$file"
    chmod +x "$HOOKS_DST/$file"
    echo -e "  ${GREEN}✓${NC} $file"
done

# ─── Install skills ──────────────────────────────────────────

if [ -d "$SKILLS_SRC" ]; then
    echo ""
    echo -e "${CYAN}Skills${NC}"
    # Plugin format: skills/skill-name/SKILL.md
    for skill_dir in "$SKILLS_SRC"/*/; do
        [ ! -d "$skill_dir" ] && continue
        SKILL_NAME=$(basename "$skill_dir")
        if [ -f "$skill_dir/SKILL.md" ]; then
            mkdir -p "$SKILLS_DST/$SKILL_NAME"
            cp "$skill_dir/SKILL.md" "$SKILLS_DST/$SKILL_NAME/SKILL.md"
            echo -e "  ${GREEN}✓${NC} /$SKILL_NAME"
        fi
    done
    # Legacy format: skills/*.md (fallback)
    for file in "$SKILLS_SRC"/*.md; do
        [ ! -f "$file" ] && continue
        BASENAME=$(basename "$file")
        SKILL_NAME="${BASENAME%.md}"
        cp "$file" "$SKILLS_DST/cg-${BASENAME}"
        echo -e "  ${GREEN}✓${NC} /cg-${SKILL_NAME} (legacy)"
    done
fi

# ─── Install agent ───────────────────────────────────────────

if [ -d "$AGENTS_SRC" ]; then
    echo ""
    echo -e "${CYAN}Agent${NC}"
    for file in "$AGENTS_SRC"/*.md; do
        [ ! -f "$file" ] && continue
        BASENAME=$(basename "$file")
        cp "$file" "$AGENTS_DST/$BASENAME"
        echo -e "  ${GREEN}✓${NC} ${BASENAME%.md}"
    done
fi

# ─── Auto-configure settings.json ────────────────────────────

echo ""
echo -e "${CYAN}Configuration${NC}"

if [ "$SKIP_CONFIG" = true ]; then
    echo -e "  ${DIM}Skipped (--skip-config)${NC}"
elif [ "$HAS_JQ" != true ]; then
    echo -e "  ${YELLOW}→${NC} jq not found — showing manual configuration"
    echo ""
    echo -e "  ${YELLOW}Add these to your settings.json:${NC}"
    echo ""
    echo "  1. Under \"hooks\", add PreCompact:"
    echo '     "PreCompact": [{"matcher":"","hooks":[{"type":"command","command":"bash \"$HOME/.claude/hooks/compact-guard-pre.sh\"","statusMessage":"Saving work state..."}]}]'
    echo ""
    echo "  2. Under \"hooks\", add/extend Stop:"
    echo '     {"type":"command","command":"bash \"$HOME/.claude/hooks/compact-guard-stop.sh\"","statusMessage":"Saving session bookmark..."}'
    echo ""
    echo "  3. Under \"env\", add:"
    echo '     "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"'
else
    # ── Backup settings.json ──
    cp "$SETTINGS" "${SETTINGS}.pre-context-guard.bak"
    echo -e "  ${GREEN}✓${NC} Backed up settings.json"

    CHANGED=false

    # ── Add CLAUDE_AUTOCOMPACT_PCT_OVERRIDE ──
    if ! grep -q "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "$SETTINGS" 2>/dev/null; then
        TMP=$(mktemp)
        jq '.env["CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"] = "80"' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
        echo -e "  ${GREEN}✓${NC} Set CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80"
        CHANGED=true
    else
        echo -e "  ${DIM}→ CLAUDE_AUTOCOMPACT_PCT_OVERRIDE already set${NC}"
    fi

    # ── Add PreCompact hook ──
    if ! grep -q "compact-guard-pre" "$SETTINGS" 2>/dev/null; then
        TMP=$(mktemp)
        HOOK_OBJ='[{"matcher":"","hooks":[{"type":"command","command":"bash \"$HOME/.claude/hooks/compact-guard-pre.sh\"","statusMessage":"Saving work state..."}]}]'
        jq --argjson hook "$HOOK_OBJ" '
            .hooks = (.hooks // {}) |
            if .hooks.PreCompact then
                .hooks.PreCompact += $hook
            else
                .hooks.PreCompact = $hook
            end
        ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
        echo -e "  ${GREEN}✓${NC} Added PreCompact hook"
        CHANGED=true
    else
        echo -e "  ${DIM}→ PreCompact hook already configured${NC}"
    fi

    # ── Add Stop hook ──
    if ! grep -q "compact-guard-stop" "$SETTINGS" 2>/dev/null; then
        TMP=$(mktemp)
        STOP_HOOK='{"type":"command","command":"bash \"$HOME/.claude/hooks/compact-guard-stop.sh\"","statusMessage":"Saving session bookmark..."}'
        jq --argjson hook "$STOP_HOOK" '
            .hooks = (.hooks // {}) |
            if .hooks.Stop then
                .hooks.Stop[-1].hooks += [$hook]
            else
                .hooks.Stop = [{"matcher":"","hooks":[$hook]}]
            end
        ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
        echo -e "  ${GREEN}✓${NC} Added Stop hook"
        CHANGED=true
    else
        echo -e "  ${DIM}→ Stop hook already configured${NC}"
    fi

    if [ "$CHANGED" = false ]; then
        echo -e "  ${DIM}→ All settings already configured${NC}"
    fi
fi

# ─── Initialize session counter ──────────────────────────────

if [ ! -f "$GUARD_DIR/.session-counter" ]; then
    echo "1" > "$GUARD_DIR/.session-counter"
    echo -e "  ${GREEN}✓${NC} Initialized session counter"
fi

# ─── CLAUDE.md integration hint ──────────────────────────────

echo ""
echo -e "${CYAN}Optional: CLAUDE.md${NC}"
if [ -f "$SCRIPT_DIR/templates/CLAUDE.md.template" ]; then
    echo -e "  Add auto-recovery instructions to your CLAUDE.md:"
    echo -e "  ${DIM}cat $SCRIPT_DIR/templates/CLAUDE.md.template >> ~/.claude/CLAUDE.md${NC}"
fi

# ─── Summary ─────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "Components:"
echo "  Hooks:  compact-guard-{lib,pre,post,stop}.sh"
echo "  Skills: /cg-snapshot, /cg-restore, /cg-context-status, /cg-annotate, /cg-recall"
echo "  Agent:  context-keeper"
echo ""
echo "How it works:"
echo "  1. Auto-compact triggers at 80% context (instead of 95%)"
echo "  2. PreCompact hook saves structured snapshot with diffs"
echo "  3. Stop hook saves session bookmark for next session"
echo "  4. SessionStart detects recent snapshot and injects recovery"
echo "  5. Claude reads snapshot to restore full work state"
echo "  6. Use /cg-snapshot for manual checkpoints anytime"
echo ""
echo "Verify installation:"
echo "  bash $SCRIPT_DIR/test.sh"
echo ""
echo "Snapshots: $GUARD_DIR"
echo "Skills:    /cg-snapshot  /cg-restore  /cg-context-status  /cg-annotate  /cg-recall"
echo "Annotations: $ANNOT_DIR"
echo ""
