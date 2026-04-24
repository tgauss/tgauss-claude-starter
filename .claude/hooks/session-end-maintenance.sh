#!/bin/bash
#
# Stop Hook: Session End Maintenance
#
# Runs after Claude finishes its response. If significant work happened
# since the last maintenance, RUNS maintenance.sh directly (async, silent)
# and updates state. Previously this only flagged state — now it actually
# performs cleanup so the user doesn't rely on Claude to remember.
#
# Exit 0 always (Stop hook must not block the session from ending).

PROJECT_ROOT="$(pwd)"
MAINT_DIR="${PROJECT_ROOT}/.claude/maintenance"
STATE_FILE="${MAINT_DIR}/state.json"
MAINT_SCRIPT="${PROJECT_ROOT}/.claude/hooks/maintenance.sh"
MAINT_LOG="${MAINT_DIR}/maintenance.log"

# Exit silently if no maintenance dir or state file (first run)
if [[ ! -d "$MAINT_DIR" ]] || [[ ! -f "$STATE_FILE" ]]; then
    exit 0
fi

# Read counters
EDIT_COUNT=$(grep -o '"edits_since_last_maintenance"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$')
COMMIT_COUNT=$(grep -o '"commits_since_last_maintenance"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$')

EDIT_COUNT=${EDIT_COUNT:-0}
COMMIT_COUNT=${COMMIT_COUNT:-0}

# Thresholds: run maintenance if meaningful work happened
# 10+ edits OR 2+ commits = worth cleaning up
if [[ $EDIT_COUNT -lt 10 ]] && [[ $COMMIT_COUNT -lt 2 ]]; then
    exit 0
fi

# Run maintenance.sh asynchronously so Stop hook returns fast.
# stdout/stderr captured to a log file the user can inspect.
if [[ -x "$MAINT_SCRIPT" ]]; then
    nohup bash "$MAINT_SCRIPT" >> "$MAINT_LOG" 2>&1 &
    disown 2>/dev/null || true
fi

exit 0
