---
name: cg-context-status
description: |
  Show Context Guard health dashboard — snapshots, recovery state, and system status.
  Trigger: "context status", "guard status", "snapshot status", "context health",
  "check context guard", "/cg-context-status"
---

# Context Guard — Health Dashboard

Show context health dashboard with snapshot inventory, hook installation, and system status.

## Steps

Run these checks:

### 1. Snapshot Inventory

```bash
echo "=== Context Guard Status ==="
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
SESSION=$(cat "$HOME/.claude/compact-guard/.session-counter" 2>/dev/null || echo "?")
echo "Session counter: #$SESSION"
```

### 2. Hook Installation Check

```bash
echo ""
echo "=== Installation ==="
for f in compact-guard-lib.sh compact-guard-pre.sh compact-guard-post.sh compact-guard-stop.sh; do
    [ -f "$HOME/.claude/hooks/$f" ] && echo "OK: $f (manual)" || true
done
grep -q "compact-guard-pre" "$HOME/.claude/settings.json" 2>/dev/null && echo "OK: PreCompact hook configured" || echo "MISSING: PreCompact hook"
grep -q "compact-guard-stop" "$HOME/.claude/settings.json" 2>/dev/null && echo "OK: Stop hook configured" || echo "MISSING: Stop hook"
grep -q "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "$HOME/.claude/settings.json" 2>/dev/null && echo "OK: Autocompact override set" || echo "MISSING: Autocompact override"
```

### 3. Plugin Check

```bash
echo ""
echo "=== Plugin ==="
if [ -f "$HOME/.claude/plugins/installed_plugins.json" ]; then
    grep -q "context-guard" "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null && echo "OK: Installed as plugin" || echo "INFO: Not installed as plugin (manual mode)"
fi
```

### 4. Disk Usage

```bash
echo ""
echo "=== Disk Usage ==="
du -sh "$HOME/.claude/compact-guard" 2>/dev/null || echo "Dir not found"
```

## Output Format

| Check | Status | Details |
|-------|--------|---------|
| Snapshots | {count} | Latest: {age} ago |
| Bookmark | {yes/no} | {age} ago |
| Session | #{n} | |
| PreCompact hook | OK/MISSING | |
| Stop hook | OK/MISSING | |
| Autocompact | {value}% | |
| Plugin | installed/manual | |
| Disk usage | {size} | |

Flag any MISSING items and suggest fixes.
