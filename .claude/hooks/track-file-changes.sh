#!/bin/bash
#
# PostToolUse Hook: Track File Changes
#
# Silently logs Edit/Write events to a change log and emits a structured
# JSON nudge at edit thresholds so Claude reliably surfaces it as context
# (plain text hints were often ignored).
#
# Exit 0 always.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"tool_name"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file_path"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')

if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Skip tracking changes to the maintenance system itself
if [[ "$FILE_PATH" =~ \.claude/maintenance/ ]]; then
    exit 0
fi

PROJECT_ROOT="$(pwd)"
MAINT_DIR="${PROJECT_ROOT}/.claude/maintenance"
CHANGE_LOG="${MAINT_DIR}/change-log.jsonl"
STATE_FILE="${MAINT_DIR}/state.json"

mkdir -p "$MAINT_DIR"

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EVENT="file_edit"
[[ "$TOOL_NAME" == "Write" ]] && EVENT="file_write"

echo "{\"ts\":\"${TS}\",\"event\":\"${EVENT}\",\"path\":\"${FILE_PATH}\",\"tool\":\"${TOOL_NAME}\"}" >> "$CHANGE_LOG"

if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"last_maintenance_ts":"","last_knowledge_update_ts":"","last_commit_ts":"","last_simplify_ts":"","edits_since_last_maintenance":0,"commits_since_last_maintenance":0,"commits_since_last_simplify":0,"maintenance_pending":false}' > "$STATE_FILE"
fi

EDIT_COUNT=$(grep -o '"edits_since_last_maintenance"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$')
EDIT_COUNT=${EDIT_COUNT:-0}
NEW_COUNT=$((EDIT_COUNT + 1))

sed_inplace() {
    sed -i '' "$1" "$2" 2>/dev/null || sed -i "$1" "$2" 2>/dev/null
}
sed_inplace "s/\"edits_since_last_maintenance\"[[:space:]]*:[[:space:]]*[0-9]*/\"edits_since_last_maintenance\":${NEW_COUNT}/" "$STATE_FILE"

# Every 25 edits, emit a structured nudge (reliably surfaced)
THRESHOLD=25
if [[ $((NEW_COUNT % THRESHOLD)) -eq 0 ]] && [[ $NEW_COUNT -gt 0 ]]; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[auto-maintenance signal — ${NEW_COUNT} file edits since last maintenance] At the next natural pause (after committing, or when the user pauses), run 'bash .claude/hooks/maintenance.sh' to clean stale artifacts. Do not interrupt current work."
  }
}
EOF
fi

exit 0
