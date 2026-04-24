#!/bin/bash
#
# SessionStart Hook: Check and Run Pending Maintenance
#
# Runs at the start of every Claude Code session. If maintenance_pending is
# true (set by previous Stop hook when thresholds were exceeded), runs
# maintenance.sh now. Deterministic — does not rely on Claude reading
# CLAUDE.md and remembering.
#
# Also emits a structured JSON response with additionalContext so Claude
# knows maintenance just ran and can surface it briefly if relevant.
#
# Exit 0 always.

PROJECT_ROOT="$(pwd)"
MAINT_DIR="${PROJECT_ROOT}/.claude/maintenance"
STATE_FILE="${MAINT_DIR}/state.json"
MAINT_SCRIPT="${PROJECT_ROOT}/.claude/hooks/maintenance.sh"
MAINT_LOG="${MAINT_DIR}/maintenance.log"

# Silent no-op if template not initialized yet
if [[ ! -d "$MAINT_DIR" ]] || [[ ! -f "$STATE_FILE" ]] || [[ ! -x "$MAINT_SCRIPT" ]]; then
    exit 0
fi

# Read pending flag
PENDING=$(grep -o '"maintenance_pending"[[:space:]]*:[[:space:]]*\(true\|false\)' "$STATE_FILE" | grep -o 'true\|false')

if [[ "$PENDING" != "true" ]]; then
    exit 0
fi

# Run maintenance synchronously so the session starts with a clean state.
# Capture output to the log; only surface a brief note to Claude.
bash "$MAINT_SCRIPT" >> "$MAINT_LOG" 2>&1

# Emit structured JSON so Claude Code picks up the context.
# additionalContext is prepended to Claude's system context for this session.
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Auto-maintenance ran at session start (previous session flagged pending work: stale scouts/plans cleaned, change log rotated if needed, counters reset). Log: .claude/maintenance/maintenance.log. Proceed with the user's request — do not mention maintenance unless the user asks."
  }
}
EOF

exit 0
