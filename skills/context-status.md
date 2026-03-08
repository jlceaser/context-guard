Show context health dashboard — snapshots, recovery state, and system status.

## When to Use

Use `/context-status` when:
- Want to see how many snapshots exist and their ages
- Check if the compact guard system is working correctly
- Diagnose context recovery issues

## Steps

Run the following checks:

### 1. Snapshot inventory

```bash
echo "=== Compact Guard Status ==="
echo ""
SNAP_COUNT=$(ls "$HOME/.claude/compact-guard"/snapshot-*.md 2>/dev/null | wc -l | tr -d ' ')
echo "Snapshots: $SNAP_COUNT"
LATEST=$(ls -t "$HOME/.claude/compact-guard"/snapshot-*.md 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    MTIME=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    AGE=$(( NOW - MTIME ))
    echo "Latest: $(basename "$LATEST") (${AGE}s ago)"
fi
if [ -f "$HOME/.claude/compact-guard/session-bookmark.md" ]; then
    BM_MTIME=$(stat -c %Y "$HOME/.claude/compact-guard/session-bookmark.md" 2>/dev/null || echo "0")
    BM_AGE=$(( $(date +%s) - BM_MTIME ))
    echo "Session bookmark: exists (${BM_AGE}s ago)"
else
    echo "Session bookmark: none"
fi
```

### 2. Hook installation check

```bash
echo ""
echo "=== Hook Installation ==="
for f in compact-guard-lib.sh compact-guard-pre.sh compact-guard-post.sh compact-guard-stop.sh; do
    [ -f "$HOME/.claude/hooks/$f" ] && echo "OK: $f" || echo "MISSING: $f"
done
```

### 3. Settings check

```bash
echo ""
echo "=== Settings ==="
grep -q "compact-guard-pre" "$HOME/.claude/settings.json" 2>/dev/null && echo "PreCompact hook: configured" || echo "PreCompact hook: NOT configured"
grep -q "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "$HOME/.claude/settings.json" 2>/dev/null && echo "Autocompact override: configured" || echo "Autocompact override: NOT configured"
```

### 4. Disk usage

```bash
echo ""
echo "=== Disk Usage ==="
du -sh "$HOME/.claude/compact-guard" 2>/dev/null || echo "Dir not found"
```

## Output Format

Report as a table:

| Check | Status | Details |
|-------|--------|---------|
| Snapshots | {count} | Latest: {age} ago |
| Bookmark | {yes/no} | {age} ago |
| PreCompact hook | {installed/missing} | |
| Post hook | {installed/missing} | |
| Stop hook | {installed/missing} | |
| Autocompact | {value}% | |
| Disk usage | {size} | |

Flag any MISSING items and suggest fixes.
