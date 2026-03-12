---
name: cg-security-config
description: Configure Context Guard security settings — mode, toggles, allowlist
trigger: "/cg-security-config"
args: "[setting] [value]"
---

# Context Guard — Security Configuration

Manage security layer settings interactively.

## Usage

- `/cg-security-config` — show current settings
- `/cg-security-config mode warn|block|log` — set security mode
- `/cg-security-config toggle injection|leakage|file_guard|manipulation on|off` — toggle a scanner
- `/cg-security-config allowlist add tool:pattern:reason` — add allowlist entry
- `/cg-security-config allowlist remove pattern` — remove allowlist entry
- `/cg-security-config reset` — reset to defaults

## Steps

### Show settings (no args)
1. Read `~/.claude/context-guard/security/config.sh`
2. Display all current values in a table
3. Show allowlist entries

### Set mode
1. Validate value is `warn`, `block`, or `log`
2. Update `CG_SEC_MODE` in `~/.claude/context-guard/security/config.sh`
3. Confirm the change

### Toggle scanner
1. Map scanner name to variable:
   - `injection` → `CG_SEC_INJECTION_SCAN`
   - `leakage` → `CG_SEC_LEAKAGE_SCAN`
   - `file_guard` → `CG_SEC_FILE_GUARD`
   - `manipulation` → `CG_SEC_MANIPULATION_SCAN`
2. Update the value to `true` or `false`
3. Confirm the change

### Allowlist management
1. For `add`: append entry to `~/.claude/context-guard/security/allowlist.txt`
2. For `remove`: remove matching line from allowlist
3. Show updated allowlist

### Reset
1. Copy default config from plugin's `config/security-config.sh` to `~/.claude/context-guard/security/config.sh`
2. Clear allowlist (keep header comments)
3. Confirm reset
