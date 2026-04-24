#!/bin/bash
#
# PreToolUse Hook: Block Hardcoded Secrets
#
# Scans Write/Edit tool inputs for strings that look like API keys, tokens,
# private keys, or AWS credentials. Blocks the operation if found, with a
# message telling Claude to use env vars instead.
#
# Exit codes:
#   0 — no secret detected, allow
#   2 — secret detected, block
#
# Patterns intentionally err on the side of false positives for anything that
# would leak a real credential into source control.

INPUT=$(cat)

# Scan the entire JSON input. Escaped quotes inside "content"/"new_string" break
# naive field extraction, so the safest approach is to search the full raw input
# for secret patterns. False-positive risk is low because the patterns require
# specific prefixes (sk-ant-, AKIA, ghp_, etc.) that won't appear in a well-formed
# tool-use request unless they are in the write/edit payload itself.
CONTENT="$INPUT"

FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file_path"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')

if [[ -z "$CONTENT" ]]; then
    exit 0
fi

# Skip this hook for: test fixtures, docs, the hooks themselves, and .example files
if [[ "$FILE_PATH" =~ \.example$ ]] || \
   [[ "$FILE_PATH" =~ /test/ ]] || \
   [[ "$FILE_PATH" =~ /tests/ ]] || \
   [[ "$FILE_PATH" =~ /__tests__/ ]] || \
   [[ "$FILE_PATH" =~ /fixtures/ ]] || \
   [[ "$FILE_PATH" =~ \.claude/hooks/ ]]; then
    exit 0
fi

block() {
    local pattern_name="$1"
    local matched="$2"
    cat <<EOF
🔐 BLOCKED: Likely hardcoded secret

File: ${FILE_PATH}
Pattern: ${pattern_name}
Matched: $(echo "$matched" | head -c 40)...

Do not commit secrets to source control. Alternatives:
1. Put the value in .env.local and read via process.env
2. Use your framework's secret storage (Vercel env, AWS SSM, etc.)
3. If this is a test fixture, put it in a *.example or /fixtures/ path

If this is a false positive (e.g., a documentation example), move the write
target into a path this hook skips (.example, /tests/, /fixtures/).
EOF
    exit 2
}

# AWS Access Key ID
if [[ "$CONTENT" =~ AKIA[0-9A-Z]{16} ]]; then
    block "AWS Access Key ID" "${BASH_REMATCH[0]}"
fi

# AWS Secret Access Key (40 base64-ish chars after "aws_secret" or similar)
if echo "$CONTENT" | grep -Eq 'aws_secret_access_key[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9/+=]{40}'; then
    block "AWS Secret Access Key" "aws_secret_access_key=..."
fi

# Generic long hex tokens labeled as secret/token/key with an assignment
if echo "$CONTENT" | grep -Eq '(secret|token|api[_-]?key|apikey|password)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_\-]{24,}["'"'"']'; then
    block "Hardcoded credential assignment" "secret/token/key = '...'"
fi

# Anthropic API key
if [[ "$CONTENT" =~ sk-ant-[A-Za-z0-9_-]{20,} ]]; then
    block "Anthropic API key" "sk-ant-..."
fi

# OpenAI API key
if [[ "$CONTENT" =~ sk-[A-Za-z0-9]{40,} ]]; then
    block "OpenAI-style API key" "sk-..."
fi

# GitHub token
if [[ "$CONTENT" =~ (ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,} ]]; then
    block "GitHub token" "${BASH_REMATCH[1]}_..."
fi

# Private key blocks
if echo "$CONTENT" | grep -q "BEGIN .*PRIVATE KEY"; then
    block "PEM private key block" "-----BEGIN ...PRIVATE KEY-----"
fi

# Slack token
if [[ "$CONTENT" =~ xox[baprs]-[A-Za-z0-9-]{10,} ]]; then
    block "Slack token" "xox..."
fi

# JWT-looking strings in a .ts/.js/.py/.go file (three base64 segments)
if [[ "$FILE_PATH" =~ \.(ts|tsx|js|jsx|py|go|rb|rs|java)$ ]]; then
    if echo "$CONTENT" | grep -Eq 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'; then
        block "Embedded JWT" "eyJ..."
    fi
fi

exit 0
