# Contributing to Context Guard

Thank you for your interest in contributing! Context Guard is built to be simple, reliable, and dependency-free.

## Design Principles

1. **Pure bash** — no external dependencies (Python, Node.js, etc.)
2. **Cross-platform** — must work on Linux, macOS, and Windows (Git Bash/MSYS2)
3. **Graceful degradation** — work without git, without jq, without any optional tool
4. **Non-destructive** — never modify user files without explicit consent
5. **Minimal footprint** — hooks should complete in under 1 second

## Getting Started

```bash
git clone https://github.com/jlceaser/context-guard.git
cd context-guard
bash test.sh  # verify everything works
```

## Making Changes

### Hooks (`hooks/`)

- All hooks must source `compact-guard-lib.sh`
- Use `set -euo pipefail` at the top
- Handle missing commands gracefully (`command 2>/dev/null || true`)
- Use `stat -c` with `stat -f` fallback for cross-platform compatibility
- Test on your platform before submitting

### Skills (`skills/`)

- Skills are Markdown files with step-by-step instructions
- Keep them concise and action-oriented
- Include bash commands that Claude can run

### Agent (`agents/`)

- Agent definitions follow Claude Code's agent format
- Keep tool boundaries explicit (READ vs NEVER)
- Include a mandatory workflow

## Testing

Run the self-test suite before submitting:

```bash
bash test.sh
```

All tests must pass. Warnings are acceptable if documented.

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add diff content capture to snapshots
fix: correct field extraction in post-hook
docs: update installation instructions
test: add library function tests
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`feat/your-feature`)
3. Make your changes
4. Run `bash test.sh` — all tests must pass
5. Submit a PR with a clear description

## Code of Conduct

Be respectful, constructive, and helpful. We're all here to make Claude Code better.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
