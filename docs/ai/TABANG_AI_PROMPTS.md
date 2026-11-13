# TABANG — Ready-to-paste AI Prompts

Use these after giving the AI `TABANG_AI_CONTEXT.md`.

---

## 1. Universal first message

```text
You are working on TABANG, a Flutter research prototype for blood donation in Digos City.

I have attached/pasted the TABANG AI context. Treat it as the source of truth.

Rules:
- Read the relevant files before editing. Do not guess APIs or field names.
- Make the smallest safe change.
- Do not add Firebase.
- Do not expose full names, emails or phone numbers on community surfaces.
- Do not use a service_role key in the client.
- Do not rebuild APKs or publish releases unless I explicitly ask.
- Run `flutter analyze --no-pub` and `flutter test --no-pub` before declaring success.
- Report exactly what changed, what passed, and any remaining risk.

Task:
[describe the task]
```

---

## 2. Bug fix

```text
Investigate and fix this bug in TABANG:

[symptoms]
[where it happens]
[expected behaviour]

First reproduce or locate the cause in the code. Do not change unrelated behaviour.
Then add or update a regression test, run analyze and the full test suite, and report the root cause.
```

---

## 3. UI / UX change

```text
Make this UI change in TABANG:

[screen]
[what should change]
[desktop/phone expectations]
[light/dark expectations]

Follow the existing shared widgets and theme tokens. Preserve accessibility, responsive behaviour and the established card/pill styles.
Update the relevant widget test and run analyze plus the full test suite.
```

---

## 4. Feature request

```text
Add this feature to TABANG:

[feature]
[who can use it]
[what data it needs]
[what happens when it fails]

Before coding, list the affected model, repository methods, screens, widgets and tests.
Keep one data layer. Do not duplicate state in a screen.
Implement it, add tests, run analyze and the full test suite, and update the README/backend guide if the data model changes.
```

---

## 5. Backend migration task

```text
You are working on the Supabase migration for TABANG.

Read:
- docs/ai/TABANG_AI_CONTEXT.md
- docs/backend/BACKEND_GUIDE.md
- docs/backend/supabase_schema.sql
- the relevant Dart repository/model files

Task:
[one specific migration slice, e.g. auth + profiles, requests read path, verify_request RPC]

Rules:
- auth.users is the only credential store.
- Public screens read donor_directory, blood_units_public and request_public.
- Multi-row workflows are Postgres RPCs.
- Never put service_role in the client.
- Use UUIDs + legacy_id, not count-based IDs.
- Realtime is a notification, not the initial load.
- Treat the SQL as a starter; do not claim it is production-tested without applying it.

Show the schema/RPC change, the Flutter change, and the exact validation steps.
```

---

## 6. Test-writing task

```text
Write tests for this TABANG behaviour:

[behaviour]

Use the existing test style in `test/`. Cover:
- the happy path
- authorization/role boundaries
- invalid or incomplete input
- the state transition that must not happen
- a regression assertion for the bug/feature

Run `flutter test --no-pub` and report the result.
```

---

## 7. Code review

```text
Review this TABANG change for:
- broken eligibility/inventory/privacy rules
- state that can get stuck or duplicated
- authorization gaps
- setState/dispose/async-context errors
- responsive overflow
- missing tests
- backend migration mismatches

Do not rewrite the code unless I ask. Return a prioritized list with file:line, severity and a concrete fix.
```

---

## 8. Backend review

```text
Review this TABANG Supabase schema/RPC against the Dart models and backend guide.

Check:
- every entity/field/derived getter is represented
- cardinalities and uniqueness constraints
- RLS row scopes and PII exposure
- transactional RPC boundaries
- Realtime publication and filters
- Storage policies
- missing indexes and race conditions

Return a gap list with severity and exact SQL changes. Do not claim it is tested unless it was applied to a database.
```

---

## 9. “Explain this code” prompt

```text
Explain this part of TABANG to a new developer:

[file or feature]

Cover:
- what it does
- which models/tables it touches
- which role can use it
- what can go wrong
- which tests protect it

Use the project's vocabulary (chapter, donor handle, coordinating, hold, matched, fulfilled, projection, RPC).
```