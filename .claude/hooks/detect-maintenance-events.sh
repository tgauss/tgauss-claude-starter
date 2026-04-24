#!/bin/bash
#
# PostToolUse Hook: Detect Maintenance Events
#
# Monitors Bash tool output for significant events (git commits, builds,
# tests, growth thresholds) and emits STRUCTURED JSON with additionalContext
# so Claude reliably picks up the instruction. Previously used plain-text
# [maintenance-hint] lines which Claude often ignored.
#
# Exit 0 always.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"tool_name"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')

if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

PROJECT_ROOT="$(pwd)"
MAINT_DIR="${PROJECT_ROOT}/.claude/maintenance"
CHANGE_LOG="${MAINT_DIR}/change-log.jsonl"
STATE_FILE="${MAINT_DIR}/state.json"

mkdir -p "$MAINT_DIR"

if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"last_maintenance_ts":"","last_knowledge_update_ts":"","last_commit_ts":"","last_simplify_ts":"","edits_since_last_maintenance":0,"commits_since_last_maintenance":0,"commits_since_last_simplify":0,"maintenance_pending":false}' > "$STATE_FILE"
fi

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Portable in-place sed (macOS + Linux)
sed_inplace() {
    sed -i '' "$1" "$2" 2>/dev/null || sed -i "$1" "$2" 2>/dev/null
}

# Emit structured response that Claude Code reliably surfaces as context
emit_context() {
    local reason="$1"
    local instruction="$2"
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[auto-maintenance signal — ${reason}] ${instruction}"
  }
}
EOF
}

# --- Git commit detected ---
if [[ "$COMMAND" =~ git[[:space:]]+commit ]]; then
    COMMIT_MSG=$(echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p' | head -c 100)
    echo "{\"ts\":\"${TS}\",\"event\":\"git_commit\",\"message\":\"${COMMIT_MSG}\"}" >> "$CHANGE_LOG"

    COMMIT_COUNT=$(grep -o '"commits_since_last_maintenance"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$')
    COMMIT_COUNT=${COMMIT_COUNT:-0}
    NEW_COUNT=$((COMMIT_COUNT + 1))
    sed_inplace "s/\"commits_since_last_maintenance\"[[:space:]]*:[[:space:]]*[0-9]*/\"commits_since_last_maintenance\":${NEW_COUNT}/" "$STATE_FILE"
    sed_inplace "s/\"last_commit_ts\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"last_commit_ts\":\"${TS}\"/" "$STATE_FILE"

    SIMPLIFY_COUNT=$(grep -o '"commits_since_last_simplify"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$')
    SIMPLIFY_COUNT=${SIMPLIFY_COUNT:-0}
    NEW_SIMPLIFY=$((SIMPLIFY_COUNT + 1))
    sed_inplace "s/\"commits_since_last_simplify\"[[:space:]]*:[[:space:]]*[0-9]*/\"commits_since_last_simplify\":${NEW_SIMPLIFY}/" "$STATE_FILE"

    # Bloat-detection: trigger simplify pass every 10 commits
    if [[ $((NEW_SIMPLIFY % 10)) -eq 0 ]] && [[ $NEW_SIMPLIFY -gt 0 ]]; then
        emit_context \
            "${NEW_SIMPLIFY} commits since last simplify pass" \
            "At the next natural pause (not mid-task), invoke the 'simplify' skill to review recent changes for dead code, premature abstractions, duplicated logic, and unused files. Do not interrupt the user's current request — complete it first, then offer: 'Want me to run /simplify on recent changes?'"
        exit 0
    fi

    # Knowledge update signal every commit — stronger wording
    emit_context \
        "git commit" \
        "A commit just landed. If this concluded a significant feature (multiple files, new patterns, new behavior), invoke the knowledge-maintainer subagent via the Agent tool to update .claude/knowledge/ files. Skip for trivial commits (typo fixes, formatting, config tweaks). Do this after your current task completes, not in the middle of another operation."
    exit 0
fi

# --- Successful build ---
if [[ "$COMMAND" =~ npm[[:space:]]+run[[:space:]]+build ]] || [[ "$COMMAND" =~ pnpm[[:space:]]+build ]] || [[ "$COMMAND" =~ yarn[[:space:]]+build ]]; then
    echo "{\"ts\":\"${TS}\",\"event\":\"build_success\",\"command\":\"${COMMAND}\"}" >> "$CHANGE_LOG"
    emit_context \
        "build completed" \
        "A build just completed. After finishing the current task, run 'bash .claude/hooks/maintenance.sh' to clean stale artifacts, and invoke the knowledge-maintainer subagent if new features shipped."
    exit 0
fi

# --- Test runs / quality checks (logged, no signal) ---
if [[ "$COMMAND" =~ (npm|pnpm|yarn)[[:space:]]+(run[[:space:]]+)?test ]] || \
   [[ "$COMMAND" =~ (npm|pnpm|yarn)[[:space:]]+run[[:space:]]+typecheck ]] || \
   [[ "$COMMAND" =~ (npm|pnpm|yarn)[[:space:]]+run[[:space:]]+lint ]]; then
    echo "{\"ts\":\"${TS}\",\"event\":\"quality_check\",\"command\":\"${COMMAND}\"}" >> "$CHANGE_LOG"
fi

exit 0
