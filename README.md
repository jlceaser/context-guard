# Claude Compact Guard

**Never lose context again.** A comprehensive context continuity system for Claude Code.

When Claude Code compacts your conversation (at ~95% context usage), it compresses your entire chat history into a summary. This loses critical details: which files you were editing, what you were debugging, your build state, uncommitted changes, and the overall "where we were."

Compact Guard is not just a hook — it is a **multi-layered context preservation system**: hooks capture state, skills give manual control, an agent handles intelligent recovery, and worktree awareness preserves parallel work.

## The Problem

```
You: "Fix the authentication bug in user-service.ts"
Claude: *edits 3 files, runs tests, debugging a failing case*
--- AUTO-COMPACT TRIGGERS ---
Claude: "I see we're working on a project. How can I help?"
```

## Architecture

```
                    ┌─────────────────────────────┐
                    │      Claude Code Session      │
                    └──────────────┬──────────────┘
                                   │
            ┌──────────────────────┼──────────────────────┐
            │                      │                      │
            ▼                      ▼                      ▼
    ┌───────────────┐    ┌─────────────────┐    ┌─────────────────┐
    │   4 Hooks      │    │   3 Skills       │    │   1 Agent       │
    │                │    │                  │    │                 │
    │ PreCompact     │    │ /cg-snapshot     │    │ context-keeper  │
    │   → snapshot   │    │   manual save    │    │   intelligent   │
    │                │    │                  │    │   recovery &    │
    │ SessionStart   │    │ /cg-restore      │    │   analysis      │
    │   → recovery   │    │   manual load    │    │                 │
    │                │    │                  │    │                 │
    │ Stop           │    │ /cg-context-     │    │                 │
    │   → bookmark   │    │   status         │    │                 │
    │                │    │   health check   │    │                 │
    │ (lib: shared)  │    │                  │    │                 │
    └───────┬───────┘    └────────┬─────────┘    └────────┬────────┘
            │                     │                       │
            └─────────────────────┼───────────────────────┘
                                  │
                    ┌─────────────▼──────────────┐
                    │  ~/.claude/compact-guard/   │
                    │                             │
                    │  snapshot-*.md   (auto)     │
                    │  session-bookmark.md        │
                    │  latest.md      (pointer)   │
                    └─────────────────────────────┘
```

## Components

### Hooks (automatic)

| Hook | Event | What It Does |
|------|-------|-------------|
| `compact-guard-pre.sh` | PreCompact | Captures 5-section snapshot + injects systemMessage |
| `compact-guard-post.sh` | SessionStart | Detects recent snapshot, injects recovery context |
| `compact-guard-stop.sh` | Stop | Saves session bookmark for next session continuity |
| `compact-guard-lib.sh` | (shared) | Git, worktree, domain, snapshot, JSON functions |

### Skills (manual control)

| Skill | Usage | Purpose |
|-------|-------|---------|
| `/cg-snapshot` | Before risky changes | Manual checkpoint — save state on demand |
| `/cg-restore` | After context loss | Read and summarize latest snapshot |
| `/cg-context-status` | Anytime | Health dashboard — snapshots, hooks, settings |

### Agent

| Agent | Purpose |
|-------|---------|
| `context-keeper` | Intelligent recovery — reads snapshot, cross-references git, produces structured briefing |

### Rules (hookify-compatible)

| Rule | Action | Purpose |
|------|--------|---------|
| `protect-snapshots` | block | Prevent accidental snapshot edits |
| `protect-compact-guard-hooks` | block | Edit source, not installed hooks |

## What Gets Captured

### 1. Git State
- Branch, last commit, modified/staged/untracked files
- Diff statistics (lines added/removed per file)
- Recent commits (last 8) and active branches
- **Domain classification** — changes sorted by domain (core, ui, build, ci, docs, scripts, test, config)

### 2. Disk State (beyond git)
- Recently modified files via `find` (not just git-tracked)
- Build directory status and artifact ages
- Project disk usage

### 3. Worktrees
- Active worktree list with branches
- Per-worktree dirty state (uncommitted files in each worktree)
- Worktree detection (`.git` file vs directory)

### 4. Environment
- Platform, shell, key environment variables
- Git stashes (forgotten work detection)
- Virtual environment status

### 5. Claude Ecosystem
- Recently updated auto-memory files
- Previous session bookmark availability

