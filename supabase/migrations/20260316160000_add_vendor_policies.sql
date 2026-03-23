ALTER TABLE vendor_profiles ADD COLUMN IF NOT EXISTS policies jsonb not null default '[]'::jsonb;
