-- Phase 3: Push notifications device token storage

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios', 'macos')),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS device_tokens_user_id_idx
  ON public.device_tokens (user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own device tokens"
  ON public.device_tokens FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can register device tokens"
  ON public.device_tokens FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own device tokens"
  ON public.device_tokens FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own device tokens"
  ON public.device_tokens FOR DELETE
  USING (user_id = auth.uid());

-- Auto-update timestamp
CREATE TRIGGER device_tokens_set_updated_at
  BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();
