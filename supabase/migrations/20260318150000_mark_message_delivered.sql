-- Mark a single message as delivered (sent → delivered).
-- Idempotent: no-op if the message is already 'delivered' or 'read'.

CREATE OR REPLACE FUNCTION public.mark_message_delivered(p_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE messages
  SET status = 'delivered'
  WHERE id = p_message_id
    AND status = 'sent';
END;
$$;

-- Permissions: authenticated users and service_role
REVOKE ALL ON FUNCTION public.mark_message_delivered(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mark_message_delivered(uuid) TO authenticated, service_role;
