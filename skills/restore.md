Manually restore context from the latest compact guard snapshot.

## When to Use

Use `/restore` when:
- After context compaction, if automatic recovery did not trigger
- When starting a new session and want to continue previous work
- When context feels lost and you need to re-orient

## Steps

1. Find the latest snapshot:

```bash
ls -t "$HOME/.claude/compact-guard"/snapshot-*.md 2>/dev/null | head -1
```

2. Check if a session bookmark exists too:

```bash
ls -la "$HOME/.claude/compact-guard/session-bookmark.md" 2>/dev/null
```

3. Read the latest snapshot file using the Read tool. Read the FULL file — every section matters.

4. If a session bookmark exists and is newer than the snapshot, read that too.

5. After reading, summarize to the user:
   - What project/branch was being worked on
   - What files were being modified
   - What the build state was
   - Any uncommitted work or stashes
   - What should be done next (based on the context)

## Important

- Read the ENTIRE snapshot, not just the header
- Pay attention to "Changes by Domain" — it tells you what areas were being worked on
- Check "Untracked Files" — these are often in-progress new features
- Check "Recently Modified Files (disk)" — these may include non-git-tracked work
- If worktrees are listed, note which branches have work in progress
