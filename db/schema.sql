-- INFINITY OS — application schema (applied to the Floot-managed Postgres).
-- Auth tables (users, sessions, user_passwords, login_attempts, password_reset_codes)
-- are created by Floot auth provisioning and are not repeated here.
-- Every user-owned table references users(id) ON DELETE CASCADE.

CREATE TYPE block_category AS ENUM ('manifestation','planning','reading','study','finance','meal','review','fitness','recovery','sales','crm','development','meeting','outreach','content','journal','rest','personal','other');
CREATE TYPE day_type AS ENUM ('work_day','school_day','weekend','rest_day','custom');
CREATE TYPE activity_status AS ENUM ('planned','in_progress','paused','completed','skipped');
CREATE TYPE lead_stage AS ENUM ('new','contacted','qualified','demo_scheduled','demo_completed','quotation_sent','won','lost');
CREATE TYPE lead_source AS ENUM ('cold_call','instagram','referral','website','linkedin','other');
CREATE TYPE sales_activity_type AS ENUM ('call','instagram_message','follow_up','demo_scheduled','demo_completed','quotation_sent');
CREATE TYPE project_status AS ENUM ('planning','in_progress','review','delivered','on_hold','cancelled');
CREATE TYPE invoice_status AS ENUM ('draft','sent','partially_paid','paid','overdue','cancelled');
CREATE TYPE goal_status AS ENUM ('not_started','in_progress','completed','paused');
CREATE TYPE manifestation_session AS ENUM ('morning','evening','night','custom');
CREATE TYPE book_status AS ENUM ('want_to_read','reading','completed','abandoned');
CREATE TYPE book_category AS ENUM ('entrepreneurship','sales','psychology','financial_literacy','leadership','technology','communication','other');
CREATE TYPE recommendation_status AS ENUM ('pending','accepted','rejected','applied','failed');
CREATE TYPE confidence_level AS ENUM ('low','medium','high');
CREATE TYPE review_source AS ENUM ('ai','deterministic');

