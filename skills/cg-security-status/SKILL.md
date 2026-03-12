---
name: cg-security-status
description: Show Context Guard security layer status, event log, and configuration
trigger: "/cg-security-status"
---

# Context Guard — Security Status Dashboard

Show the security layer health and event summary.

## Steps

1. Read `~/.claude/context-guard/security/security.jsonl` — show last 10 events
2. Read `~/.claude/context-guard/security/config.sh` — show current configuration (or defaults if missing)
3. Check if security hooks are registered in `~/.claude/settings.json` (look for `security-pre-tool` and `security-post-tool`)
4. Read `~/.claude/context-guard/security/allowlist.txt` — show allowlisted patterns
5. Present a structured dashboard:

```
## Context Security Status

| Setting | Value |
|---------|-------|
| Enabled | true/false |
| Mode | warn/block/log |
| Injection Scan | on/off |
| Leakage Scan | on/off |
| File Guard | on/off |
| Manipulation Scan | on/off |

### Recent Events (last 10)
| Time | Type | Severity | Tool | Details |
|------|------|----------|------|---------|
| ... | ... | ... | ... | ... |

### Event Summary
total=N | injection=N leakage=N file_guard=N manipulation=N

### Allowlist
N entries configured

### Hook Registration
- PreToolUse: registered/missing
- PostToolUse: registered/missing
```

6. If no events exist, report "No security events recorded — system is clean or newly installed."
