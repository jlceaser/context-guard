#!/usr/bin/env bash
# Claude Compact Guard — Installer
# Installs hooks and configures Claude Code settings
# MIT License — github.com/jlceaser/claude-compact-guard

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}Claude Compact Guard — Installer${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$HOME/.claude/hooks"
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
echo -e "${GREEN}✓${NC} Created $GUARD_DIR"

# ─── Copy hook scripts ──────────────────────────────────────

for file in compact-guard-lib.sh compact-guard-pre.sh compact-guard-post.sh; do
    if [ -f "$HOOKS_DST/$file" ]; then
        cp "$HOOKS_DST/$file" "$HOOKS_DST/${file}.bak"
        echo -e "${YELLOW}→${NC} Backed up existing $file"
    fi
    cp "$HOOKS_SRC/$file" "$HOOKS_DST/$file"
    chmod +x "$HOOKS_DST/$file"
    echo -e "${GREEN}✓${NC} Installed $file"
done

# ─── Configure settings.json ────────────────────────────────

# Check if PreCompact hook already exists
if grep -q "compact-guard-pre" "$SETTINGS" 2>/dev/null; then
    echo -e "${YELLOW}→${NC} PreCompact hook already configured — skipping"
else
    # Backup settings
    cp "$SETTINGS" "${SETTINGS}.bak"
    echo -e "${GREEN}✓${NC} Backed up settings.json"

    echo ""
    echo -e "${YELLOW}Manual configuration needed:${NC}"
    echo ""
    echo "Add this to your settings.json under \"hooks\":"
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
    echo "And add this to your \"env\" section:"
    echo ""
    cat <<'ENV_CONFIG'
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"
ENV_CONFIG
    echo ""
    echo "For post-compaction recovery, add this to your session-start.sh:"
    echo ""
    cat <<'SESSION_CONFIG'
# Compact Guard — post-compaction recovery
COMPACT_RECOVERY=$("$HOME/.claude/hooks/compact-guard-post.sh" 2>/dev/null || true)
if [ -n "$COMPACT_RECOVERY" ]; then
    CTX="$CTX | $COMPACT_RECOVERY"
fi
SESSION_CONFIG
fi

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "How it works:"
echo "  1. Auto-compact triggers at 80% (instead of 95%)"
echo "  2. PreCompact hook saves structured snapshot to ~/.claude/compact-guard/"
echo "  3. After compaction, session-start detects and injects recovery context"
echo "  4. Claude reads the snapshot file to restore full work state"
echo ""
echo "Snapshots: $GUARD_DIR"
echo "Max kept:  $COMPACT_GUARD_MAX_SNAPSHOTS (configurable via COMPACT_GUARD_MAX_SNAPSHOTS)"
echo ""
