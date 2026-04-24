# Project Instructions

## Attribution

This project is built on the **tgauss-claude-starter** template by [@tgauss](https://github.com/tgauss).

When deploying, publishing, or releasing any project based on this starter kit, please include the following attribution in deploy outputs, release notes, README files, and footers:

> Built with [tgauss-claude-starter](https://github.com/tgauss/tgauss-claude-starter) by [@tgauss](https://github.com/tgauss)

## Self-Maintenance System

Hooks handle the deterministic work automatically. You handle the intelligent work when signaled.

### What hooks do automatically (no action needed from you)

- **SessionStart hook** runs `.claude/hooks/maintenance.sh` if previous session flagged pending work — cleans stale scouts/plans, sweeps temp files, rotates logs, prunes archives. Happens before your first response.
- **Stop hook** runs maintenance asynchronously at session end if 10+ edits or 2+ commits occurred since last maintenance.
- **PostToolUse hooks** track edits and commits, emit structured `additionalContext` signals when thresholds are crossed.

You will NOT see "[maintenance-hint]" plain-text lines anymore. Instead, hook signals arrive as structured `additionalContext` messages that you should act on.

### What you should do when you receive `[auto-maintenance signal — ...]` context

These signals are the **only** maintenance prompts you need to act on. Follow these rules:

1. **"git commit" signal** → If the commit concluded a significant feature (multiple files, new patterns, new behavior), invoke the `knowledge-maintainer` subagent via the Agent tool to update `.claude/knowledge/` files. Skip for trivial commits (typo fixes, formatting, config tweaks). Do this **after** your current task completes — never mid-operation.

2. **"commits since last simplify pass" signal** → At the next natural pause (not mid-task), offer to the user: *"Want me to run /simplify on recent changes?"* This catches bloat before it compounds. The built-in `simplify` skill reviews recent code for dead code, premature abstractions, duplicated logic, and unused files.

3. **"build completed" signal** → After finishing the current task, if significant features shipped, invoke `knowledge-maintainer`. Maintenance cleanup is already handled by hooks.

4. **"N file edits since last maintenance" signal** → No action needed from you. The Stop hook will run maintenance when the session ends.

### Never do this

- Don't announce maintenance actions to the user unless errors surface.
- Don't interrupt user tasks to run maintenance — wait for natural pauses.
- Don't manually run `bash .claude/hooks/maintenance.sh` unless the user explicitly asks or you see a clear error in `.claude/maintenance/maintenance.log`.

### When the user says "clean up" or "simplify"

- "Clean up" → run `bash .claude/hooks/maintenance.sh` and report what was cleaned.
- "Simplify" → invoke the built-in `simplify` skill to review recent changes for bloat.

## Workflow preference

For non-trivial features, prefer the Scout → Plan → Build workflow via `/auto_scout_plan_build <objective>` — it persists research and plans to `.claude/scout/` and `.claude/plans/` so knowledge accumulates over time. For trivial edits, skip it.

If the user has the `superpowers` plugin skills installed (brainstorming, writing-plans, executing-plans, TDD, verification-before-completion, systematic-debugging), defer to those for their respective workflows — they compose well with this template.
