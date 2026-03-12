#!/usr/bin/env bash
# Context Guard — Security Configuration Template
# Copy to ~/.claude/context-guard/security/config.sh and customize
# MIT License — github.com/jlceaser/context-guard

# ─── Master Switch ──────────────────────────────────────────
# Set to false to completely disable security scanning
CG_SEC_ENABLED=true

# ─── Mode ───────────────────────────────────────────────────
# warn  — inject systemMessage warnings, never block (default, recommended)
# block — block dangerous tool calls in PreToolUse, warn in PostToolUse
# log   — silently log events, no user-facing output
CG_SEC_MODE=warn

# ─── Feature Toggles ───────────────────────────────────────
# Enable/disable individual scanning engines
CG_SEC_INJECTION_SCAN=true      # Prompt injection detection
CG_SEC_LEAKAGE_SCAN=true        # Credential/secret leakage detection
CG_SEC_FILE_GUARD=true           # Sensitive file access protection
CG_SEC_MANIPULATION_SCAN=true    # Context manipulation detection

# ─── Performance ────────────────────────────────────────────
# Max bytes to scan per tool input/output (larger content is truncated)
CG_SEC_MAX_SCAN_BYTES=50000
