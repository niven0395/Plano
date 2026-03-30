-- Event fields redesign: add time range, duration, venue setting; soft-deprecate budget
-- This supports the new event card that gives vendors full context at a glance.

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS start_time text;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS end_time text;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS duration_hours double precision;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS venue_setting text NOT NULL DEFAULT 'tbd'
  CHECK (venue_setting IN ('indoor', 'outdoor', 'both', 'tbd'));

-- Soft-deprecate budget: make nullable, new events won't send it
ALTER TABLE public.events ALTER COLUMN budget_label DROP NOT NULL;
ALTER TABLE public.events ALTER COLUMN budget_label SET DEFAULT NULL;

-- Ensure end_time is always set when start_time is set
ALTER TABLE public.events ADD CONSTRAINT event_time_range_check
  CHECK (start_time IS NULL OR end_time IS NOT NULL);
