# Knowledge Base

Living documentation about specific feature areas, patterns, and utilities in **your** project. This template ships empty — `knowledge-maintainer` fills it as you build.

## Principle: progressive disclosure

`INDEX.md` is a **router**, not an encyclopedia. Heavy feature-area files load only when relevant. The goal:

- Fast context for Claude (short index, summaries)
- Deep detail on demand (Claude reads the specific file it needs)
- Minimal context bloat over time

## Structure

```
.claude/knowledge/
├── INDEX.md                   # router: topics → files (auto-updated)
├── README.md                  # this file
├── <feature-area>.md          # one file per feature area
└── external/                  # cached third-party docs (optional)
```

Naming: kebab-case feature areas (`authentication.md`, `state-management.md`, `api-integration.md`).

## How knowledge files get written

You don't write these by hand. The `knowledge-maintainer` subagent is invoked automatically when:

- A git commit concludes a significant feature (multiple files, new pattern, new behavior) — PostToolUse hook signals Claude to invoke it
- A build completes successfully
- The user explicitly asks to document something

Trivial commits (typos, formatting, config tweaks) skip this step.

## What belongs here

- How a feature area is architected
- Key utility functions with usage examples
- Established patterns (forms, API calls, error handling, etc.)
- Gotchas, edge cases, non-obvious decisions

## What does NOT belong here

- Generic framework documentation — use `external/` or install official docs MCP
- Your personal opinions or TODO lists — use git history and issues
- Code snippets for one-off problems — those belong in the code itself
- Anything a new developer would derive from reading the code in 5 minutes

## File structure (for when one gets written)

```markdown
# <Feature Area>

**Last Updated**: YYYY-MM-DD

## Overview
One paragraph: what this feature area does, why it exists.

## Architecture
How it's structured; integration points; data flow.

## Key Files
- `path/to/file.ts` — what it does
- `path/to/other.tsx` — what it does

## Patterns
### <Pattern Name>
When to use, how to implement, why this way.

## Gotchas
Non-obvious constraints future readers will trip on.

## Change Log
- YYYY-MM-DD: <what changed and why>
```

## Workflow integration

- **Scout** (`/scout`) — reads INDEX.md first to avoid re-researching what's documented
- **Plan** (`/plan`) — references established patterns from knowledge files
- **Build** (`/build`) — hooks signal `knowledge-maintainer` to update after significant commits
- **Simplify** (bloat detection) — hooks signal `/simplify` at every 10 commits
