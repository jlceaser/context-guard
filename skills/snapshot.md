Take a manual context checkpoint — save the current work state on demand.

## When to Use

Use `/snapshot` when:
- You are about to start a complex task and want to save current state
- You want to create a restore point before risky changes
- You are nearing context limits and want to preserve state proactively

## Steps

1. Run the compact-guard-pre.sh hook manually to capture current state:

```bash
echo '{"trigger":"manual_snapshot"}' | bash "$HOME/.claude/hooks/compact-guard-pre.sh" 2>/dev/null
```

2. Read the snapshot that was just created:

```bash
cat "$HOME/.claude/compact-guard/latest.md"
```

3. Report to the user:
   - Confirm snapshot was saved
   - Show key stats: project, branch, uncommitted files, build state
   - Show the snapshot file path

## Output Format

```
Snapshot saved: ~/.claude/compact-guard/snapshot-YYYYMMDD-HHMMSS.md
  Project: {name} | Branch: {branch} | Dirty: {count} | Build: {state}
```
