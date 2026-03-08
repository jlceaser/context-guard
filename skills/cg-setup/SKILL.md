---
name: cg-setup
description: |
  Initial setup and configuration for Context Guard.
  Trigger: "setup context guard", "configure context guard", "initialize guard",
  "/cg-setup"
---

# Context Guard — Setup

Run initial setup and configuration for Context Guard.

## Steps

### 1. Create Data Directory

```bash
mkdir -p "$HOME/.claude/compact-guard"
echo "1" > "$HOME/.claude/compact-guard/.session-counter" 2>/dev/null || true
echo "Data directory ready: $HOME/.claude/compact-guard"
```

### 2. Check Autocompact Override

Check if `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is set in settings.json:

```bash
if grep -q "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "$HOME/.claude/settings.json" 2>/dev/null; then
    VALUE=$(grep "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "$HOME/.claude/settings.json" | sed 's/.*: *"//;s/".*//')
    echo "Autocompact override: ${VALUE}% (already set)"
else
    echo "MISSING: CLAUDE_AUTOCOMPACT_PCT_OVERRIDE not set"
    echo "Add to settings.json → env: \"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE\": \"80\""
fi
```

If not set and `jq` is available, offer to set it:

```bash
if command -v jq &>/dev/null && ! grep -q "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" "$HOME/.claude/settings.json" 2>/dev/null; then
    TMP=$(mktemp)
    cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.pre-cg-setup.bak"
    jq '.env["CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"] = "80"' "$HOME/.claude/settings.json" > "$TMP" && mv "$TMP" "$HOME/.claude/settings.json"
    echo "Set CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80"
fi
```

### 3. Verify Hooks

```bash
echo ""
echo "Hook status:"
grep -q "compact-guard-pre" "$HOME/.claude/settings.json" 2>/dev/null && echo "  PreCompact: OK" || echo "  PreCompact: MISSING — reinstall plugin or run install.sh"
grep -q "compact-guard-stop" "$HOME/.claude/settings.json" 2>/dev/null && echo "  Stop: OK" || echo "  Stop: MISSING — reinstall plugin or run install.sh"
```

### 4. Run Self-Test (if available)

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -f "$PLUGIN_ROOT/test.sh" ]; then
    bash "$PLUGIN_ROOT/test.sh"
elif [ -f "$HOME/.claude/compact-guard/../../cedra/claude-compact-guard/test.sh" ]; then
    echo "Run: bash /path/to/context-guard/test.sh"
fi
```

### 5. Report

Show the user:
- Installation mode (plugin or manual)
- Hook configuration status
- Data directory location
- CLAUDE_AUTOCOMPACT_PCT_OVERRIDE value
- Available skills: `/cg-snapshot`, `/cg-restore`, `/cg-context-status`
- Suggest adding CLAUDE.md template for passive recovery
