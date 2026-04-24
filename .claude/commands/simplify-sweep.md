---
description: Periodic bloat sweep — chain simplify + dead-code + knowledge audit + unused-skill detection. Run every ~10 commits or when the project feels heavy.
category: maintenance
version: 1.0.0
allowed-tools: Skill, Agent, Read, Edit, Grep, Glob, Bash
argument-hint: [optional scope hint — e.g., "frontend only", "recent changes"]
model: sonnet
---

# Simplify Sweep

Combat feature sprawl. Chain four narrow passes that, together, catch the bloat that's hard to see when you're moving fast. Runs the built-in `simplify` skill plus three additional audits that nothing else currently bundles.

## Variables

SCOPE: $1 (optional — if blank, sweeps all recent changes)

## Instructions

Execute each pass in order. After each pass, report a one-line summary to the user. **Never merge findings across passes** — each has its own lens, and mixing them loses the signal.

### Pass 1 — Simplify recent code

Invoke the built-in `simplify` skill via the Skill tool. Focus on files changed in the last 10 commits (or matching SCOPE). The skill reviews for:
- Dead code / unused exports
- Premature abstractions (wrappers around wrappers, single-use helpers)
- Duplicated logic across 2+ files
- Boolean-prop proliferation in components

Report: "Pass 1 (simplify): N findings — M already fixed."

### Pass 2 — Dead-code scan

Search for exports that are never imported, after the `simplify` skill has had its pass:

```bash
# Find all exports
grep -r "^export " --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" -n

# Then for each one, grep for imports. If zero hits outside its own file → candidate for removal.
```

Output a list of candidates with file:line. Do **not** auto-delete — surface them as a list for the user to approve.

Report: "Pass 2 (dead-code): N candidates for removal."

### Pass 3 — Knowledge base audit

Read `.claude/knowledge/INDEX.md` and each knowledge file. Flag:
- Files whose "Last Updated" is >60 days old
- Files describing code paths that no longer exist (grep for referenced file paths; if missing, the knowledge is stale)
- Duplicate knowledge — the same pattern documented in 2+ files

Report: "Pass 3 (knowledge): N stale files, M broken references, K duplicates."

If anything found, offer to have `knowledge-maintainer` update them.

### Pass 4 — Unused skills / agents / commands

List files under `.claude/agents/` and `.claude/commands/`. For each:
- Grep for invocations in git history (last 90 days): `git log --all --since="90 days ago" -p | grep -c "<skill-name>"`
- If zero invocations AND file isn't a core workflow (scout/plan/build/review), flag as unused.

Per Vercel's eval finding (2025): skills unused in 56% of test cases. Pruning reduces context load and future-proofs the template.

Report: "Pass 4 (unused): N agents, M commands with zero invocations in 90 days. Candidates for archival."

### Final step — reset simplify counter

After completing all four passes, run:

```bash
sed -i '' 's/"commits_since_last_simplify"[[:space:]]*:[[:space:]]*[0-9]*/"commits_since_last_simplify":0/' .claude/maintenance/state.json 2>/dev/null || \
sed -i 's/"commits_since_last_simplify"[[:space:]]*:[[:space:]]*[0-9]*/"commits_since_last_simplify":0/' .claude/maintenance/state.json 2>/dev/null

# Also stamp last_simplify_ts
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
sed -i '' "s/\"last_simplify_ts\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"last_simplify_ts\":\"${TS}\"/" .claude/maintenance/state.json 2>/dev/null || \
sed -i "s/\"last_simplify_ts\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"last_simplify_ts\":\"${TS}\"/" .claude/maintenance/state.json 2>/dev/null
```

## Final Report

```markdown
# Simplify Sweep Report

**Scope**: {SCOPE or "all recent changes"}

## Pass 1 — Simplify
- Findings: N
- Auto-fixed: M
- Still open: K

## Pass 2 — Dead code
- Candidates: N (see list below; user to approve removal)

## Pass 3 — Knowledge
- Stale files: N
- Broken references: M
- Duplicates: K

## Pass 4 — Unused skills/agents
- Zero-invocation candidates: N

## Recommended next actions
- [ ] <specific file> — <specific action>
- [ ] ...
```

## When to use

- After the `[auto-maintenance signal — N commits since last simplify pass]` context appears (every 10 commits)
- Before shipping to production
- When the project "feels heavy" (long builds, hard to navigate, you forget what files do)
- Once a month as a scheduled routine — `/schedule` can automate this

## When to skip

- Actively mid-feature (wait for next natural pause)
- Right after a merge (let the dust settle)
- If last sweep was <7 days ago (premature)
