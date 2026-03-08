#!/usr/bin/env bash
# Claude Compact Guard — Uninstaller
set -euo pipefail

echo "Claude Compact Guard — Uninstaller"
echo ""

HOOKS_DST="$HOME/.claude/hooks"
GUARD_DIR="$HOME/.claude/compact-guard"

for file in compact-guard-lib.sh compact-guard-pre.sh compact-guard-post.sh; do
    if [ -f "$HOOKS_DST/$file" ]; then
        rm -f "$HOOKS_DST/$file"
        echo "Removed $HOOKS_DST/$file"
    fi
    # Restore backup if exists
    if [ -f "$HOOKS_DST/${file}.bak" ]; then
        mv "$HOOKS_DST/${file}.bak" "$HOOKS_DST/$file"
        echo "Restored backup: $file"
    fi
done

echo ""
echo "Manual steps:"
echo "  1. Remove PreCompact hook from settings.json"
echo "  2. Remove CLAUDE_AUTOCOMPACT_PCT_OVERRIDE from settings.json env"
echo "  3. Remove compact-guard-post.sh call from session-start.sh"
echo "  4. Optionally delete snapshots: rm -rf $GUARD_DIR"
echo ""
echo "Done."
