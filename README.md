<p align="center">
  <h1 align="center">Context Guard</h1>
  <p align="center">
    <strong>Defense in depth for Claude Code context.</strong><br>
    Never lose your work state to context compaction again.
  </p>
  <p align="center">
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"></a>
    <a href="#requirements"><img src="https://img.shields.io/badge/Dependencies-Zero-brightgreen.svg" alt="Zero Dependencies"></a>
    <a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Shell-Bash-green.svg" alt="Shell: Bash"></a>
    <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/Claude_Code-Hooks-8A2BE2.svg" alt="Claude Code"></a>
    <a href="CHANGELOG.md"><img src="https://img.shields.io/badge/Version-3.0.0-orange.svg" alt="v3.0.0"></a>
  </p>
</p>

---

## The Problem

When Claude Code hits ~95% context usage, it auto-compacts your conversation. You lose:

- Which files you were editing and **why**
- Your debugging trail, hypotheses, and decisions
- Build state, test results, error messages
- Uncommitted changes, stashes, and worktree state
- The overall narrative: *"where were we?"*

**Context Guard captures your entire work environment** — git state, actual code diffs, build health, worktrees, environment variables, and Claude's own memory — and automatically restores it after compaction.

```
Before:  "Fix the auth bug in user-service.ts"
         *edits 3 files, runs tests, debugging failing case*
         --- COMPACTION ---
         "I see we're working on a project. How can I help?"

After:   --- COMPACTION ---
         "Resuming: auth bug in user-service.ts, branch feat/auth-fix.
          3 files modified (core:2, ui:1), tests failing on line 42.
          Diff shows we added token validation but missed expiry check.
          Continuing with the expiry logic..."
```

---

## Quick Start

**One command:**

```bash
bash <(curl -sL https://raw.githubusercontent.com/jlceaser/context-guard/main/install.sh)
```

**Or clone and install:**

```bash
git clone https://github.com/jlceaser/context-guard.git
cd context-guard
bash install.sh
```

The installer auto-configures `settings.json` (requires `jq`). Verify with:

```bash
bash test.sh
```

That's it. Context Guard is now active.

---

## How It Works

```
                          Context at 80%
                               │
                    ┌──────────▼──────────┐
                    │  PreCompact Hook    │
                    │  ┌────────────────┐ │
                    │  │ Git state      │ │
                    │  │ Code diffs     │ │     ┌─────────────────┐
                    │  │ Build health   │ │────▶│ Snapshot .md     │
                    │  │ Worktrees      │ │     │ + systemMessage  │
                    │  │ Environment    │ │     └────────┬────────┘
                    │  │ Claude memory  │ │              │
                    │  └────────────────┘ │              │
                    └─────────────────────┘              │
                                                        ▼
                    ┌─────────────────────┐    ┌────────────────┐
                    │  --- COMPACTION --- │───▶│ systemMessage   │
                    └─────────────────────┘    │ injected into   │
                                               │ compacted state │
                    ┌─────────────────────┐    └────────┬───────┘
                    │  SessionStart Hook  │◀────────────┘
                    │  Detects snapshot   │
                    │  Injects recovery   │──▶ Claude reads snapshot
                    └─────────────────────┘    and resumes work
```

**Two-phase defense:**

1. **systemMessage** — critical metadata (project, branch, dirty files) is injected directly into the compaction summary. This survives compaction and is immediately available.

2. **Snapshot file** — full state with code diffs is saved to disk. Claude reads this on the next turn to restore complete context.

---

## Architecture

Context Guard is a **5-layer defense system**:

```
┌─────────────────────────── Context Guard ────────────────────────────┐
│                                                                      │
│  LAYER 1: Hooks (automatic)                                          │
│  ┌──────────────┐  ┌───────────────┐  ┌─────────────────┐           │
│  │ PreCompact    │  │ SessionStart  │  │ Stop            │           │
│  │ Full snapshot │  │ Auto-detect   │  │ Session         │           │
│  │ + code diffs  │  │ + recovery    │  │ bookmark        │           │
│  │ + systemMsg   │  │ + resume      │  │ + session chain │           │
│  └───────┬──────┘  └───────┬───────┘  └────────┬────────┘           │
│          │                 │                    │                     │
│  LAYER 2: Skills (manual control)                                    │
│  ┌──────────────┐  ┌───────────────┐  ┌─────────────────┐           │
│  │ /cg-snapshot  │  │ /cg-restore   │  │ /cg-context-    │           │
│  │ checkpoint    │  │ manual load   │  │ status          │           │
│  └──────────────┘  └───────────────┘  └─────────────────┘           │
│                                                                      │
│  LAYER 3: Agent (intelligent)                                        │
│  ┌──────────────────────────────────────────────────────────┐        │
│  │ context-keeper: reads snapshots + git + diffs             │        │
│  │ → multi-snapshot analysis + structured recovery briefing  │        │
│  └──────────────────────────────────────────────────────────┘        │
│                                                                      │
│  LAYER 4: Guidance (passive)                                         │
│  ┌──────────────────────────────────────────────────────────┐        │
│  │ CLAUDE.md template: auto-recovery instructions            │        │
│  │ → Claude reads snapshot without being told to             │        │
│  └──────────────────────────────────────────────────────────┘        │
│                                                                      │
│  LAYER 5: Protection (rules)                                         │
│  ┌──────────────────────────────────────────────────────────┐        │
│  │ Hookify rules: protect snapshots + installed hooks        │        │
│  └──────────────────────────────────────────────────────────┘        │
│                                                                      │
│          ┌──────────────────────────────────┐                        │
│          │  ~/.claude/compact-guard/        │                        │
│          │  snapshot-*.md  latest.md        │                        │
│          │  session-bookmark.md             │                        │
│          │  .session-counter                │                        │
│          └──────────────────────────────────┘                        │
└──────────────────────────────────────────────────────────────────────┘
```

