#!/usr/bin/env bash
# spec-coverage-gate — entry point for Claude Code PreToolUse hook.
#
# Reads JSON payload from stdin, forwards it to the python implementation,
# preserves exit code (0 pass, 2 block) and stderr.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find python: prefer python3, fall back to python
if command -v python3 >/dev/null 2>&1; then
    PY=python3
elif command -v python >/dev/null 2>&1; then
    PY=python
else
    # python missing — fail open (do not block writes when toolchain incomplete)
    echo "spec-coverage-gate: python not found, skipping" >&2
    exit 0
fi

exec "$PY" "$SCRIPT_DIR/spec-coverage-gate.py"
