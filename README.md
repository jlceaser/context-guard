# Context Guard

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Hooks-purple.svg)](https://docs.anthropic.com/en/docs/claude-code)
[![Zero Dependencies](https://img.shields.io/badge/Dependencies-Zero-brightgreen.svg)](#requirements)

**Never lose context again.** The most comprehensive context preservation system for Claude Code.

Context Guard is a multi-layered defense against context compaction loss — hooks capture state automatically, skills give you manual control, a specialized agent handles intelligent recovery, and worktree awareness preserves parallel work. Pure bash, zero dependencies.

---

## Why Context Guard?

When Claude Code hits ~95% context usage, it auto-compacts your conversation into a lossy summary. You lose:

- Which files you were editing and why
- Your debugging trail and hypotheses
- Build state and test results
- Uncommitted changes and stashes
- The overall "where we were"

**Context Guard captures your entire work environment** — not just git state, but disk changes, build health, worktrees, environment variables, and Claude's own memory files — and automatically restores it after compaction.

```
Before:  "Fix the auth bug in user-service.ts"
         *edits 3 files, runs tests, debugging failing case*
         --- COMPACTION ---
         "I see we're working on a project. How can I help?"

After:   --- COMPACTION ---
         "I see we were debugging the auth bug in user-service.ts.
          3 files modified, tests failing on line 42. Continuing..."
```

---

## Architecture

```
┌────────────────────── Context Guard ──────────────────────┐
│                                                           │
│  LAYER 1: Hooks (automatic)                               │
│  ┌─────────────┐ ┌──────────────┐ ┌────────────────┐     │
│  │ PreCompact   │ │ SessionStart │ │ Stop           │     │
│  │ 5-section    │ │ auto-detect  │ │ session        │     │
│  │ snapshot     │ │ + recovery   │ │ bookmark       │     │
│  └──────┬──────┘ └──────┬───────┘ └───────┬────────┘     │
│         │               │                 │               │
│  LAYER 2: Skills (manual control)                         │
│  ┌─────────────┐ ┌──────────────┐ ┌────────────────┐     │
│  │ /cg-snapshot │ │ /cg-restore  │ │ /cg-context-   │     │
│  │ checkpoint   │ │ manual load  │ │ status         │     │
│  └─────────────┘ └──────────────┘ └────────────────┘     │
│                                                           │
│  LAYER 3: Agent (intelligent)                             │
│  ┌───────────────────────────────────────────────────┐    │
│  │ context-keeper: reads snapshot + git + files       │    │
│  │ → produces structured recovery briefing            │    │
│  └───────────────────────────────────────────────────┘    │
│                                                           │
│  LAYER 4: Guidance (passive)                              │
│  ┌───────────────────────────────────────────────────┐    │
│  │ CLAUDE.md template: auto-recovery instructions     │    │
│  │ → Claude reads snapshot without being told to      │    │
│  └───────────────────────────────────────────────────┘    │
│                                                           │
│  LAYER 5: Protection (rules)                              │
│  ┌───────────────────────────────────────────────────┐    │
│  │ Hookify rules: protect snapshots + installed hooks │    │
│  └───────────────────────────────────────────────────┘    │
│                                                           │
│         ┌─────────────────────────────────┐               │
│         │  ~/.claude/compact-guard/       │               │
│         │  snapshot-*.md  latest.md       │               │
│         │  session-bookmark.md            │               │
│         └─────────────────────────────────┘               │
└───────────────────────────────────────────────────────────┘
```

---

## What Gets Captured

Context Guard models your **entire work environment**, not just version control:

### 1. Git State
Branch, last commit, modified/staged/untracked files, diff statistics, recent commits (8), active branches, and **domain classification** (changes sorted by: core, ui, build, ci, docs, scripts, test, config).

### 2. Disk State
Recently modified files via `find` (catches non-git-tracked work), build directory status, artifact ages, project disk usage.

### 3. Worktrees
Active worktree list, per-worktree dirty state, worktree detection (`.git` file vs directory).

### 4. Environment
Platform, shell, key env vars (VCPKG_ROOT, CMAKE_PREFIX_PATH, VIRTUAL_ENV), git stashes.

### 5. Claude Ecosystem
Recently updated auto-memory files, previous session bookmark availability.

---

## Quick Start

```bash
git clone https://github.com/jlceaser/context-guard.git
cd context-guard
bash install.sh
```

**One-line alternative:**

```bash
bash <(curl -sL https://raw.githubusercontent.com/jlceaser/context-guard/main/install.sh)
```

The installer copies hooks, skills, and agent to `~/.claude/` and shows you what to add to `settings.json`.

---

## Components

| Component | Type | Event/Usage | Purpose |
|-----------|------|-------------|---------|
| `compact-guard-pre.sh` | Hook | PreCompact | 5-section snapshot + systemMessage injection |
| `compact-guard-post.sh` | Hook | SessionStart | Auto-detect + inject recovery context |
| `compact-guard-stop.sh` | Hook | Stop | Session bookmark for next session |
| `compact-guard-lib.sh` | Library | (shared) | Git, worktree, domain, snapshot, JSON functions |
| `/cg-snapshot` | Skill | Manual | Create checkpoint on demand |
| `/cg-restore` | Skill | Manual | Read and summarize latest snapshot |
| `/cg-context-status` | Skill | Manual | System health dashboard |
| `context-keeper` | Agent | Delegated | Intelligent recovery with cross-referencing |
| `CLAUDE.md.template` | Template | Passive | Auto-recovery instructions for Claude |
| `context-health.sh` | Widget | StatusLine | Visual context health indicator |
| `compact-guard-rules.md` | Rules | Hookify | Protect snapshots and hooks |

---

## Configuration

```bash
# settings.json → env section
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"    # Trigger at 80% (default: 95%)

# Environment variables (optional)
COMPACT_GUARD_DIR=~/.claude/compact-guard  # Snapshot storage
COMPACT_GUARD_MAX_SNAPSHOTS=10             # Max snapshots to keep
COMPACT_GUARD_MAX_AGE=900                  # Recovery detection window (seconds)
```

### settings.json Hook Configuration

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "bash \"$HOME/.claude/hooks/compact-guard-pre.sh\"",
          "statusMessage": "Saving work state..."
        }]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "bash \"$HOME/.claude/hooks/compact-guard-stop.sh\"",
          "statusMessage": "Saving session bookmark..."
        }]
      }
    ]
  },
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"
  }
}
```

### SessionStart Integration

Add to your existing `session-start.sh`:

```bash
COMPACT_RECOVERY=$("$HOME/.claude/hooks/compact-guard-post.sh" 2>/dev/null || true)
if [ -n "$COMPACT_RECOVERY" ]; then
    CTX="$CTX | $COMPACT_RECOVERY"
