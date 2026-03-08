# Claude Compact Guard

**Never lose context again.** Comprehensive work state preservation for Claude Code's auto-compaction.

When Claude Code compacts your conversation (at ~95% context usage), it compresses your entire chat history into a summary. This often loses critical details: which files you were editing, what you were debugging, your build state, uncommitted changes, and the overall "where we were."

Compact Guard captures a structured snapshot of your **entire work state** — not just git, but disk, environment, build artifacts, and Claude's own ecosystem — right before compaction happens, and automatically restores it afterward.

## The Problem

```
You: "Fix the authentication bug in user-service.ts"
Claude: *edits 3 files, runs tests, debugging a failing case*
--- AUTO-COMPACT TRIGGERS ---
Claude: "I see we're working on a project. How can I help?"
```

Context compaction is lossy. The compressed summary captures broad strokes but drops:
- Exact files being edited and their modification state
- Build status and recent artifact ages
- Untracked files (potential in-progress work)
- Environment variables affecting the build
- The debugging trail and hypotheses being tested

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│                    Claude Code Session                    │
│                                                          │
│  Context fills up → Auto-compact triggers                │
│       │                                                  │
│       ▼                                                  │
│  ┌──────────────────┐                                    │
│  │  PreCompact Hook  │ ◄── compact-guard-pre.sh          │
│  │  Captures:        │                                   │
│  │  • Git state      │     Writes structured             │
│  │  • Disk state     │──── snapshot to                   │
│  │  • Build health   │     ~/.claude/compact-guard/      │
│  │  • Environment    │                                   │
│  │  • Claude memory  │     Injects systemMessage         │
│  │                   │──── into compaction summary       │
│  └──────────────────┘                                    │
│       │                                                  │
│       ▼                                                  │
│  ┌──────────────────┐                                    │
│  │  Compaction       │ Context compressed to summary     │
│  │  (built-in)       │ systemMessage survives!           │
│  └──────────────────┘                                    │
│       │                                                  │
│       ▼                                                  │
│  ┌──────────────────┐                                    │
│  │  SessionStart     │ ◄── compact-guard-post.sh         │
│  │  Hook             │     (called from session-start)   │
│  │                   │                                   │
│  │  Detects recent   │     Injects snapshot path         │
│  │  snapshot (<15m)  │──── as additionalContext           │
│  │                   │                                   │
│  │  Claude reads     │     Full state restored           │
│  │  snapshot file    │──── from structured markdown      │
│  └──────────────────┘                                    │
│                                                          │
│  Claude: "I see we were debugging the auth bug in        │
│   user-service.ts, with 3 uncommitted files..."          │
└─────────────────────────────────────────────────────────┘
```

## What Gets Captured

### 1. Git State
| Data | Description |
|------|-------------|
| Branch & last commit | Current working branch and HEAD |
| Modified files | All uncommitted changes with status |
| Staged files | Files ready for commit |
| Diff stat | Lines added/removed per file |
| Untracked files | New files not yet in git (in-progress work) |
| Recent commits | Last 8 commits for context |
| Active branches | All local branches (parallel work) |
| Domain breakdown | Changes classified by domain (core, ui, build, etc.) |

### 2. Disk State (beyond git)
| Data | Description |
|------|-------------|
| Recently modified files | Files changed since last commit (via `find`, not git) |
| Build directory | Which build dir exists (dev/debug/release) |
| Build artifacts | Most recent .exe/.dll/.o and their age |
| Project size | Total disk usage |

### 3. Environment
| Data | Description |
|------|-------------|
| Platform & shell | OS and shell info |
| Key env vars | VCPKG_ROOT, CMAKE_PREFIX_PATH, etc. |
| Git stashes | Stashed work that might be forgotten |

### 4. Claude Ecosystem
| Data | Description |
|------|-------------|
| Recent memory files | Auto-memory files updated since last commit |

## Installation

### Quick Install

```bash
git clone https://github.com/jlceaser/claude-compact-guard.git
cd claude-compact-guard
bash install.sh
```

The installer will:
1. Copy hook scripts to `~/.claude/hooks/`
2. Create `~/.claude/compact-guard/` for snapshots
3. Show you what to add to `~/.claude/settings.json`

### Manual Setup

**1. Copy hooks:**

```bash
cp hooks/compact-guard-*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/compact-guard-*.sh
```

**2. Add PreCompact hook to `~/.claude/settings.json`:**

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
    ]
  }
}
```

**3. Lower the compaction threshold** (recommended):

Add to the `"env"` section of your settings:

