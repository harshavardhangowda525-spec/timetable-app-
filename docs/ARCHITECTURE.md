# INFINITY OS — Architecture

## Layout of the Floot project

```
pages/            one file per route (_index = Command Center, timetable, business, habits,
                  manifestation, reading, journal, coach, goals, analytics, settings,
                  login, onboarding) + .pageLayout.tsx ([UserRoute, AppShell])
components/       AppShell (sidebar + mobile bottom nav + FAB), ProgressRing, WeekStrip,
                  IconTile, NeuCard, PageHeader, BusinessCharts, BlockEditorDialog,
                  TemplatesSheet, QuickAddSheet, NotificationBell, RichTextEditor, DatePicker
helpers/          pure logic (tested) + server helpers + React Query hooks
endpoints/        serverless GET/POST handlers, each with a zod .schema.ts
static/__dev/     design principles, build plan, scheduled-jobs.json
```

## Design system

Dark neumorphism ("soft-machined command console"), matched to the owner's reference mockup:
charcoal slab, paired light/dark shadows (`--neu-raised`, `--neu-inset`), one electric-cyan
signal with glow, violet for history/comparison, coral only for partial/alerts. Sora (display)
and Manrope (UI). Dark is the default; light mode is opt-in.

The chart palette (`--chart-color-1..5`) was checked with a colour-blind-safety validator in both
modes (lightness band, chroma, CVD separation, contrast).

## Data flow

```
Browser ── React Query ──► /_api/<route> (endpoint)
                               │  serverApi.withUser(): resolves user from the session cookie
                               ▼
                         helpers (timetableServer, metricsServer, coachServer …)
                               ▼
                         Postgres (every query filtered by user_id)
```

* Dates are keyed as `YYYY-MM-DD` in **Asia/Kolkata** (`helpers/istDate`).
* Timetable: a weekday resolves to one active template; its blocks plus that date's one-time
  blocks form the day. Per-day state lives in `activity_logs` (unique per user + block + date).

## Security model

Floot has no Postgres RLS, so isolation is enforced in the application layer:

1. Every app endpoint runs through `serverApi.withUser`, which derives the user **only** from the
   server-side session. No endpoint accepts a user id from the client.
2. Every read/write includes `where user_id = <session user>`. Referenced ids (block, goal,
   lead, invoice …) are ownership-checked before use.
3. All input is validated with zod on the server. Arrays are bounded.
4. Journal rich text is sanitised server-side (whitelist, attributes stripped) before storage.
5. Account deletion cascades through every user-owned table (verified via `information_schema`).
6. AI calls run server-side only. Journal text is sent **only** when both the global consent
   (Settings) and the per-entry switch are on. Reading-lesson text requires its own consent.
7. Secrets are Floot-managed environment variables, never shipped to the browser.

## Weekly AI Coach pipeline

1. `computeMetrics(user, week)` aggregates timetable, study, allocation, sales funnel, projects,
   reading, journal, sleep, habits and the weighted score. Pure maths, no AI.
2. The same for up to 3 previous weeks, for comparison.
3. `buildDeterministicReport` produces the scorecard (with formulas), improvements, bottlenecks,
   data gaps, rule-based recommendations and next-week targets. Each one requires a minimum
   amount of data.
4. A structured payload goes to `gpt-6-luna` with a strict JSON schema (`AI_REPORT_JSON_SCHEMA`).
5. `validateAiReport` checks the response against the zod schema. Schedule changes must
   reference a known block, keep its duration and stay outside the sleep window. If they don't,
   they are downgraded to advice.
6. If the AI fails for any reason, the deterministic report is stored instead (`source =
   deterministic`, `ai_error` recorded). No AI text is fabricated.
7. The review is upserted (unique `user_id + week_start`). Pending recommendations are replaced,
   decided ones are kept. Recommendations whose fingerprint was previously rejected are filtered out.
8. Accept: a timetable change is re-checked against the current schedule (overlaps + sleep
   window) before it's applied. Reject: the fingerprint is stored and not suggested again.
9. Manual regeneration: max 4 per week, at least 10 minutes apart. Automatic: Sundays 19:30 IST.

## Productivity score

`score = Σ component × weight / Σ weights of components that have data`

| Component | Measure |
|---|---|
| Essential tasks | completed ÷ scheduled high-priority blocks |
| Academic | completed ÷ scheduled study blocks |
| Business effort | mean(outreach-target attainment, business-block completion). Clients and revenue are reported separately |
| Reading & reflection | mean(reading days, journal days) ÷ tracked days |
| Sleep & recovery | nights meeting target ÷ nights logged |

Weights are user-editable (defaults 25/20/25/10/20). The UI labels it an organisational
indicator, not a measure of worth.

## Sleep-conflict handling

The founder template starts at 03:00 and ends at 21:10. `analyzeSleep` computes at most
5h 35m of sleep after a 15-minute wind-down, 2h 25m short of an 8h target. Onboarding shows this
and recommends a sleep-safe template (05:00 wake, 21:00 lights-out, every activity kept). The
original can still be chosen after an explicit acknowledgement.
