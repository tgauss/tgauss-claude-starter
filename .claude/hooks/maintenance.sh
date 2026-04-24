#!/bin/bash
#
# Project Maintenance Script
#
# Runs automatically from SessionStart and Stop hooks when thresholds are met.
# Also callable manually: bash .claude/hooks/maintenance.sh [--dry-run]
#
# Actions (all deterministic — no Claude required):
#   1. Clean old scout reports (>30 days)
#   2. Clean completed plans (>30 days)
#   3. Sweep temp/scratch files
#   4. Rotate change log (archive if >500 lines)
#   5. Prune archived logs (>90 days)
#   6. Report stale knowledge files (>60 days)
#   7. Check bloat thresholds → flag for simplify pass
#   8. Reset tracking counters

PROJECT_ROOT="$(pwd)"
MAINT_DIR="${PROJECT_ROOT}/.claude/maintenance"
STATE_FILE="${MAINT_DIR}/state.json"
CHANGE_LOG="${MAINT_DIR}/change-log.jsonl"
SCOUT_DIR="${PROJECT_ROOT}/.claude/scout"
PLANS_DIR="${PROJECT_ROOT}/.claude/plans"
KNOWLEDGE_DIR="${PROJECT_ROOT}/.claude/knowledge"
SCRATCH_DIR="${PROJECT_ROOT}/.claude/scratch"

DRY_RUN=false
[[ "$1" == "--dry-run" ]] && DRY_RUN=true

mkdir -p "$MAINT_DIR"

echo "=========================================="
echo "  Project Maintenance Report"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

CLEANED_SCOUTS=0
CLEANED_PLANS=0
CLEANED_TEMPS=0
CLEANED_LOGS=0
LOG_ROTATED=false
SIMPLIFY_FLAGGED=false

# Portable stat (macOS + Linux)
file_mtime() {
    stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}
age_days() {
    local mtime=$1
    echo $(( ( $(date +%s) - mtime ) / 86400 ))
}
sed_inplace() {
    sed -i '' "$1" "$2" 2>/dev/null || sed -i "$1" "$2" 2>/dev/null
}

# ---- 1. Scout reports cleanup ----
echo ""
echo "## Scout Reports (>30 days)"
if [[ -d "$SCOUT_DIR" ]]; then
    while IFS= read -r -d '' file; do
        [[ "$(basename "$file")" == "README.md" ]] && continue
        MT=$(file_mtime "$file"); [[ -z "$MT" ]] && continue
        AGE=$(age_days "$MT")
        if [[ $AGE -gt 30 ]]; then
            if $DRY_RUN; then echo "  [dry] would remove $(basename "$file") (${AGE}d)"
            else rm "$file" && echo "  removed $(basename "$file") (${AGE}d)"
            fi
            CLEANED_SCOUTS=$((CLEANED_SCOUTS + 1))
        fi
    done < <(find "$SCOUT_DIR" -name "*.md" -not -name "README.md" -print0 2>/dev/null)
fi
[[ $CLEANED_SCOUTS -eq 0 ]] && echo "  none"

# ---- 2. Completed plans cleanup ----
echo ""
echo "## Completed Plans (>30 days)"
if [[ -d "$PLANS_DIR" ]]; then
    while IFS= read -r -d '' file; do
        [[ "$(basename "$file")" == "README.md" ]] && continue
        MT=$(file_mtime "$file"); [[ -z "$MT" ]] && continue
        AGE=$(age_days "$MT")
        [[ $AGE -le 30 ]] && continue
        if grep -qi "Status.*Completed\|status:.*completed" "$file" 2>/dev/null; then
            if $DRY_RUN; then echo "  [dry] would remove completed $(basename "$file") (${AGE}d)"
            else rm "$file" && echo "  removed completed $(basename "$file") (${AGE}d)"
            fi
            CLEANED_PLANS=$((CLEANED_PLANS + 1))
        fi
    done < <(find "$PLANS_DIR" -name "*.md" -not -name "README.md" -print0 2>/dev/null)
fi
[[ $CLEANED_PLANS -eq 0 ]] && echo "  none"

# ---- 3. Temp/scratch cleanup ----
echo ""
echo "## Temp / Scratch Files"

# .claude/scratch/ — anything >7 days
if [[ -d "$SCRATCH_DIR" ]]; then
    while IFS= read -r -d '' file; do
        MT=$(file_mtime "$file"); [[ -z "$MT" ]] && continue
        AGE=$(age_days "$MT")
        if [[ $AGE -gt 7 ]]; then
            if $DRY_RUN; then echo "  [dry] would remove scratch $(basename "$file") (${AGE}d)"
            else rm "$file" && echo "  removed scratch $(basename "$file") (${AGE}d)"
            fi
            CLEANED_TEMPS=$((CLEANED_TEMPS + 1))
        fi
    done < <(find "$SCRATCH_DIR" -type f -print0 2>/dev/null)
fi

