# INFINITY OS

AI-powered personal productivity and business-growth app for the founder of **Infinity Web & Apps**.

> Measure progress. Learn from data. Improve consistently. Grow sustainably.

The application itself is built and hosted on **[Floot](https://floot.com)** (project name: `INFINITY OS`).
This repository holds the project documentation, the database schema, and the architecture notes.
The source of truth for the running code is the Floot project.

## What it does

| Module | Highlights |
|---|---|
| Command Center | Greeting, week strip, glowing completion ring, habit toggles, streaks, weekly activity bars, consistency checks, 10-client campaign progress, today's outreach, last night's sleep |
| Daily Timetable | Founder template preloaded, sleep-conflict detection at onboarding, start/pause/complete timers, skip with reason, overlap detection, drag-to-swap, week calendar, recurring + one-time tasks, capacity-aware rollover, school/work/rest templates |
| Business Analytics | Leads pipeline (kanban), clients, projects, invoices, payments, editable targets, supportive target suggestions, 8 charts (outreach, funnel, weekly funnel, revenue vs target, client acquisition with labelled forecast, lead sources, pipeline, delivery tracker) |
| Habit Tracker | 28-day grid, streaks, weekly targets, archive |
| Manifestation | Morning / evening / night sessions, affirmations, visualisation, gratitude, intention, **required action commitment when tied to a goal**, sleep-window warnings |
| Reading Library | Books, sessions (pages + minutes), lesson & application prompts, notes, search, streaks, books per month |
| Daily Journal | 7 prompts, rich text, autosave, mood, tags, search, calendar history, private by default, per-entry AI consent |
| Weekly AI Coach | Deterministic metrics + scorecard, AI analysis validated against a strict JSON schema, Accept / Reject on every recommendation, conflict-checked timetable changes, rejected ideas remembered, deterministic fallback when AI is unavailable, rate-limited regeneration, Sunday schedule |
| Analytics | Daily / 7 / 30 / 90-day views, 11 charts, transparent customisable productivity score |
| Goals & Milestones | Auto progress from tracked data, milestones, linked timetable tasks, history |
| Notifications | In-app + browser, quiet hours, daily limit, snooze, per-type toggles |
| Settings | Sleep window, capacity, privacy/AI consent, theme, data export, account deletion |

## Tech stack (Floot)

The original brief named Next.js + Supabase + Vercel. The project owner chose Floot, so each piece maps to a Floot equivalent:

| Brief | Floot implementation |
|---|---|
| Next.js + TypeScript | React 19 + TypeScript pages/components |
| Tailwind + shadcn/ui | Floot UI kit (Radix) + CSS modules + `base.css` design tokens |
| Supabase Postgres | Floot-managed Postgres (kysely) |
| Supabase Auth | Floot email/password auth (bcrypt, JWT session cookie) |
| Row Level Security | Server-side ownership scoping on every query (see [Security](docs/ARCHITECTURE.md#security-model)) |
| Recharts | Recharts |
| Server-side LLM | `@floot/ai` (`gpt-6-luna`), server-only, no API key in the client |
| Vercel Cron | Floot scheduled job `weeklyCoachJob` (Sundays 19:30 Asia/Kolkata) |
| Vercel hosting | Floot hosting |

## Configuration

Floot manages every secret. Nothing secret is stored in this repo or in the frontend. See [`.env.example`](.env.example) for the variable names the backend reads.

## Testing

Unit tests live next to the helpers in the Floot project (`helpers/*.spec.tsx`) and run on Floot's test runner:

| Spec | Covers |
|---|---|
| `scheduleMath.spec` | overlaps, sleep-window maths (the 3 AM template conflict), completion %, capacity-aware rollover, timers |
| `salesMetrics.spec` | cohort funnel, lead→client and demo→client rates, outstanding payments, cumulative targets, forecast guard, target suggestions |
| `productivityScore.spec` | weighted score, re-normalisation for missing data, outreach attainment |
| `coachEngine.spec` | scorecard separates activity vs outcomes, data-sufficiency rules, spec bottleneck example, no "work longer" advice |
| `coachReportSchema.spec` | AI JSON validation, unsafe schedule changes dropped, rejection fingerprints |
| `notificationRules.spec` | quiet hours across midnight, due reminders, missed high-priority tasks |
| `sanitizeHtml.spec` | journal rich-text XSS sanitising |
| `streaks.spec` | reading / journal / habit streaks |

## Deployment

1. Open the Floot project **INFINITY OS** and press **Publish** (or ask Claude to publish).
2. Scheduled jobs (the Sunday coach review) only run on a **published** app whose owner is on a **paid Floot plan**.
3. To let users other than the owner reset passwords by email, verify an email domain in Floot's Email tab.

Docs: [Architecture](docs/ARCHITECTURE.md) · [Database schema](db/schema.sql)