## Installation

### Quick Install

```bash
git clone https://github.com/jlceaser/claude-compact-guard.git
cd claude-compact-guard
bash install.sh
```

This installs:
- 4 hook scripts to `~/.claude/hooks/`
- 3 skills to `~/.claude/skills/`
- 1 agent to `~/.claude/agents/`
- Creates `~/.claude/compact-guard/` for snapshots

### Manual Setup

**1. Copy hooks:**

```bash
cp hooks/compact-guard-*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/compact-guard-*.sh
```

**2. Add hooks to `~/.claude/settings.json`:**

```json
{
  "hooks": {
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
    ],
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
  }
}
```

**3. Lower the compaction threshold** (recommended):

```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"
  }
}
```

**4. Add post-compaction recovery to your SessionStart hook:**

```bash
# In your session-start.sh
COMPACT_RECOVERY=$("$HOME/.claude/hooks/compact-guard-post.sh" 2>/dev/null || true)
if [ -n "$COMPACT_RECOVERY" ]; then
    CTX="$CTX | $COMPACT_RECOVERY"
fi
```

**5. Install skills and agent (optional):**

```bash
cp skills/*.md ~/.claude/skills/
cp agents/*.md ~/.claude/agents/
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPACT_GUARD_DIR` | `~/.claude/compact-guard` | Snapshot storage directory |
| `COMPACT_GUARD_MAX_SNAPSHOTS` | `10` | Max snapshots to keep |
| `COMPACT_GUARD_MAX_AGE` | `900` (15 min) | Max age for recovery detection |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `95` (Claude default) | Context % to trigger compaction |

## Domain Classification

Changes are classified for quick context:

| Domain | Patterns |
|--------|----------|
| `core` | `core/*`, `*/core/*` |
| `src` | `src/*`, `*/src/*` |
| `ui` | `qml/*`, `*.qml`, `ui/*`, `components/*` |
| `build` | `CMake*`, `justfile`, `Makefile`, `*.cmake` |
| `ci` | `.github/*`, `.gitlab-ci*` |
| `docs` | `docs/*`, `*.md`, `CHANGELOG*` |
| `scripts` | `scripts/*`, `*.py`, `*.sh` |
| `test` | `test*/*`, `*_test.*`, `*_spec.*` |
| `config` | `*.json`, `*.yaml`, `*.yml`, `*.toml` |
| `infra` | `hooks/*`, `skills/*`, `agents/*`, `rules/*` |

Extend `cg_classify_file()` in `compact-guard-lib.sh` for your project structure.

## How It Compares

| Feature | No Protection | Git-only | **Compact Guard** |
|---------|:---:|:---:|:---:|
| Branch & commit state | - | Yes | Yes |
| Modified file list | - | Yes | Yes |
| Domain classification | - | - | Yes |
| Disk-level file changes | - | - | Yes |
| Build artifact state | - | - | Yes |
| Worktree awareness | - | - | Yes |
| Environment snapshot | - | - | Yes |
| Session bookmarks | - | - | Yes |
| Manual checkpoints (skills) | - | - | Yes |
| Intelligent recovery (agent) | - | - | Yes |
| Hookify rules | - | - | Yes |
| systemMessage injection | - | - | Yes |
| Auto-cleanup | - | - | Yes |
| Zero dependencies | - | Varies | Yes |

## Uninstalling

```bash
bash uninstall.sh
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with hooks support
- Bash (Linux, macOS, Windows Git Bash / MSYS2)
- Git (for git state capture — gracefully degrades without it)

## Philosophy

Context compaction is inevitable. Rather than fighting it, Compact Guard embraces it:

1. **Capture everything** — git + disk + worktrees + environment + Claude ecosystem
2. **Multi-layer defense** — hooks (auto) + skills (manual) + agent (intelligent)
3. **Inject into the summary** — systemMessage survives compaction
4. **Auto-recover** — SessionStart detects and tells Claude to read the snapshot
5. **Session continuity** — Stop hook bookmarks for next-session awareness
6. **Zero dependencies** — pure bash, works everywhere Claude Code runs

The result: compaction becomes a **minor hiccup** instead of a **full reset**.

## License

MIT License — see [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome. The project is intentionally minimal (pure bash, no dependencies).

---

Built with frustration and determination by [@jlceaser](https://github.com/jlceaser).
