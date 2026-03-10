# Changelog

All notable changes to Context Guard will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.1.0] — 2026-03-10

### Changed
- `compact-guard-lib.sh` version constant bumped to `0.4.1`
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` recommended value updated to `97` — triggers compaction later, maximizing working context while pre-compact hook still saves state safely
- `subagent-context.sh` — added per-agent chub hints (`web-dev`: `cloudflare/workers`, `ai-dev`: `anthropic/claude-api`) for hallucination prevention on external API calls
- `subagent-context.sh` — `web-dev` and `ai-dev` agent cases added (previously fell through to default)
- Project domain paths updated: `MakineAI-Launcher` (Qt6/C++ app) and `MakineAI` (AI/tokenizer) correctly separated

### Compatibility
- Fully backward compatible — no new hooks or skills added
- Existing snapshots and annotations unaffected

## [4.0.0] — 2026-03-09

### Added
- **Annotation Layer** — persistent topic-based notes that survive context compaction and session restarts, inspired by context-hub (github.com/andrewyng/context-hub)
- **`/cg-annotate <topic> "note"`** — append a dated bullet note to a project-scoped topic file (`~/.claude/annotations/<project>/<topic>.md`)
- **`/cg-recall <topic>`** — retrieve all annotations for a topic; lists available topics if none specified
- **`COMPACT_GUARD_ANNOT_DIR`** — configurable annotation storage directory (default: `~/.claude/annotations/`)
- **Annotation awareness in session-start** — auto-detects project annotation files and reports topic count on session start
- **Pre-compact annotation reminder** — systemMessage now includes `/cg-annotate` reminder before context compaction
- **Annotation inventory in `/cg-context-status`** — shows all annotation topics with line counts and last-modified dates
- **Project-scoped annotations** — annotations organized by project key (e.g., `C--cedra`, `MakineAI`) for multi-project use

### Changed
- `compact-guard-lib.sh` version constant updated to `0.3.0`
- `COMPACT_GUARD_ANNOT_DIR` constant added to lib
- `cg-context-status` skill updated with step 7 (annotation inventory)
- `install.sh` creates `~/.claude/annotations/` on setup and bumped to v4.0.0
- `uninstall.sh` prompts user before removing annotations directory
- `plugin.json` version bumped to `4.0.0`
- `test.sh` adds annotation layer test section (section 10)
- `context-keeper` agent now reads `~/.claude/annotations/` in tool boundaries
- README updated with Annotation Layer documentation and v4.0.0 badge

### Compatibility
- Fully backward compatible — annotation layer is additive
- Existing snapshots, handoffs, and hooks unaffected
- No new dependencies (pure bash, zero deps maintained)

## [3.0.0] — 2026-03-08

### Added
- **Claude Code Plugin** — full `.claude-plugin/` manifest with `plugin.json`, `hooks.json`, `marketplace.json`
- **Plugin install** — `/plugin marketplace add jlceaser/context-guard` + `/plugin install context-guard@jlceaser`
- **SKILL.md format** — skills converted to YAML frontmatter + subdirectory structure
- **Agent YAML frontmatter** — context-keeper agent uses standard agent format
- **`/cg-setup` skill** — initial setup and configuration wizard
- **Diff content capture** — actual code diffs saved in snapshots (first 40 lines per file, up to 8 files)
- **Session chain tracking** — sequential session numbering across compactions and sessions
- **Auto-configure installer** — uses `jq` to automatically update `settings.json` (no manual JSON editing)
- **Auto-cleanup uninstaller** — removes hooks from `settings.json` automatically
- **Self-test suite** (`test.sh`) — validates installation, hook functionality, plugin structure, and snapshot integrity
- **Standalone post-hook** — can run as direct SessionStart hook or as addon called from session-start.sh
- **Session bookmark resume** — post-hook detects session bookmarks within 24 hours for cross-session continuity
- **Plugin-level settings** — `.claude/settings.json` for env vars
- **Settings.json template** — reference configuration file
- **GitHub Issue templates** — bug report and feature request templates
- **CONTRIBUTING.md** — contributor guide
- **Platform detection** — `cg_platform()`, `cg_is_windows()` functions
- **Settings helpers** — `cg_has_hook()`, `cg_has_env()` functions
- **Extended build detection** — `out/`, `dist/`, `target/` directories, `.so`, `.dylib`, `.wasm` artifacts
- **Extended ignore paths** — `.next/`, `dist/`, `target/` excluded from disk scanning
- **Environment capture** — `NODE_ENV`, `CARGO_HOME` detection
- **Multi-snapshot analysis** in context-keeper agent

### Changed
- Bumped version to 3.0.0
- Skills now use SKILL.md format in subdirectories (plugin-compatible)
- Agent uses YAML frontmatter (plugin-compatible)
- README updated with plugin install as primary method
- Renamed branding: "Compact Guard" → "Context Guard" in all systemMessage output
- Installer now shows verify command: `bash test.sh`
- Uninstaller supports `--keep-snapshots` and `--skip-config` flags
- Installer supports `--skip-config` and `--force` flags
- Enhanced context-keeper agent with diff analysis workflow
- Snapshot format now includes Session number and Diff Content section
- Comparison table updated with real competing repos (context-mode, context-cascade, context-engineer)

### Fixed
- Post-hook field extraction now properly handles markdown table format
- Session counter persists across hook invocations

## [2.0.0] — 2026-03-08

### Added
- **5-layer architecture** — hooks + skills + agent + guidance + rules
- **Worktree awareness** — detect `.git` file vs directory, per-worktree dirty state
- **Domain classification** — auto-categorize changes (core, ui, build, ci, docs, scripts, test, config, infra)
- **Stop hook** — session bookmark for cross-session continuity
- **Skills** — `/cg-snapshot`, `/cg-restore`, `/cg-context-status`
- **Agent** — `context-keeper` for intelligent recovery
- **CLAUDE.md template** — passive auto-recovery instructions
- **StatusLine widget** — visual context health indicator
- **Hookify rules** — protect snapshots and installed hooks

### Changed
- Rebranded from "Claude Compact Guard" to "Context Guard"
- Professional README with badges, architecture diagram, comparison table
- Enhanced snapshot format with 5 sections

## [1.0.0] — 2026-03-08

### Added
- Initial release
- PreCompact hook with git state capture
- SessionStart addon for recovery detection
- Basic snapshot management
- Pure bash, zero dependencies

[4.0.0]: https://github.com/jlceaser/context-guard/compare/v3.0.0...v4.0.0
[3.0.0]: https://github.com/jlceaser/context-guard/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/jlceaser/context-guard/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/jlceaser/context-guard/releases/tag/v1.0.0
