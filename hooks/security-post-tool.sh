#!/usr/bin/env bash
# security-post-tool.sh — PostToolUse hook: scan tool outputs
# Detects prompt injection, credential leakage, and context manipulation in outputs
# Pure bash, zero dependencies
# MIT License — github.com/jlceaser/context-guard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/context-security-lib.sh"

# Optional: source project's hook logger if available
source "$HOME/.claude/hooks/hook-logger.sh" 2>/dev/null || true

# ─── Fast exit if disabled ──────────────────────────────────

[ "$CG_SEC_ENABLED" != "true" ] && exit 0

# ─── Read hook input from stdin ─────────────────────────────

INPUT=$(cat 2>/dev/null || echo "{}")

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | sed -n 's/.*"toolName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

[ -z "$TOOL_NAME" ] && exit 0

# For PostToolUse, the tool_output is in the JSON but can be very large.
# We extract a manageable portion for scanning.
# The full JSON is our scan target — toolOutput may contain the dangerous content.
SCAN_TEXT=$(cg_sec_truncate "$INPUT")

# ─── Collect all findings ───────────────────────────────────

ALL_FINDINGS=""
EVENT_TYPE=""

# 1. Prompt injection scan
INJECTION_FINDINGS=$(cg_sec_scan_injection "$SCAN_TEXT" || true)
if [ -n "$INJECTION_FINDINGS" ]; then
    ALL_FINDINGS="${ALL_FINDINGS}${INJECTION_FINDINGS}"
    EVENT_TYPE="injection"
fi

# 2. Leakage scan (secrets in output)
LEAKAGE_FINDINGS=$(cg_sec_scan_leakage "$SCAN_TEXT" || true)
if [ -n "$LEAKAGE_FINDINGS" ]; then
    ALL_FINDINGS="${ALL_FINDINGS}${LEAKAGE_FINDINGS}"
    EVENT_TYPE="${EVENT_TYPE:+${EVENT_TYPE}+}leakage"
fi

# 3. Context manipulation scan
MANIPULATION_FINDINGS=$(cg_sec_scan_manipulation "$SCAN_TEXT" || true)
if [ -n "$MANIPULATION_FINDINGS" ]; then
    ALL_FINDINGS="${ALL_FINDINGS}${MANIPULATION_FINDINGS}"
    EVENT_TYPE="${EVENT_TYPE:+${EVENT_TYPE}+}manipulation"
fi

# ─── Output decision if threats found ───────────────────────

if [ -n "$ALL_FINDINGS" ]; then
    cg_sec_make_decision "post" "$ALL_FINDINGS" "$TOOL_NAME" "$EVENT_TYPE"
    hook_log "ContextSecurity" "post_scan" "tool=$TOOL_NAME findings=$ALL_FINDINGS mode=$CG_SEC_MODE" 2>/dev/null || true
    cg_sec_log_cleanup
fi

exit 0