---

## What Gets Captured

### 1. Git State
Branch, last commit, modified/staged/untracked files, diff statistics, recent commits (8), active branches, and **domain classification**.

### 2. Code Diffs *(new in v3)*
Actual `git diff` content — first 40 lines per file, up to 8 files. This is the most valuable data for recovery: Claude can see exactly what code was being changed.

### 3. Disk State
Recently modified files (catches non-git-tracked work), build directory status, artifact ages, project size.

### 4. Worktrees
Active worktree list, per-worktree dirty state, worktree detection (`.git` file vs directory).

### 5. Environment
Platform, shell, key env vars (VCPKG_ROOT, CMAKE_PREFIX_PATH, VIRTUAL_ENV, NODE_ENV, CARGO_HOME), git stashes.

### 6. Claude Ecosystem
Recently updated auto-memory files, session bookmarks, session chain number.

### Domain Classification

Changes are automatically categorized:

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

---

## Components

| Component | Type | Purpose |
|-----------|------|---------|
| `compact-guard-pre.sh` | Hook (PreCompact) | Full state snapshot + code diffs + systemMessage |
| `compact-guard-post.sh` | Hook (SessionStart) | Auto-detect compaction + inject recovery |
| `compact-guard-stop.sh` | Hook (Stop) | Session bookmark for cross-session continuity |
| `compact-guard-lib.sh` | Library | Shared functions (git, worktree, domain, diff, JSON) |
| `/cg-snapshot` | Skill | Create manual checkpoint on demand |
| `/cg-restore` | Skill | Read and summarize latest snapshot |
| `/cg-context-status` | Skill | System health dashboard |
| `context-keeper` | Agent | Intelligent multi-snapshot recovery analysis |
| `CLAUDE.md.template` | Template | Auto-recovery instructions for Claude |
| `settings.json.template` | Template | Reference hook configuration |
| `context-health.sh` | Widget | StatusLine context health indicator |
| `compact-guard-rules.md` | Rules | Hookify protection for snapshots/hooks |
| `test.sh` | Test Suite | Validate installation and hook functionality |

---

## Configuration

```bash
# Trigger compaction at 80% instead of 95% (more room for recovery)
CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80

# Environment variables (all optional, with defaults)
COMPACT_GUARD_DIR=~/.claude/compact-guard  # Snapshot storage
COMPACT_GUARD_MAX_SNAPSHOTS=10             # Max snapshots to keep
COMPACT_GUARD_MAX_AGE=900                  # Recovery detection window (seconds)
COMPACT_GUARD_DIFF_LINES=40               # Lines of diff per file
COMPACT_GUARD_DIFF_FILES=8                # Max files to capture diffs for
```

### SessionStart Integration

The post-hook can run as a **standalone SessionStart hook** or as an **addon** called from your existing `session-start.sh`:

**Option A — Addon (recommended if you have a session-start.sh):**

```bash
# In your session-start.sh:
COMPACT_RECOVERY=$("$HOME/.claude/hooks/compact-guard-post.sh" 2>/dev/null || true)
if [ -n "$COMPACT_RECOVERY" ]; then
    CTX="$CTX | $COMPACT_RECOVERY"
fi
```

**Option B — Standalone hook in settings.json:**

```json
"SessionStart": [{
  "matcher": "",
  "hooks": [{
    "type": "command",
    "command": "bash \"$HOME/.claude/hooks/compact-guard-post.sh\"",
    "statusMessage": "Checking for context recovery..."
  }]
}]
```

---

## Comparison

Context Guard focuses on **state preservation** — capturing your complete work environment (git + diffs + disk + build + worktrees + environment) and recovering it automatically after compaction.

