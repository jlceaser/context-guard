---
name: cg-snapshot
description: |
  Take a manual context checkpoint — save the current work state on demand.
  Trigger: "save state", "create checkpoint", "snapshot context", "preserve state",
  "manual snapshot", "/cg-snapshot"
---

# Context Guard — Manual Snapshot

Take a manual context checkpoint to preserve the current work state.

## When to Use

- Before starting a complex task (save current state as restore point)
- Before risky changes (rollback point)
- When nearing context limits (proactive preservation)
- Before a long debugging session

## Steps

1. Run the Context Guard pre-hook manually:

```bash
echo '{"trigger":"manual_snapshot"}' | bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/hooks}/../hooks/compact-guard-pre.sh" 2>/dev/null || echo '{"trigger":"manual_snapshot"}' | bash "$HOME/.claude/hooks/compact-guard-pre.sh" 2>/dev/null
```

2. Read the snapshot that was just created:

```bash
cat "$HOME/.claude/compact-guard/latest.md"
```

3. Report to the user:
   - Confirm snapshot was saved
   - Show key stats: project, branch, uncommitted files, build state
   - Show the snapshot file path
   - Note the session number

## Output Format

```
Snapshot saved: ~/.claude/compact-guard/snapshot-YYYYMMDD-HHMMSS.md
  Project: {name} | Branch: {branch} | Dirty: {count} | Build: {state} | Session: #{n}
```
