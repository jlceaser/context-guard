#!/usr/bin/env bash
# security-pre-tool.sh — PreToolUse hook: context security scanning
# Scans tool inputs for prompt injection, sensitive file access, and leakage
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

# Extract tool name and input
# hooks.json provides: hookEventName, toolName, toolInput
TOOL_NAME=""
TOOL_INPUT=""

# Parse toolName
TOOL_NAME=$(echo "$INPUT" | sed -n 's/.*"toolName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

[ -z "$TOOL_NAME" ] && exit 0

# ─── Route by tool type ─────────────────────────────────────

case "$TOOL_NAME" in

    Read)
        # Check if trying to read a sensitive file
        FILE_PATH=$(echo "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

        if [ -n "$FILE_PATH" ]; then
            REASON=$(cg_sec_check_file_path "$FILE_PATH")
            if [ $? -ne 0 ] || [ -n "$REASON" ]; then
                cg_sec_make_decision "pre" "sensitive_file:${REASON};" "$TOOL_NAME" "file_guard"
                hook_log "ContextSecurity" "file_guard" "tool=$TOOL_NAME path=$FILE_PATH reason=$REASON mode=$CG_SEC_MODE" 2>/dev/null || true
                exit 0
            fi
        fi
        ;;

    Bash)
        # Scan command for injection patterns and potential secret exfiltration
        COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

        if [ -n "$COMMAND" ]; then
            # Check for injection in command
            INJECTION_FINDINGS=$(cg_sec_scan_injection "$COMMAND" || true)
            if [ -n "$INJECTION_FINDINGS" ]; then
                cg_sec_make_decision "pre" "$INJECTION_FINDINGS" "$TOOL_NAME" "injection"
                hook_log "ContextSecurity" "injection" "tool=$TOOL_NAME findings=$INJECTION_FINDINGS mode=$CG_SEC_MODE" 2>/dev/null || true
                exit 0
            fi

            # Check for credential exfiltration patterns
            if echo "$COMMAND" | grep -iqE 'curl.*(\$[A-Z_]*KEY|\$[A-Z_]*TOKEN|\$[A-Z_]*SECRET|\$[A-Z_]*PASSWORD)'; then
                cg_sec_make_decision "pre" "credential_exfiltration;" "$TOOL_NAME" "leakage"
                hook_log "ContextSecurity" "leakage" "tool=$TOOL_NAME findings=credential_exfiltration mode=$CG_SEC_MODE" 2>/dev/null || true
                exit 0
            fi
        fi
        ;;

    Write|Edit)
        # Scan content being written for injection (prevents writing malicious files)
        CONTENT=$(echo "$INPUT" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        [ -z "$CONTENT" ] && CONTENT=$(echo "$INPUT" | sed -n 's/.*"new_string"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

        # Also check file path for sensitive destinations
        FILE_PATH=$(echo "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        if [ -n "$FILE_PATH" ]; then
            REASON=$(cg_sec_check_file_path "$FILE_PATH")
            if [ $? -ne 0 ] || [ -n "$REASON" ]; then
                cg_sec_make_decision "pre" "write_sensitive_file:${REASON};" "$TOOL_NAME" "file_guard"
                hook_log "ContextSecurity" "file_guard" "tool=$TOOL_NAME path=$FILE_PATH reason=$REASON mode=$CG_SEC_MODE" 2>/dev/null || true
                exit 0
            fi
        fi
        ;;

    mcp__*)
        # MCP tools: scan entire input for injection
        INJECTION_FINDINGS=$(cg_sec_scan_injection "$INPUT" || true)
        if [ -n "$INJECTION_FINDINGS" ]; then
            cg_sec_make_decision "pre" "$INJECTION_FINDINGS" "$TOOL_NAME" "injection"
            hook_log "ContextSecurity" "injection" "tool=$TOOL_NAME findings=$INJECTION_FINDINGS mode=$CG_SEC_MODE" 2>/dev/null || true
            exit 0
        fi
        ;;

    *)
        # Other tools: fast pass-through
        ;;
esac

# Clean — no output means allow
exit 0