```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"
  }
}
```

This triggers compaction at 80% instead of 95%, giving more room for the recovery context.

**4. Add post-compaction recovery to your SessionStart hook:**

If you already have a `session-start.sh`, add this:

```bash
# Compact Guard — post-compaction recovery
COMPACT_RECOVERY=$("$HOME/.claude/hooks/compact-guard-post.sh" 2>/dev/null || true)
if [ -n "$COMPACT_RECOVERY" ]; then
    CTX="$CTX | $COMPACT_RECOVERY"
fi
```

## Configuration

All configuration is via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPACT_GUARD_DIR` | `~/.claude/compact-guard` | Snapshot storage directory |
| `COMPACT_GUARD_MAX_SNAPSHOTS` | `10` | Max snapshots to keep |
| `COMPACT_GUARD_MAX_AGE` | `900` (15 min) | Max age (seconds) for recovery detection |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `95` (Claude default) | Context % to trigger compaction |

## Domain Classification

Compact Guard classifies your changes by domain for quick context:

| Domain | Pattern |
|--------|---------|
| `core` | `core/*`, `*/core/*` |
| `ui` | `qml/*`, `*.qml` |
| `ci` | `.github/*`, `.gitlab-ci*` |
| `build` | `CMake*`, `cmake*`, `justfile`, `Makefile`, `*.cmake` |
| `docs` | `docs/*`, `*.md`, `CHANGELOG*` |
| `scripts` | `scripts/*`, `*.py`, `*.sh` |
| `test` | `test*/*`, `*_test.*`, `*_spec.*` |
| `config` | `*.json`, `*.yaml`, `*.yml`, `*.toml` |

This is extensible — modify `cg_classify_file()` in `compact-guard-lib.sh` for your project structure.

## Snapshot Example

After compaction, a snapshot looks like:

```markdown
# Compact Guard Snapshot

> Comprehensive work state captured before context compaction.

## Session Info
| Field | Value |
|-------|-------|
| Time | 2026-03-08 14:32:15 |
| Trigger | auto |
| Working Dir | /c/cedra/MakineAI |

## 1. Git State
| Field | Value |
|-------|-------|
| Project | MakineAI |
| Branch | feat/auth-fix |
| Last Commit | a1b2c3d fix(core): handle empty config |
| Uncommitted | 3 files |

### Changes by Domain
| Domain | Files |
|--------|-------|
| core | 2 |
| ui | 1 |

### Modified Files (git)
core/src/auth_service.cpp
core/include/auth_service.h
qml/screens/LoginScreen.qml

## 2. Disk State
| Field | Value |
|-------|-------|
| Project Size | 1.2G |
| Build Dir | build/dev |
| Build State | exists |
| Last Build | 5min ago |
```

## Uninstalling

```bash
cd claude-compact-guard
bash uninstall.sh
```

Then manually:
1. Remove `PreCompact` hook from `~/.claude/settings.json`
2. Remove `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` from settings env
3. Remove compact-guard-post.sh call from your session-start.sh
4. Optionally delete snapshots: `rm -rf ~/.claude/compact-guard`

## How It Compares

| Feature | No Protection | Git-only Handoff | **Compact Guard** |
|---------|:---:|:---:|:---:|
| Branch & commit state | - | Yes | Yes |
| Modified file list | - | Yes | Yes |
| Diff statistics | - | Partial | Yes |
| Domain classification | - | - | Yes |
| Disk-level file changes | - | - | Yes |
| Build artifact state | - | - | Yes |
| Environment snapshot | - | - | Yes |
| Stash detection | - | - | Yes |
| Memory file tracking | - | - | Yes |
| Auto-cleanup | - | - | Yes |
| Recovery injection | - | - | Yes |
| Zero dependencies | - | Varies | Yes |

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with hooks support
- Bash (Linux, macOS, Windows Git Bash / MSYS2)
- Git (for git state capture — gracefully degrades without it)

## Philosophy

Context compaction is inevitable. Rather than fighting it, Compact Guard embraces it:

1. **Capture everything** — not just git, but the full disk and environment state
2. **Inject into the summary** — the systemMessage survives compaction
3. **Auto-recover** — SessionStart detects the snapshot and tells Claude to read it
4. **Zero dependencies** — pure bash, works everywhere Claude Code runs

The result: compaction becomes a **minor hiccup** instead of a **full reset**.

## License

MIT License — see [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome. The project is intentionally minimal (pure bash, no dependencies).

---

Built with frustration and determination by [@jlceaser](https://github.com/jlceaser).
