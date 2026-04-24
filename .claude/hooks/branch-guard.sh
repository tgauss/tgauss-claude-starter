#!/bin/bash
#
# PreToolUse Hook: Branch Guard
#
# Detects when Claude is about to edit/write files while the repo is on a
# protected branch (main/master/production). Does NOT block — instead emits
# additionalContext so Claude can confirm with the user first. Blocking
# would be too aggressive for quick doc/config edits.
#
# Exit 0 always. The JSON output is what shapes Claude's behavior.

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file_path"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')

# Skip if not a file edit
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Skip for edits inside .claude/ itself (template maintenance is fine on any branch)
if [[ "$FILE_PATH" =~ \.claude/ ]]; then
    exit 0
fi

# Require a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null)

# Protected branches: main, master, production, prod, develop, development
case "$BRANCH" in
    main|master|production|prod|develop|development)
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "[branch-guard] About to edit ${FILE_PATH} while on protected branch '${BRANCH}'. Before proceeding, confirm with the user: 'You're on ${BRANCH} — want me to create a feature branch first?' Do not skip this confirmation unless the user already requested branch-free work in this session."
  }
}
EOF
        ;;
esac

exit 0
