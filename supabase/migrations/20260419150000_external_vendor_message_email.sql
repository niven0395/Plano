-- Migration: per-message emails for vendor → external guest
--
-- Previous behavior throttled vendor_messaged email jobs to one per 30 minutes
-- per conversation. The new product spec is: every vendor message to an
-- external (not-yet-claimed) guest should email the guest, and the email
-- should include the actual message body so the guest can read it without
-- installing the app first.

begin;

create or replace function public.enqueue_external_email_for_vendor_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation public.conversations%rowtype;
  v_preview text;
begin
  if new.sender_role <> 'vendor' or new.kind = 'system' then
    return new;
  end if;

  select *
  into v_conversation
  from public.conversations
  where id = new.conversation_id;

  if not found or v_conversation.external_email is null then
    return new;
  end if;

  -- Cap the preview length so unusually long messages don't bloat the email
  -- payload or the external_email_jobs row.
  v_preview := substring(coalesce(new.body, '') for 1500);

  insert into public.external_email_jobs (conversation_id, kind, payload)
  values (
    new.conversation_id,
    'vendor_messaged',
    jsonb_build_object(
      'vendor_name', coalesce(v_conversation.vendor_display_name, 'Your vendor'),
      'event_date_label', v_conversation.event_date_label,
      'message_preview', v_preview
    )
  );

  return new;
end;
$$;

-- Trigger enqueue_external_email_on_vendor_message already points at this
-- function; replacing the function body is enough.

commit;