fi
```

---

## Comparison

| Feature | [compaction-fix](https://github.com/ajjucoder/claude-compaction-fix) | [context-saver](https://github.com/panbergco/claude-context-saver) | [auto-compact](https://github.com/kfirco-jit/claude-auto-compact) | [context-handoff](https://github.com/who96/claude-code-context-handoff) | [context-battery](https://github.com/svenmeys/claude-context-battery) | **Context Guard** |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|
| Git state capture | - | Partial | - | Yes | - | **Full** |
| Disk-level file tracking | - | - | - | - | - | **Yes** |
| Build health monitoring | - | - | - | - | - | **Yes** |
| Domain classification | - | - | - | - | - | **Yes** |
| Worktree awareness | - | - | - | - | - | **Yes** |
| Environment snapshot | - | - | - | - | - | **Yes** |
| systemMessage injection | - | - | - | - | - | **Yes** |
| Auto-recovery | - | Yes | On resume | Yes | - | **Yes** |
| Manual checkpoints (skills) | - | - | - | - | - | **Yes** |
| Intelligent recovery (agent) | - | - | - | - | - | **Yes** |
| Session bookmarks | - | - | - | - | - | **Yes** |
| CLAUDE.md guidance | Yes | Partial | - | - | - | **Yes** |
| Visual indicator | - | Yes | - | - | Yes | **Yes** |
| Hookify protection rules | - | - | - | - | - | **Yes** |
| Zero external dependencies | Yes | - | - | - | - | **Yes** |
| Pure bash | Yes | - | - | Yes | Yes | **Yes** |
| Multi-layer defense | - | - | - | - | - | **5 layers** |

### Context Guard vs context-mode

[context-mode](https://github.com/mksglu/context-mode) and Context Guard solve **different halves** of the context problem:

| Aspect | context-mode | Context Guard |
|--------|:---:|:---:|
| **Focus** | Reduce context consumption | Preserve state across compaction |
| **How** | MCP sandbox (tool output stays out of context) | Multi-layer snapshot + recovery |
| **Prevents compaction?** | Delays it (98% less context used) | Handles it when it happens |
| **Architecture** | MCP server + FTS5 indexing | Hooks + skills + agent + rules |
| **Dependencies** | Node.js, SQLite | None (pure bash) |
| **Best for** | Long sessions with heavy tool use | Any session where compaction may occur |

**They are complementary.** Use context-mode to extend your context window, and Context Guard to preserve state when compaction eventually fires. Together: maximum context longevity + zero loss on compaction.

---

## Domain Classification

Changes are automatically categorized for quick context restoration:

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

Customize by editing `cg_classify_file()` in `compact-guard-lib.sh`.

---

## Snapshot Example

```markdown
# Compact Guard Snapshot

## Session Info
| Field | Value |
|-------|-------|
| Time | 2026-03-08 14:32:15 |
| Trigger | auto |
| Working Dir | /home/user/myproject |

## 1. Git State
| Field | Value |
|-------|-------|
| Project | myproject |
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
| Build Dir | build/dev |
| Build State | exists |
| Last Build | 5min ago |
```

---

## Uninstalling

```bash
bash uninstall.sh
```

Removes hooks, skills, and agent. Lists manual cleanup steps for settings.json.

---

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with hooks support
- Bash (Linux, macOS, Windows Git Bash / MSYS2)
- Git (optional — gracefully degrades without it)

---

## Philosophy

Context compaction is inevitable. Rather than fighting it, Context Guard embraces it with defense in depth:

1. **Capture everything** — git + disk + worktrees + environment + Claude ecosystem
2. **Multi-layer defense** — hooks (auto) + skills (manual) + agent (intelligent) + guidance (passive) + rules (protective)
3. **Inject into the summary** — systemMessage survives compaction
4. **Auto-recover** — SessionStart detects and tells Claude to read the snapshot
5. **Session continuity** — Stop hook bookmarks for cross-session awareness
6. **Zero dependencies** — pure bash, works everywhere Claude Code runs

The result: compaction becomes a **minor hiccup** instead of a **full reset**.

---

## License

[MIT](LICENSE)

## Contributing

Issues and PRs welcome at [github.com/jlceaser/context-guard](https://github.com/jlceaser/context-guard).

---

<p align="center">
  <b>Context Guard</b> — defense in depth for Claude Code context<br>
  Built by <a href="https://github.com/jlceaser">@jlceaser</a>
</p>
