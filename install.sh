#!/usr/bin/env bash
# Claude Compact Guard — Installer v2.0
# Installs hooks, skills, agent, and configures Claude Code settings
# MIT License — github.com/jlceaser/claude-compact-guard

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BOLD}Claude Compact Guard v2.0 — Installer${NC}"
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

# ─── Preflight checks ───────────────────────────────────────

if [ ! -d "$HOME/.claude" ]; then
    echo -e "${RED}Error: ~/.claude not found. Is Claude Code installed?${NC}"
    exit 1
fi

if [ ! -f "$SETTINGS" ]; then
    echo -e "${RED}Error: settings.json not found at $SETTINGS${NC}"
    exit 1
fi

# ─── Create directories ─────────────────────────────────────

mkdir -p "$HOOKS_DST"
mkdir -p "$GUARD_DIR"
mkdir -p "$SKILLS_DST" 2>/dev/null || true
mkdir -p "$AGENTS_DST" 2>/dev/null || true
echo -e "${GREEN}✓${NC} Directories ready"

# ─── Install hooks ───────────────────────────────────────────

echo ""
echo -e "${CYAN}Hooks${NC}"
for file in compact-guard-lib.sh compact-guard-pre.sh compact-guard-post.sh compact-guard-stop.sh; do
    if [ ! -f "$HOOKS_SRC/$file" ]; then
        continue
    fi
    if [ -f "$HOOKS_DST/$file" ]; then
        cp "$HOOKS_DST/$file" "$HOOKS_DST/${file}.bak"
        echo -e "  ${YELLOW}→${NC} Backed up existing $file"
    fi
    cp "$HOOKS_SRC/$file" "$HOOKS_DST/$file"
    chmod +x "$HOOKS_DST/$file"
    echo -e "  ${GREEN}✓${NC} $file"
done

# ─── Install skills (optional) ──────────────────────────────

if [ -d "$SKILLS_SRC" ]; then
    echo ""
    echo -e "${CYAN}Skills${NC}"
    for file in "$SKILLS_SRC"/*.md; do
        [ ! -f "$file" ] && continue
        BASENAME=$(basename "$file")
        SKILL_NAME="${BASENAME%.md}"
        # Prefix with cg- to avoid conflicts
        cp "$file" "$SKILLS_DST/cg-${BASENAME}"
        echo -e "  ${GREEN}✓${NC} /cg-${SKILL_NAME}"
    done
fi

# ─── Install agent (optional) ────────────────────────────────

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

# ─── Configure settings.json ────────────────────────────────

echo ""
echo -e "${CYAN}Configuration${NC}"

if grep -q "compact-guard-pre" "$SETTINGS" 2>/dev/null; then
    echo -e "  ${YELLOW}→${NC} PreCompact hook already configured"
else
    cp "$SETTINGS" "${SETTINGS}.bak"
    echo -e "  ${GREEN}✓${NC} Backed up settings.json"

    echo ""
    echo -e "${YELLOW}Manual configuration needed:${NC}"
    echo ""
    echo "1. Add to settings.json under \"hooks\":"
    echo ""
    cat <<'HOOK_CONFIG'
"PreCompact": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": "bash \"$HOME/.claude/hooks/compact-guard-pre.sh\"",
        "statusMessage": "Saving work state..."
      }
    ]
  }
]
HOOK_CONFIG
    echo ""
    echo "2. (Optional) Add Stop hook for session bookmarks:"
    echo ""
    cat <<'STOP_CONFIG'
"Stop": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": "bash \"$HOME/.claude/hooks/compact-guard-stop.sh\"",
        "statusMessage": "Saving session bookmark..."
      }
    ]
  }
]
STOP_CONFIG
    echo ""
    echo "3. Add to \"env\" section:"
    echo ""
    cat <<'ENV_CONFIG'
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"
ENV_CONFIG
    echo ""
    echo "4. Add to your session-start.sh for post-compaction recovery:"
    echo ""
    cat <<'SESSION_CONFIG'
# Compact Guard — post-compaction recovery
COMPACT_RECOVERY=$("$HOME/.claude/hooks/compact-guard-post.sh" 2>/dev/null || true)
if [ -n "$COMPACT_RECOVERY" ]; then
    CTX="$CTX | $COMPACT_RECOVERY"
fi
SESSION_CONFIG
fi

# ─── Summary ─────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "Components installed:"
echo "  Hooks:  compact-guard-{lib,pre,post,stop}.sh"
echo "  Skills: /cg-snapshot, /cg-restore, /cg-context-status"
echo "  Agent:  context-keeper"
echo ""
echo "How it works:"
echo "  1. Auto-compact triggers at 80% context (instead of 95%)"
echo "  2. PreCompact hook saves structured snapshot with full state"
echo "  3. Stop hook saves session bookmark for next session"
echo "  4. SessionStart detects recent snapshot and injects recovery"
echo "  5. Claude reads snapshot to restore full work state"
echo "  6. Use /cg-snapshot for manual checkpoints anytime"
echo ""
echo "Snapshots: $GUARD_DIR"
echo "Skills:    /cg-snapshot  /cg-restore  /cg-context-status"
echo ""
