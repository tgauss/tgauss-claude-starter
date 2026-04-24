# Changelog

## 2026-04-24 — 2026 Modernization Pass

Comprehensive review and upgrade of the template. Hooks now enforce deterministically instead of relying on text hints. Added research-driven additions based on 2026 community-consensus patterns and Anthropic-official plugins.

---

### Self-maintenance pipeline — now actually fires

Previously: hooks printed `[maintenance-hint]` text that Claude frequently ignored. Cleanup and knowledge updates rarely ran.

Now: hooks do the deterministic work; Claude only does the intelligent work on structured signals.

- **Added `session-start-maintenance.sh`** (new SessionStart hook) — runs `maintenance.sh` synchronously at session start if previous session flagged pending work. No reliance on Claude reading CLAUDE.md.
- **Rewrote `session-end-maintenance.sh`** — now actually *runs* `maintenance.sh` asynchronously when thresholds exceeded (10+ edits or 2+ commits). Previously only flagged state.
- **Rewrote `detect-maintenance-events.sh`** — emits structured JSON `hookSpecificOutput` with `additionalContext` instead of plain-text hints. Claude Code surfaces these reliably. Detects `pnpm` and `yarn` builds in addition to `npm`.
- **Rewrote `track-file-changes.sh`** — 25-edit threshold nudge now uses structured JSON output.
- **Expanded `maintenance.sh`** — added temp/scratch cleanup (`.claude/scratch/`, stale `.tmp`/`.bak`/`~` files in project root), archived-log pruning (>90 days), bloat detection (tracks commits since last simplify), portable stat/sed helpers for macOS + Linux.
- **Updated `.claude/maintenance/state.json`** — new schema with `last_simplify_ts` and `commits_since_last_simplify` fields.

### New safety hooks (community-consensus "must-haves")

