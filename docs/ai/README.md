# AI Context Pack

These files are for teammates who want to use an AI assistant on TABANG without re-explaining the whole project.

## Which file to give the AI

| File | Use it when |
|---|---|
| `TABANG_AI_CONTEXT.md` | **Start here.** Paste this into the AI first. It is the full human-readable handoff: architecture, entities, rules, screens, backend, constraints and quality gates. |
| `TABANG_AI_CONTEXT.json` | Give this too if the AI can read/parse files or if you are building tooling. It is the same context in machine-readable form. |
| `TABANG_AI_PROMPTS.md` | Copy a ready-made prompt for a bug fix, feature, backend task, test task or code review. |

For backend work, also give:

- `docs/backend/BACKEND_GUIDE.md`
- `docs/backend/TABANG_Backend_Guide.xlsx`
- `docs/backend/supabase_schema.sql`

## Recommended order

1. Attach or paste `TABANG_AI_CONTEXT.md`.
2. Paste the starter prompt from `TABANG_AI_PROMPTS.md`.
3. Add the actual task.
4. If the AI has repository access, say: **“Read the relevant files before editing. Do not guess.”**
5. Require it to run `flutter analyze --no-pub` and `flutter test --no-pub` before saying it is done.

## Important

- The context describes the **base app**, which is still in-memory and has no live backend.
- The Supabase SQL is a **starter**, not an applied migration.
- Do not give an AI the `service_role` key or any private credentials.
- Keep these files updated when the model, backend plan or release changes.

## Current baseline

- App: TABANG 2.1.0
- Tests: 213
- Release tag: `v2.1.0`
- Backend docs: `docs/backend/`