| Capability | [context-mode](https://github.com/mksglu/context-mode) | [context-cascade](https://github.com/DNYoussef/context-cascade) | [context-engineer](https://github.com/silvesterdivas/context-engineer) | **Context Guard** |
|------------|:---:|:---:|:---:|:---:|
| **Focus** | Context reduction | Modular loading | Budget management | **State preservation** |
| Git state capture | - | - | - | **Full** |
| Code diff capture | - | - | - | **Yes** |
| Disk-level file tracking | - | - | - | **Yes** |
| Build health monitoring | - | - | - | **Yes** |
| Domain classification | - | - | - | **Yes** |
| Worktree awareness | - | - | - | **Yes** |
| Environment snapshot | - | - | - | **Yes** |
| systemMessage injection | - | - | - | **Yes** |
| Auto-recovery on compaction | Via SQLite | - | Via TASK.md | **Via hooks** |
| Session chain tracking | - | - | - | **Yes** |
| Manual checkpoints (skills) | - | Yes | - | **Yes** |
| Intelligent recovery (agent) | - | Yes | - | **Yes** |
| Visual indicator | CLI | - | Dashboard | **StatusLine** |
| Self-test suite | - | - | - | **Yes** |
| Auto-configure installer | - | - | One-liner | **Auto (jq)** |
| Zero external dependencies | No (Node.js) | No (MCP) | No (Node.js) | **Yes** |
| Pure bash | No | No | No | **Yes** |

### Works great with context-mode

[context-mode](https://github.com/mksglu/context-mode) (2,900+ stars) and Context Guard solve **different halves** of the context problem:

| | context-mode | Context Guard |
|---|:---:|:---:|
| **Goal** | Reduce context consumption | Preserve state across compaction |
| **How** | MCP sandbox (~98% context savings) | Multi-layer snapshot + recovery |
| **Prevents compaction?** | Delays it significantly | Handles it when it fires |
| **Dependencies** | Node.js, SQLite | None (pure bash) |

**They are complementary.** context-mode reduces context consumption so compaction happens less often. Context Guard preserves your full state when it does happen. Together: maximum longevity + zero loss.

---

## Snapshot Example

<details>
<summary>Click to expand a sample snapshot</summary>

```markdown
# Context Guard Snapshot

## Session Info
| Field | Value |
|-------|-------|
| Time | 2026-03-08 14:32:15 |
| Session | #3 |
| Trigger | auto |
| Working Dir | /home/user/myproject |
| Context Guard | v3.0.0 |

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

### Diff Content (actual changes)
--- core/src/auth_service.cpp ---
@@ -42,6 +42,12 @@
 bool AuthService::validateToken(const QString& token) {
+    // Check token expiry
+    auto expiry = extractExpiry(token);
+    if (expiry < QDateTime::currentDateTime()) {
+        return false;
+    }
+
     return verifySignature(token);
 }

## 2. Disk State
| Field | Value |
|-------|-------|
| Project Size | 156M |
| Build Dir | build/dev |
| Build State | exists |
| Last Build | 5min ago |

## 4. Environment
| Field | Value |
|-------|-------|
| Platform | Linux |
| Shell | /bin/bash |
| Key Vars | CMAKE_PREFIX_PATH=set VENV=active |

## Recovery
After compaction, this snapshot was automatically saved.
Read this file to restore working state.
```

</details>

---

## Uninstalling

```bash
bash uninstall.sh
```

Options:
- `--keep-snapshots` — keep snapshot files
- `--skip-config` — skip settings.json cleanup

---

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with hooks support
- Bash (Linux, macOS, Windows Git Bash / MSYS2)
- Git (optional — gracefully degrades without it)
- jq (optional — enables auto-configuration, falls back to manual)

---

## Philosophy

Context compaction is inevitable. Rather than fighting it, Context Guard embraces it:

1. **Capture everything** — git + diffs + disk + worktrees + environment + Claude ecosystem
2. **Inject into the summary** — systemMessage survives compaction
3. **Auto-recover** — SessionStart detects and injects recovery context
4. **Multi-layer defense** — hooks (auto) + skills (manual) + agent (intelligent) + guidance (passive) + rules (protective)
5. **Session continuity** — bookmarks and session chain across multiple sessions
6. **Zero dependencies** — pure bash, works everywhere Claude Code runs

The result: compaction becomes a **minor hiccup** instead of a **full reset**.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)

---

<p align="center">
  <strong>Context Guard</strong> — defense in depth for Claude Code context<br>
  <a href="https://github.com/jlceaser/context-guard/issues">Report Bug</a> · <a href="https://github.com/jlceaser/context-guard/issues">Request Feature</a><br><br>
  Built by <a href="https://github.com/jlceaser">@jlceaser</a>
</p>
