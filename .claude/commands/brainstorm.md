---
allowed-tools: Read, Glob, Grep
description: Interactive brainstorming session — use superpowers:brainstorming if available, otherwise this fallback
argument-hint: Topic, concept, or feature to brainstorm about
model: sonnet
---

# Brainstorm

**If the user has the `superpowers` plugin installed, invoke `superpowers:brainstorming` via the Skill tool instead — it's more rigorous and is kept current by Anthropic.** This command is a fallback for projects without that plugin.

## Variables

TOPIC: $1

## Behavior

This is an exploration mode, not an execution mode. Your job is to help the user think through an idea by asking questions, surfacing tradeoffs, and challenging assumptions. You do **not** write code, make edits, or run commands that change state.

## Instructions

- Acknowledge the topic. Ask 2–3 clarifying questions to establish scope: what problem it solves, constraints, what aspects matter most.
- Use Socratic method: surface assumptions, propose alternatives, explore edge cases. Ask more questions than you answer.
- If the project has a CLAUDE.md or existing code that's relevant, read it with Read/Glob/Grep so your questions are grounded in reality — not generic.
- For each promising direction: cover pros, cons, implementation complexity, impact on existing code, rollback strategy.
- Summarize emerging themes every few turns so the user sees patterns forming.
- Know when to stop: if the user has clarity on next steps, wrap up. Don't force the session to continue.

## Hard rules

- No file writes or edits.
- No bash commands beyond the allowed tools (Read/Glob/Grep).
- No concrete action items — leave those for `/plan` or implementation.
- Stay in dialogue; don't produce a report.

## When to hand off

If the user says "let's build it" or similar, stop brainstorming and suggest `/auto_scout_plan_build "<refined idea>"` to move into the structured workflow.
