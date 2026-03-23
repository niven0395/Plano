-- Phase 3: Message attachments infrastructure

-- 1. Add 'attachment' kind to messages check constraint
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_kind_check;
ALTER TABLE public.messages ADD CONSTRAINT messages_kind_check
  CHECK (kind IN ('text', 'booking_request', 'quote', 'payment_receipt', 'attachment'));

-- 2. Message attachments table
CREATE TABLE IF NOT EXISTS public.message_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  storage_path text NOT NULL,
  file_name text NOT NULL,
  mime_type text NOT NULL CHECK (mime_type IN (
    'image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp',
    'application/pdf'
  )),
  file_size_bytes bigint NOT NULL CHECK (file_size_bytes > 0 AND file_size_bytes <= 10485760),
  width integer,
  height integer,
  thumbnail_path text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS message_attachments_message_id_idx
  ON public.message_attachments (message_id);

ALTER TABLE public.message_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participants can read attachments"
  ON public.message_attachments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.messages m
      JOIN public.conversations c ON c.id = m.conversation_id
      WHERE m.id = message_attachments.message_id
        AND (c.host_id = auth.uid() OR c.vendor_id = auth.uid())
    )
  );

CREATE POLICY "Participants can create attachments"
  ON public.message_attachments FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.messages m
      JOIN public.conversations c ON c.id = m.conversation_id
      WHERE m.id = message_attachments.message_id
        AND (c.host_id = auth.uid() OR c.vendor_id = auth.uid())
    )
  );

-- 3. Storage bucket for message attachments
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('message-attachments', 'message-attachments', false, 10485760)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: participants can read attachments via signed URLs
CREATE POLICY "Authenticated users can read message attachments"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'message-attachments' AND auth.role() = 'authenticated');

-- Storage RLS: users upload to their own folder
CREATE POLICY "Users can upload message attachments"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'message-attachments'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own message attachments"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'message-attachments'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