CREATE TABLE profiles (
  user_id integer PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  timezone text NOT NULL DEFAULT 'Asia/Kolkata',
  wake_time time NOT NULL DEFAULT '05:00',
  bed_time time NOT NULL DEFAULT '21:30',
  sleep_target_hours numeric(3,1) NOT NULL DEFAULT 8 CHECK (sleep_target_hours BETWEEN 4 AND 12),
  onboarded boolean NOT NULL DEFAULT false,
  ai_journal_consent boolean NOT NULL DEFAULT false,
  ai_reading_consent boolean NOT NULL DEFAULT false,
  daily_call_target integer NOT NULL DEFAULT 60 CHECK (daily_call_target >= 0),
  daily_dm_target integer NOT NULL DEFAULT 20 CHECK (daily_dm_target >= 0),
  daily_followup_target integer NOT NULL DEFAULT 15 CHECK (daily_followup_target >= 0),
  monthly_client_targets jsonb NOT NULL DEFAULT '[{"month":"2026-11","clients":2},{"month":"2026-12","clients":3},{"month":"2027-01","clients":5}]',
  monthly_revenue_target numeric(12,2),
  daily_reading_minutes integer NOT NULL DEFAULT 30,
  monthly_book_target integer NOT NULL DEFAULT 2,
  daily_capacity_minutes integer NOT NULL DEFAULT 720 CHECK (daily_capacity_minutes BETWEEN 60 AND 1080),
  score_weights jsonb NOT NULL DEFAULT '{"essential":25,"academic":20,"business":25,"reading":10,"sleep":20}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE schedule_templates (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  day_type day_type NOT NULL DEFAULT 'work_day',
  days_of_week jsonb NOT NULL DEFAULT '[]',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX schedule_templates_user_idx ON schedule_templates(user_id);

CREATE TABLE goals (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL, description text, category text NOT NULL DEFAULT 'personal',
  target_date date, status goal_status NOT NULL DEFAULT 'not_started',
  metric_key text, metric_target numeric(12,2), metric_current numeric(12,2) NOT NULL DEFAULT 0, metric_unit text,
  linked_action text, notes text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX goals_user_idx ON goals(user_id);

CREATE TABLE milestones (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  goal_id integer NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  title text NOT NULL, due_date date, completed_at timestamptz, sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX milestones_goal_idx ON milestones(goal_id);
CREATE INDEX milestones_user_idx ON milestones(user_id);

CREATE TABLE goal_progress_history (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  goal_id integer NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  recorded_on date NOT NULL, progress_pct numeric(5,2) NOT NULL,
  UNIQUE (goal_id, recorded_on)
);

CREATE TABLE schedule_blocks (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  template_id integer REFERENCES schedule_templates(id) ON DELETE CASCADE,
  block_date date,
  title text NOT NULL, category block_category NOT NULL DEFAULT 'other',
  start_time time NOT NULL, end_time time NOT NULL,
  priority smallint NOT NULL DEFAULT 2 CHECK (priority BETWEEN 1 AND 3),
  reminder_minutes integer CHECK (reminder_minutes BETWEEN 0 AND 240),
  goal_id integer REFERENCES goals(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (template_id IS NOT NULL OR block_date IS NOT NULL),
  CHECK (end_time <> start_time)
);
CREATE INDEX schedule_blocks_user_template_idx ON schedule_blocks(user_id, template_id);
CREATE INDEX schedule_blocks_user_date_idx ON schedule_blocks(user_id, block_date);

CREATE TABLE activity_logs (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  block_id integer REFERENCES schedule_blocks(id) ON DELETE SET NULL,
  log_date date NOT NULL, title text NOT NULL, category block_category NOT NULL,
  planned_start time NOT NULL, planned_end time NOT NULL,
  status activity_status NOT NULL DEFAULT 'planned',
  started_at timestamptz, last_resumed_at timestamptz,
  total_seconds integer NOT NULL DEFAULT 0 CHECK (total_seconds >= 0),
  completed_at timestamptz, skip_reason text, rescheduled_to date,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, block_id, log_date)
);
CREATE INDEX activity_logs_user_date_idx ON activity_logs(user_id, log_date);

CREATE TABLE sleep_logs (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sleep_date date NOT NULL,
  duration_minutes integer NOT NULL CHECK (duration_minutes BETWEEN 0 AND 1440),
  quality smallint CHECK (quality BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, sleep_date)
);

CREATE TABLE habits (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL, icon text NOT NULL DEFAULT 'check', color text NOT NULL DEFAULT 'primary',
  target_label text, target_per_week smallint NOT NULL DEFAULT 7 CHECK (target_per_week BETWEEN 1 AND 7),
  archived boolean NOT NULL DEFAULT false, sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX habits_user_idx ON habits(user_id);

CREATE TABLE habit_entries (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  habit_id integer NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
  entry_date date NOT NULL, completed boolean NOT NULL DEFAULT true, note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (habit_id, entry_date)
);
CREATE INDEX habit_entries_user_date_idx ON habit_entries(user_id, entry_date);

CREATE TABLE manifestation_entries (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entry_date date NOT NULL, session manifestation_session NOT NULL,
  goal_id integer REFERENCES goals(id) ON DELETE SET NULL,
  affirmations text, visualization text, gratitude text, intention text, action_commitment text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX manifestation_user_date_idx ON manifestation_entries(user_id, entry_date);

CREATE TABLE books (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL, author text, category book_category NOT NULL DEFAULT 'other',
  total_pages integer CHECK (total_pages > 0), current_page integer NOT NULL DEFAULT 0 CHECK (current_page >= 0),
  status book_status NOT NULL DEFAULT 'reading', started_on date, finished_on date,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX books_user_idx ON books(user_id);

CREATE TABLE reading_sessions (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  book_id integer NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  session_date date NOT NULL,
  pages_read integer NOT NULL DEFAULT 0 CHECK (pages_read >= 0),
  duration_minutes integer NOT NULL DEFAULT 0 CHECK (duration_minutes >= 0),
  lesson text, application text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX reading_sessions_user_date_idx ON reading_sessions(user_id, session_date);

CREATE TABLE reading_notes (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  book_id integer NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  session_id integer REFERENCES reading_sessions(id) ON DELETE SET NULL,
  note text NOT NULL, page integer,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX reading_notes_user_idx ON reading_notes(user_id);

CREATE TABLE journal_entries (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entry_date date NOT NULL,
  accomplished text, client_progress text, learned text, challenges text, mistakes text, grateful text, priorities text,
  body_html text, mood smallint CHECK (mood BETWEEN 1 AND 5), tags jsonb NOT NULL DEFAULT '[]',
  ai_allowed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, entry_date)
);

CREATE TABLE leads (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL, business_name text, contact text,
  source lead_source NOT NULL DEFAULT 'other', stage lead_stage NOT NULL DEFAULT 'new',
  estimated_value numeric(12,2),
  qualified_at timestamptz, demo_scheduled_for timestamptz, demo_completed_at timestamptz,
  quotation_sent_at timestamptz, won_at timestamptz, lost_at timestamptz, lost_reason text,
  next_follow_up_on date, notes text,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX leads_user_stage_idx ON leads(user_id, stage);

CREATE TABLE sales_activities (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  activity_date date NOT NULL, type sales_activity_type NOT NULL,
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity >= 0),
  lead_id integer REFERENCES leads(id) ON DELETE SET NULL, notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sales_activities_user_date_idx ON sales_activities(user_id, activity_date);

CREATE TABLE clients (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lead_id integer REFERENCES leads(id) ON DELETE SET NULL,
  name text NOT NULL, business_name text, contact text,
  source lead_source NOT NULL DEFAULT 'other', acquired_on date NOT NULL,
  is_new_in_campaign boolean NOT NULL DEFAULT true, notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX clients_user_idx ON clients(user_id, acquired_on);

CREATE TABLE projects (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id integer NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  name text NOT NULL, status project_status NOT NULL DEFAULT 'planning',
  value numeric(12,2) NOT NULL DEFAULT 0 CHECK (value >= 0),
  start_date date, due_date date,
  progress_pct smallint NOT NULL DEFAULT 0 CHECK (progress_pct BETWEEN 0 AND 100),
  delivered_on date,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX projects_user_idx ON projects(user_id, status);

CREATE TABLE invoices (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id integer NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  project_id integer REFERENCES projects(id) ON DELETE SET NULL,
  invoice_number text NOT NULL, amount numeric(12,2) NOT NULL CHECK (amount >= 0),
  issued_on date NOT NULL, due_on date, status invoice_status NOT NULL DEFAULT 'sent',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, invoice_number)
);
CREATE INDEX invoices_user_idx ON invoices(user_id, status);

CREATE TABLE payments (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id integer NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  invoice_id integer REFERENCES invoices(id) ON DELETE SET NULL,
  amount numeric(12,2) NOT NULL CHECK (amount > 0), paid_on date NOT NULL, method text, notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX payments_user_date_idx ON payments(user_id, paid_on);

CREATE TABLE weekly_reviews (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  week_start date NOT NULL, metrics jsonb NOT NULL, report jsonb,
  source review_source NOT NULL, ai_error text,
  generation_count integer NOT NULL DEFAULT 1, last_generated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, week_start)
);

CREATE TABLE ai_recommendations (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  review_id integer NOT NULL REFERENCES weekly_reviews(id) ON DELETE CASCADE,
  area text NOT NULL, recommendation text NOT NULL, evidence text NOT NULL, expected_benefit text NOT NULL,
  confidence confidence_level NOT NULL, is_hypothesis boolean NOT NULL DEFAULT false,
  schedule_change jsonb, fingerprint text NOT NULL,
  status recommendation_status NOT NULL DEFAULT 'pending', decided_at timestamptz, apply_result text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ai_recommendations_user_status_idx ON ai_recommendations(user_id, status);
CREATE INDEX ai_recommendations_user_fp_idx ON ai_recommendations(user_id, fingerprint);

CREATE TABLE notification_preferences (
  user_id integer PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  browser_enabled boolean NOT NULL DEFAULT false,
  quiet_start time NOT NULL DEFAULT '21:30', quiet_end time NOT NULL DEFAULT '05:00',
  daily_limit integer NOT NULL DEFAULT 12 CHECK (daily_limit BETWEEN 0 AND 100),
  lead_minutes integer NOT NULL DEFAULT 10 CHECK (lead_minutes BETWEEN 0 AND 120),
  enabled_types jsonb NOT NULL DEFAULT '{"activity":true,"reading":true,"journal":true,"manifestation":true,"meeting":true,"follow_up":true,"weekly_review":true,"missed_priority":true}',
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE notifications (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL, title text NOT NULL, body text, link text, dedupe_key text,
  read_at timestamptz, snoozed_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, dedupe_key)
);
CREATE INDEX notifications_user_idx ON notifications(user_id, created_at DESC);
