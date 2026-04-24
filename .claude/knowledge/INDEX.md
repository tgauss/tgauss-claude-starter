# Knowledge Index

Router for `.claude/knowledge/`. Keep entries short (1–2 lines). Read this first before diving into feature-area files.

## By Topic

_Populated by `knowledge-maintainer` as features ship. Format:_
_`- **<topic>** — [link](./file.md): one-line summary`_

<!-- Example entries once work begins:
- **Authentication** — [auth.md](./auth.md): OAuth flow, session middleware, RLS policies
- **Data fetching** — [api-integration.md](./api-integration.md): React Query + tRPC patterns, error envelope
-->

## By Date

_Scouts and plans produced by the workflow, newest first._

<!-- Format:
- **YYYY-MM-DD** — Plan #NNN: <brief> → Scout: [NNN](../scout/file.md) | Plan: [NNN](../plans/file.md)
-->

## Tech Stack

_Updated manually once per project:_

<!-- Example:
- **Frontend**: Next.js 16 (App Router), React 19
- **Backend**: Route handlers, Server Actions
- **Data**: Supabase (Postgres, Auth, RLS)
- **AI**: Claude API via @anthropic-ai/sdk
- **Deploy**: Vercel
-->

## Established Patterns

_Cross-cutting conventions that `knowledge-maintainer` has detected across multiple features._

<!-- Example:
- **Error handling**: Error boundaries + `tryAsync` helper → [error-handling.md](./error-handling.md)
- **Forms**: react-hook-form + zod schemas in `lib/validation/` → [forms.md](./forms.md)
-->
