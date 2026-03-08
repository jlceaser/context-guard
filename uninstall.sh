#!/usr/bin/env bash
# Claude Compact Guard — Uninstaller v2.0
set -euo pipefail

echo "Claude Compact Guard — Uninstaller"
echo ""

HOOKS_DST="$HOME/.claude/hooks"
SKILLS_DST="$HOME/.claude/skills"
AGENTS_DST="$HOME/.claude/agents"
GUARD_DIR="$HOME/.claude/compact-guard"

# Remove hooks
echo "Hooks:"
for file in compact-guard-lib.sh compact-guard-pre.sh compact-guard-post.sh compact-guard-stop.sh; do
    if [ -f "$HOOKS_DST/$file" ]; then
        rm -f "$HOOKS_DST/$file"
        echo "  Removed $file"
    fi
    if [ -f "$HOOKS_DST/${file}.bak" ]; then
        mv "$HOOKS_DST/${file}.bak" "$HOOKS_DST/$file"
        echo "  Restored backup: $file"
    fi
done

# Remove skills
echo ""
echo "Skills:"
for file in cg-snapshot.md cg-restore.md cg-context-status.md; do
    if [ -f "$SKILLS_DST/$file" ]; then
        rm -f "$SKILLS_DST/$file"
        echo "  Removed $file"
    fi
done

# Remove agent
echo ""
echo "Agent:"
if [ -f "$AGENTS_DST/context-keeper.md" ]; then
    rm -f "$AGENTS_DST/context-keeper.md"
    echo "  Removed context-keeper.md"
fi

echo ""
echo "Manual steps:"
echo "  1. Remove PreCompact hook entry from settings.json"
echo "  2. Remove Stop hook entry from settings.json (if added)"
echo "  3. Remove CLAUDE_AUTOCOMPACT_PCT_OVERRIDE from settings.json env"
echo "  4. Remove compact-guard-post.sh call from session-start.sh"
echo "  5. Optionally delete snapshots: rm -rf $GUARD_DIR"
echo ""
echo "Done."