- **Added `block-hardcoded-secrets.sh`** (PreToolUse Write/Edit) — blocks commits containing AWS Access Key IDs, AWS Secret Access Keys, Anthropic API keys (`sk-ant-*`), OpenAI keys (`sk-*`), GitHub tokens (`ghp_*`/`gho_*`/`ghu_*`/`ghs_*`/`ghr_*`), Slack tokens, JWTs in source files, and PEM private key blocks. Skips `*.example`, `/tests/`, `/fixtures/`, and the hooks directory.
- **Added `branch-guard.sh`** (PreToolUse Edit/Write) — warns (doesn't block) when editing while on protected branches (main/master/production/prod/develop/development). Emits `additionalContext` prompting Claude to confirm with user before proceeding.

### New commands

- **Added `/simplify-sweep`** — periodic bloat-reduction loop nothing else in the ecosystem currently bundles. Chains 4 passes:
  1. Built-in `simplify` skill on recent changes
  2. Dead-code scan (exports never imported)
  3. Knowledge base audit (stale files >60d, broken references, duplicates)
  4. Unused skills/agents/commands detection (zero invocations in 90 days)
  
  Auto-triggered by hooks every 10 commits. Resets the commits-since-last-simplify counter on completion.

### Bugs fixed

- **`settings.json` permissions** — removed invalid types (`FileEdit(*)`, `FileView(*)`, `Git(*)` — all no-ops in current Claude Code). Restored `Bash(cat:*)` and `Bash(*)` per user request (speed matters; deny rules + hooks still enforce safety on top).
- **`settings.json` hooks** — replaced `test -f` with `test -x` guards (verifies executable bit), collapsed duplicate Edit/Write matchers into `Edit|Write`, added SessionStart event, wired the two new hooks.
- **`meta-agent.md`** — renamed from `meta_agent.md` so filename matches the `name:` frontmatter. Removed references to unavailable `mcp__firecrawl-mcp__*` tools.
- **`meta_command.md`** — removed references to unavailable firecrawl tools.
- **`review.md`** — removed invalid tool references (`ListMcpResourcesTool`, `ReadMcpResourceTool`, `TodoWrite`, `MultiEdit`, `BashOutput`, `KillBash`, `LS`, `NotebookEdit`). Replaced `Task` with `Agent`.
- **`build.md`** — changed project-specific `npm run typecheck:prod` to generic `npm run typecheck`.
- **All hook scripts** — ensured executable bit set via `chmod +x`.

### Decontamination (removed Carbon UI / project-specific content)

- **`git-wizard.md`** — full rewrite. Removed hardcoded fork workflow (`origin`/`upstream`), hardcoded `development` branch assumption, sequential branch numbering scheme (`938-EP-1969-...`), Carbon UI PR template. Now agnostic to git workflow; asks user for conventions.
- **`brainstorm.md`** — removed Carbon UI references. Added note at top recommending `superpowers:brainstorming` when available.
- **`agent-architect.md`** — removed hardcoded "Next.js + Supabase + Vercel + Claude API" stack assumption and the "British workshop master" character voice. Now reads project stack from `INDEX.md` or asks user.
- **`doc-fetcher/package.json`** — renamed from `@carbon-ui/doc-fetcher-mcp` to `tgauss-doc-fetcher-mcp`; author updated from "Carbon UI Team" to "tgauss".
- **`.claude/knowledge/README.md`** — full rewrite. Removed listing of ~12 Carbon UI-specific knowledge files that didn't exist in the template. Added progressive-disclosure principle and file structure template.

### Knowledge base — progressive disclosure pattern

- **Renamed `meta-index.md` → `INDEX.md`** — matches 2026 community-consensus naming; reframed as a *router*, not an encyclopedia.
- **Updated `INDEX.md`** — new structure with By Topic, By Date, Tech Stack, and Established Patterns sections as empty templates for `knowledge-maintainer` to populate over time.
- **Updated `scout.md`, `plan.md`, `auto_scout_plan_build.md`** — all references to `meta-index.md` changed to `INDEX.md`.

### Documentation rewrites

- **`CLAUDE.md`** — rewritten to reflect hook-driven behavior. Explicit rules for how Claude should respond to each `[auto-maintenance signal — …]` context type (git commit, simplify threshold, build completed, edit threshold). Softened attribution from mandatory to requested.
- **`GETTING-STARTED.md`** — rewritten for 2026. Added "Recommended plugins" section pointing to `superpowers` and `code-simplifier` (Anthropic-official). Updated command list (~13 commands now). Updated safety-hook table (6 PreToolUse hooks). Added self-maintenance explanation showing the deterministic pipeline.
- **`.claude/README.md`** — updated "Last Updated" to 2026-04-24.
- **`CHANGELOG.md`** — this file, added.

### Research informing the changes

Two parallel research agents ran during the review:

1. **Current Claude Code best practices (2026)** — confirmed `FileEdit(*)`/`FileView(*)` are invalid, that structured hook JSON (`additionalContext`, `systemMessage`) is the right signaling mechanism, that `superpowers` is the canonical plugin for meta-skills, and that `code-simplifier` is Anthropic's official simplification plugin.
2. **Community template benchmarking** — surfaced the "consensus-7 hooks" pattern (we now have 6 of 7; format-on-save is project-dependent), the "INDEX.md as router" convention, and the observation that no existing template bundles a periodic simplify/bloat-sweep loop — motivating `/simplify-sweep`.

Key doctrine applied: **"Hooks for enforcement, CLAUDE.md for judgment."** CLAUDE.md instructions degrade after `/compact`; hooks fire mechanically every time.

---

## Inventory after this pass

**Custom subagents (5):** agent-architect, code-reviewer, doc-fetcher, git-wizard, knowledge-maintainer, meta-agent

**Slash commands (13):** auto_scout_plan_build, brainstorm, build, fetch-docs, meta_command, plan, review, scout, scout_plan_build, security-review, simplify-sweep, track-docs, update-docs

**Hooks (11 scripts + tests + maintenance):**
- PreToolUse: validate-bash-command, protect-git-operations, prevent-credential-exposure, protect-sensitive-files, block-hardcoded-secrets, branch-guard
- PostToolUse: track-file-changes, detect-maintenance-events
- SessionStart: session-start-maintenance
- Stop: session-end-maintenance
- Callable: maintenance.sh
- Tests: test-all-hooks.sh, test-hook.sh

**MCP servers:** doc-fetcher (optional; build with `npm install && npm run build`)

---

## Intentionally not touched

- **Ruby Scaffold agent methodology** (`.claude/knowledge/agent-methodology/`, 9 files, ~136KB) — opinionated but coherent; delete per-project if not wanted.
- **doc-fetcher MCP server implementation** — left functional; consider replacing with Context7 or official docs MCP in future.
- **Attribution in CLAUDE.md** — softened to "please include" but kept.
