-- ---------------------------------------------------------------------------
-- Add p_intake_answers param to submit_booking_request_v2
-- ---------------------------------------------------------------------------

-- Drop the old overload (11 params without jsonb)
drop function if exists public.submit_booking_request_v2(uuid, uuid, date, text, uuid, time, time, text, text, text, text[]);

create or replace function public.submit_booking_request_v2(
  p_conversation_id uuid,
  p_host_id uuid,
  p_event_date date,
  p_note text,
  p_idempotency_key uuid default null,
  p_requested_time_start time default null,
  p_requested_time_end time default null,
  p_title text default null,
  p_budget_label text default null,
  p_guest_count_label text default null,
  p_requested_services text[] default null,
  p_intake_answers jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking_id uuid;
  v_request_id uuid;
  v_now timestamptz := timezone('utc', now());
begin
  -- Idempotency check
  if p_idempotency_key is not null then
    if exists (
      select 1
      from public.booking_events
      where idempotency_key = p_idempotency_key
    ) then
      return public.booking_transition_snapshot(p_conversation_id);
    end if;
  end if;

  -- Lock conversation
  select *
  into v_conversation
  from public.conversations
  where id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found.';
  end if;

  -- Validate host is participant
  if v_conversation.host_id <> p_host_id then
    raise exception 'Only the host can submit a booking request.';
  end if;

  -- Validate stage allows booking (including re-booking after decline/cancel)
  if v_conversation.stage not in ('active', 'draft', 'declined', 'cancelled') then
    raise exception 'Booking request cannot be submitted from the current stage.';
  end if;

  -- Insert booking request with full details
  insert into public.booking_requests (
    conversation_id,
    event_date,
    note,
    requested_time_start,
    requested_time_end,
    title,
    budget_label,
    guest_count_label,
    requested_services,
    intake_answers
  )
  values (
    p_conversation_id,
    p_event_date,
    coalesce(p_note, ''),
    p_requested_time_start,
    p_requested_time_end,
    p_title,
    p_budget_label,
    p_guest_count_label,
    coalesce(p_requested_services, '{}'::text[]),
    coalesce(p_intake_answers, '[]'::jsonb)
  )
  returning id into v_request_id;

  -- Ensure booking exists with stage 'requested'
  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'requested');

  -- Update booking event_date
  update public.bookings
  set event_date = p_event_date,
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'requested',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Insert system message
  insert into public.messages (
    conversation_id,
    sender_role,
    body,
    kind,
    created_at
  )
  values (
    p_conversation_id,
    'system',
    format('Booking requested for %s', to_char(p_event_date, 'Mon DD, YYYY')),
    'system',
    v_now
  );

  -- Insert booking_events audit row
  insert into public.booking_events (
    conversation_id,
    booking_id,
    from_stage,
    to_stage,
    triggered_by,
    trigger_role,
    metadata,
    idempotency_key
  )
  values (
    p_conversation_id,
    v_booking_id,
    v_conversation.stage,
    'requested',
    p_host_id,
    'host',
    jsonb_build_object(
      'booking_request_id', v_request_id,
      'event_date', p_event_date,
      'requested_time_start', p_requested_time_start,
      'requested_time_end', p_requested_time_end,
      'title', p_title,
      'budget_label', p_budget_label,
      'guest_count_label', p_guest_count_label,
      'intake_answers', coalesce(p_intake_answers, '[]'::jsonb)
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- Permissions
revoke all on function public.submit_booking_request_v2(uuid, uuid, date, text, uuid, time, time, text, text, text, text[], jsonb) from public, anon, authenticated;
grant execute on function public.submit_booking_request_v2(uuid, uuid, date, text, uuid, time, time, text, text, text, text[], jsonb) to service_role;