# Stale .tmp / .bak in project root (>7 days, not inside node_modules / .git)
while IFS= read -r -d '' file; do
    MT=$(file_mtime "$file"); [[ -z "$MT" ]] && continue
    AGE=$(age_days "$MT")
    if [[ $AGE -gt 7 ]]; then
        if $DRY_RUN; then echo "  [dry] would remove tmp $file (${AGE}d)"
        else rm "$file" && echo "  removed tmp $file (${AGE}d)"
        fi
        CLEANED_TEMPS=$((CLEANED_TEMPS + 1))
    fi
done < <(find "$PROJECT_ROOT" -maxdepth 3 \( -name "*.tmp" -o -name "*.bak" -o -name "*~" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" \
    -print0 2>/dev/null)

[[ $CLEANED_TEMPS -eq 0 ]] && echo "  none"

# ---- 4. Change log rotation ----
echo ""
echo "## Change Log"
if [[ -f "$CHANGE_LOG" ]]; then
    LOG_LINES=$(wc -l < "$CHANGE_LOG" | tr -d ' ')
    echo "  current entries: ${LOG_LINES}"
    if [[ $LOG_LINES -gt 500 ]]; then
        ARCHIVE_FILE="${MAINT_DIR}/change-log-$(date +%Y%m%d).jsonl.old"
        if $DRY_RUN; then
            echo "  [dry] would archive to $(basename "$ARCHIVE_FILE") and keep last 100"
        else
            cp "$CHANGE_LOG" "$ARCHIVE_FILE"
            tail -100 "$CHANGE_LOG" > "${CHANGE_LOG}.tmp" && mv "${CHANGE_LOG}.tmp" "$CHANGE_LOG"
            echo "  archived to $(basename "$ARCHIVE_FILE"); kept last 100"
            LOG_ROTATED=true
        fi
    fi
fi

# ---- 5. Prune old archived logs (>90 days) ----
if [[ -d "$MAINT_DIR" ]]; then
    while IFS= read -r -d '' file; do
        MT=$(file_mtime "$file"); [[ -z "$MT" ]] && continue
        AGE=$(age_days "$MT")
        if [[ $AGE -gt 90 ]]; then
            if $DRY_RUN; then echo "  [dry] would prune old archive $(basename "$file") (${AGE}d)"
            else rm "$file" && echo "  pruned old archive $(basename "$file") (${AGE}d)"
            fi
            CLEANED_LOGS=$((CLEANED_LOGS + 1))
        fi
    done < <(find "$MAINT_DIR" -name "*.jsonl.old" -print0 2>/dev/null)
fi

# ---- 6. Stale knowledge files ----
echo ""
echo "## Knowledge Files (>60 days since update)"
if [[ -d "$KNOWLEDGE_DIR" ]]; then
    STALE=0
    while IFS= read -r -d '' file; do
        BN=$(basename "$file")
        [[ "$BN" == "README.md" || "$BN" == "meta-index.md" ]] && continue
        MT=$(file_mtime "$file"); [[ -z "$MT" ]] && continue
        AGE=$(age_days "$MT")
        if [[ $AGE -gt 60 ]]; then
            echo "  stale (${AGE}d): $BN"
            STALE=$((STALE + 1))
        fi
    done < <(find "$KNOWLEDGE_DIR" -maxdepth 1 -name "*.md" -print0 2>/dev/null)
    [[ $STALE -eq 0 ]] && echo "  all current"
fi

# ---- 7. Bloat detection for simplify pass ----
echo ""
echo "## Simplify Check"
if [[ -f "$STATE_FILE" ]]; then
    SIMPLIFY_COUNT=$(grep -o '"commits_since_last_simplify"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$')
    SIMPLIFY_COUNT=${SIMPLIFY_COUNT:-0}
    if [[ $SIMPLIFY_COUNT -ge 10 ]]; then
        echo "  ${SIMPLIFY_COUNT} commits since last simplify — flagged for review"
        SIMPLIFY_FLAGGED=true
    else
        echo "  ${SIMPLIFY_COUNT}/10 commits since last simplify"
    fi
fi

# ---- 8. Reset state ----
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if ! $DRY_RUN && [[ -f "$STATE_FILE" ]]; then
    sed_inplace "s/\"edits_since_last_maintenance\"[[:space:]]*:[[:space:]]*[0-9]*/\"edits_since_last_maintenance\":0/" "$STATE_FILE"
    sed_inplace "s/\"commits_since_last_maintenance\"[[:space:]]*:[[:space:]]*[0-9]*/\"commits_since_last_maintenance\":0/" "$STATE_FILE"
    sed_inplace "s/\"last_maintenance_ts\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"last_maintenance_ts\":\"${TS}\"/" "$STATE_FILE"
    sed_inplace "s/\"maintenance_pending\"[[:space:]]*:[[:space:]]*true/\"maintenance_pending\":false/" "$STATE_FILE"
fi

echo ""
echo "=========================================="
echo "  Summary"
echo "=========================================="
echo "  Scouts cleaned:    ${CLEANED_SCOUTS}"
echo "  Plans cleaned:     ${CLEANED_PLANS}"
echo "  Temp files:        ${CLEANED_TEMPS}"
echo "  Archive logs:      ${CLEANED_LOGS}"
echo "  Log rotated:       ${LOG_ROTATED}"
echo "  Simplify needed:   ${SIMPLIFY_FLAGGED}"
echo "=========================================="
