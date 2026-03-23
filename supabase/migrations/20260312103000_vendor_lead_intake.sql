alter table public.vendor_profiles
  add column if not exists lead_intake_questions jsonb not null default '[]'::jsonb;

alter table public.booking_requests
  add column if not exists intake_answers jsonb not null default '[]'::jsonb;

alter table public.conversations
  alter column stage set default 'draft';

update public.conversations
set stage = 'draft'
where stage = 'requested'
  and not exists (
    select 1
    from public.booking_requests
    where booking_requests.conversation_id = conversations.id
  );

drop function if exists public.submit_booking_request_server(uuid, uuid, text, text, text, text[], text, text, uuid);

create or replace function public.submit_booking_request_server(
  p_conversation_id uuid,
  p_host_id uuid,
  p_title text,
  p_budget_label text,
  p_response_window_label text,
  p_requested_services text[],
  p_note text,
  p_guest_count_label text,
  p_intake_answers jsonb default '[]'::jsonb,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_event_date date;
  v_booking_id uuid;
  v_request_id uuid;
  v_now timestamptz := timezone('utc', now());
begin
  if p_idempotency_key is not null then
    if exists (
      select 1
      from public.booking_events
      where idempotency_key = p_idempotency_key
    ) then
      return public.booking_transition_snapshot(p_conversation_id);
    end if;
  end if;

  select *
  into v_conversation
  from public.conversations
  where id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found.';
  end if;

  if v_conversation.host_id <> p_host_id then
    raise exception 'Only the host can submit a booking request.';
  end if;

  if not public.validate_booking_transition(v_conversation.stage, 'requested', 'host') then
    raise exception 'Booking request cannot be submitted from the current stage.';
  end if;

  if v_conversation.event_id is not null then
    select (timezone('utc', events.date))::date
    into v_event_date
    from public.events
    where events.id = v_conversation.event_id;
  end if;

  insert into public.booking_requests (
    conversation_id,
    title,
    budget_label,
    response_window_label,
    requested_services,
    note,
    guest_count_label,
    event_date,
    intake_answers
  )
  values (
    p_conversation_id,
    btrim(p_title),
    btrim(p_budget_label),
    btrim(p_response_window_label),
    coalesce(p_requested_services, '{}'::text[]),
    coalesce(p_note, ''),
    btrim(p_guest_count_label),
    v_event_date,
    coalesce(p_intake_answers, '[]'::jsonb)
  )
  returning id into v_request_id;

  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'requested');

  update public.conversations
  set stage = 'requested',
      last_activity_at = v_now
  where id = p_conversation_id;

  insert into public.messages (
    conversation_id,
    sender_role,
    body,
    kind,
    created_at
  )
  values (
    p_conversation_id,
    'host',
    format('Booking request sent for %s.', btrim(p_title)),
    'booking_request',
    v_now
  );

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
      'event_date', v_event_date,
      'requested_services', coalesce(to_jsonb(p_requested_services), '[]'::jsonb),
      'intake_answers', coalesce(p_intake_answers, '[]'::jsonb)
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

revoke all on function public.submit_booking_request_server(uuid, uuid, text, text, text, text[], text, text, jsonb, uuid) from public, anon, authenticated;
grant execute on function public.submit_booking_request_server(uuid, uuid, text, text, text, text[], text, text, jsonb, uuid) to service_role;
