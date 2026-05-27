-- Fix: submit_external_booking_request failed with
--   "function gen_random_bytes(integer) does not exist"
--
-- pgcrypto is installed in the `extensions` schema on Supabase projects but
-- that schema isn't on the search_path for SECURITY DEFINER functions. Qualify
-- the call explicitly so the function resolves regardless of search_path.

begin;

create or replace function public.submit_external_booking_request(
  p_vendor_id uuid,
  p_first_name text,
  p_last_name text,
  p_email text,
  p_event_date date,
  p_guest_count int default null,
  p_note text default '',
  p_intake_answers jsonb default '[]'::jsonb,
  p_source text default 'web'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_vendor public.vendor_profiles%rowtype;
  v_conversation_id uuid;
  v_request_id uuid;
  v_token text;
  v_host_display text;
  v_event_date_label text;
  v_event_context_line text;
  v_email text := lower(trim(p_email));
  v_first text := trim(p_first_name);
  v_last text := trim(p_last_name);
  v_guest_label text;
  v_now timestamptz := timezone('utc', now());
begin
  if v_email is null or v_email = '' or v_email not like '%@%' then
    raise exception 'A valid email address is required.';
  end if;

  if v_first is null or v_first = '' or v_last is null or v_last = '' then
    raise exception 'First and last name are required.';
  end if;

  if p_event_date is null then
    raise exception 'Event date is required.';
  end if;

  select *
  into v_vendor
  from public.vendor_profiles
  where user_id = p_vendor_id;

  if not found then
    raise exception 'Vendor not found.';
  end if;

  v_host_display := v_first || ' ' || v_last;
  v_event_date_label := to_char(p_event_date, 'Mon DD, YYYY');
  v_event_context_line := 'Booking request for ' || v_event_date_label;
  if p_guest_count is not null and p_guest_count > 0 then
    v_guest_label := p_guest_count::text || ' guests';
  else
    v_guest_label := '';
  end if;

  insert into public.conversations (
    event_id, vendor_id, host_id, host_display_name, vendor_display_name,
    vendor_category, event_title, event_date_label, event_context_line,
    stage, last_activity_at, created_at, updated_at,
    external_email, external_first_name, external_last_name, external_source
  )
  values (
    null, p_vendor_id, null, v_host_display, v_vendor.business_name,
    coalesce(v_vendor.category, 'General'), 'Booking request',
    v_event_date_label, v_event_context_line,
    'requested', v_now, v_now, v_now,
    v_email, v_first, v_last, coalesce(p_source, 'web')
  )
  returning id into v_conversation_id;

  insert into public.booking_requests (
    conversation_id, title, budget_label, response_window_label,
    requested_services, note, guest_count_label, event_date, intake_answers
  )
  values (
    v_conversation_id, 'External booking request', '', '',
    '{}'::text[], coalesce(p_note, ''), v_guest_label, p_event_date,
    coalesce(p_intake_answers, '[]'::jsonb)
  )
  returning id into v_request_id;

  insert into public.messages (conversation_id, sender_role, body, kind, created_at)
  values (
    v_conversation_id,
    'system',
    v_host_display || ' requested ' || v_event_date_label || ' via your booking link',
    'system',
    v_now
  );

  -- Schema-qualified so SECURITY DEFINER search_path finds it.
  v_token := encode(extensions.gen_random_bytes(24), 'base64');
  v_token := replace(replace(replace(v_token, '+', '-'), '/', '_'), '=', '');

  insert into public.external_booking_invites (conversation_id, email, token, expires_at)
  values (v_conversation_id, v_email, v_token, v_now + interval '30 days');

  insert into public.external_email_jobs (conversation_id, kind, payload)
  values (
    v_conversation_id,
    'request_received',
    jsonb_build_object(
      'vendor_name', v_vendor.business_name,
      'event_date_label', v_event_date_label,
      'first_name', v_first
    )
  );

  return jsonb_build_object(
    'conversation_id', v_conversation_id,
    'booking_request_id', v_request_id,
    'invite_token', v_token
  );
end;
$$;

revoke all on function public.submit_external_booking_request(
  uuid, text, text, text, date, int, text, jsonb, text
) from public, anon, authenticated;
grant execute on function public.submit_external_booking_request(
  uuid, text, text, text, date, int, text, jsonb, text
) to service_role;

commit;
