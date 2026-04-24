# Getting Started with the tgauss-claude-starter Template

**Last updated: 2026-04-24**

## What Is This?

A starter template that turns Claude Code from a chatty assistant into a structured, self-maintaining development environment. It gives you:

- A three-phase **Scout → Plan → Build** workflow so Claude researches before it codes
- **Deterministic safety hooks** (force-push blocks, credential protection, hardcoded-secret scanner, branch guard)
- **Hook-driven self-maintenance** — stale files cleaned, knowledge base updated, and bloat flagged without you remembering
- **5 custom subagents** (git-wizard, code-reviewer, doc-fetcher, knowledge-maintainer, agent-architect) that compose with Claude Code's built-in `Explore`, `Plan`, and `general-purpose` types
- **~13 slash commands** for workflows, docs, and periodic cleanup
- **`/simplify-sweep`** — a bloat-reduction loop that nothing else in the ecosystem currently bundles

Guardrails + superpowers for Claude Code.

---

## Prerequisites

1. **Install Claude Code** — CLI, desktop app (Mac/Windows), web at claude.ai/code, or IDE extensions (VS Code, JetBrains). [Official install](https://code.claude.com/docs/en/setup).
2. **Git** — installed and configured.
3. **Node.js 20+** — only needed if you plan to use the bundled doc-fetcher MCP server (optional).

---

## Setup

### 1. Clone

```bash
git clone https://github.com/tgauss/tgauss-claude-starter my-project
cd my-project
```

### 2. (Optional) Build the doc-fetcher MCP server

Only if you plan to use `/fetch-docs`. Most projects don't need this now — the ecosystem has better options (see "Recommended plugins" below).

```bash
cd .claude/mcp-servers/doc-fetcher && npm install && npm run build && cd ../../..
```

### 3. Recommended plugins (install once, benefit every project)

These are Anthropic-official plugins I recommend on top of the template:

```bash
claude plugin install superpowers       # brainstorming, writing-plans, TDD, systematic-debugging, verification-before-completion
claude plugin install code-simplifier   # dedicated simplify agent (same one Anthropic uses internally)
```

The template **already references these by name** in CLAUDE.md and `/simplify-sweep`. When they're installed, hooks and commands use them automatically. When they're not, the template degrades gracefully to its own fallbacks.

### 4. Start Claude Code

```bash
claude
```

CLAUDE.md and `.claude/settings.json` are picked up automatically. All hooks, agents, and commands are active immediately.

---

## The Core Workflow: Scout → Plan → Build

Disciplined three-phase approach instead of "hey Claude, build a thing."

### Fastest — one approval gate

```
/auto_scout_plan_build "Add user auth with OAuth"
```

Claude scouts the codebase using the built-in `Explore` subagent, writes a plan via the built-in `Plan` subagent, shows you a combined summary with a risk-weighted complexity score, then builds after your approval.

### Traditional — three approval gates

```
/scout "..."     # review the scout report in .claude/scout/
/plan "..."      # review the plan in .claude/plans/
/build
```

### Why this matters

- **Scout** prevents Claude from making assumptions — it reads code first.
- **Plan** gives you an approval gate. You see exactly what's about to happen.
- **Build** executes with progress tracking and quality checks.

Scout reports and plans persist in `.claude/scout/` and `.claude/plans/`, so knowledge accumulates across sessions.

---

## Key Slash Commands

| Command | What it does |
|---------|-------------|
| `/auto_scout_plan_build "<obj>"` | Autonomous scout + plan, single approval gate, then build |
| `/scout` / `/plan` / `/build` | Manual three-phase workflow |
| `/review` | Comprehensive code review (Pragmatic Quality framework) |
| `/security-review` | HIGH-confidence security vulnerabilities only |
| `/simplify-sweep` | **Periodic bloat cleanup** — chain simplify + dead-code + knowledge audit + unused-skill detection |
| `/brainstorm "<topic>"` | Exploratory dialogue (defers to `superpowers:brainstorming` if installed) |
| `/fetch-docs`, `/update-docs`, `/track-docs` | External documentation management |
| `/meta_command` / meta-agent | Create new commands / subagents |

---

## Safety: hooks that fire deterministically

Claude Code text-based hints are cosmetic — they often get ignored. This template's hooks exit with status 2 (block) or emit structured `additionalContext` that Claude Code reliably picks up.

### PreToolUse (blocks before execution)

| Hook | Blocks |
|------|--------|
| `validate-bash-command.sh` | `rm -rf /`, fork bombs, `curl \| bash`, `dd`, `mkfs` |
| `protect-git-operations.sh` | Force push to `main`/`master`/etc., `git reset --hard`, history rewrites |
| `protect-sensitive-files.sh` | Editing `.env`, credentials, lock files, certs, SSH keys |
| `prevent-credential-exposure.sh` | Reading credential files |
| `block-hardcoded-secrets.sh` | AWS keys, Anthropic/OpenAI/GitHub tokens, JWTs, PEM blocks in source |
| `branch-guard.sh` | (warns, not blocks) Edits while on protected branches — prompts Claude to confirm |

### PostToolUse / SessionStart / Stop (self-maintenance)

- **SessionStart**: runs `maintenance.sh` if previous session flagged pending work
- **PostToolUse (Bash)**: detects commits, builds; emits structured signals
- **Stop**: runs maintenance async at session end if thresholds crossed
- **Every 10 commits**: a "simplify sweep" signal is emitted, prompting `/simplify-sweep`
- **Every 25 edits**: a quiet maintenance-due signal

You don't configure any of this. It just works.

---

## The Self-Maintenance System (how it actually works)

Unlike version 1 of this template, maintenance is **deterministic** — hooks do the work; Claude doesn't have to remember.

1. **Edits tracked** → `.claude/maintenance/change-log.jsonl`
2. **Thresholds crossed** → `[auto-maintenance signal]` context delivered to Claude
3. **Session ends with meaningful work** → Stop hook runs `maintenance.sh` (async)
4. **Next session starts** → SessionStart hook runs `maintenance.sh` if pending
5. **`maintenance.sh`** cleans: stale scouts (>30d), completed plans (>30d), temp files (>7d), archived logs (>90d), rotates change log at 500 entries, flags stale knowledge files (>60d), flags bloat for `/simplify-sweep`

Maintenance log: `.claude/maintenance/maintenance.log`

---

## Directory Map

```
.claude/
├── settings.json          # permissions, hooks config (committed)
├── agents/                # 5 custom subagents
├── commands/              # ~13 slash commands
├── hooks/                 # 9 hook scripts + maintenance.sh
├── knowledge/
│   ├── INDEX.md           # router (progressive disclosure)
│   ├── README.md          # conventions
│   └── external/          # cached docs (optional)
├── mcp-servers/doc-fetcher/   # optional
├── maintenance/           # runtime state (gitignored)
├── plans/                 # persistent plans
└── scout/                 # persistent research
```

---

## Tips

1. **Always start with `/auto_scout_plan_build`** — the fastest path to well-structured code.
2. **Install `superpowers` and `code-simplifier` plugins** — they compose with this template.
3. **Run `/simplify-sweep` every ~10 commits** — the hooks will nudge you.
4. **Trust the maintenance system** — if you see `[auto-maintenance signal]` in context, hooks are working. Act on it at the next pause.
5. **Don't hand-edit `settings.json`** unless you know what you're doing.

---

## Why this template stays useful in 2026

| Problem | How this template solves it |
|---------|-----------------------------|
| Claude hallucinates architecture | Scout phase forces codebase-first research |
| Dangerous commands slip through | 6 hard-blocking PreToolUse hooks |
| Claude "forgets" maintenance | Deterministic SessionStart/Stop hooks do it for him |
| Feature sprawl over time | `/simplify-sweep` + 10-commit bloat detection |
| Knowledge base goes stale | `knowledge-maintainer` auto-invoked after significant commits |
| Template goes stale as Claude Code evolves | Explicit plugin recommendations (superpowers, code-simplifier) — Anthropic maintains those |

---

> Built with [tgauss-claude-starter](https://github.com/tgauss/tgauss-claude-starter) by [@tgauss](https://github.com/tgauss)
