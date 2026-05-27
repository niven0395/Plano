-- Vendors hitting "Booking cannot be accepted from the current stage" when a
-- conversation row is still on a legacy stage value (vendor_reviewing, quoted,
-- host_reviewing, deposit_pending, confirmed). The iOS BookingStage enum
-- collapses those onto the simplified set, so the Accept button shows up, but
-- accept_booking_server's validator only knows the simplified vocabulary and
-- rejects the transition.
--
-- 1. Replace accept_booking_server so it normalizes the source stage with the
--    same mapping iOS uses before consulting validate_booking_transition_v2.
-- 2. Backfill any conversations / bookings rows still on legacy stage strings.
--    booking_events rows are intentionally left alone — their from_stage /
--    to_stage values are an audit log and should reflect what actually
--    happened at the time.

create or replace function public.accept_booking_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_normalized_stage text;
  v_booking_id uuid;
  v_booking public.bookings%rowtype;
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

  if v_conversation.vendor_id <> p_vendor_id then
    raise exception 'Only the vendor can accept this booking.';
  end if;

  v_normalized_stage := case v_conversation.stage
    when 'vendor_reviewing' then 'requested'
    when 'quoted'           then 'accepted'
    when 'host_reviewing'   then 'accepted'
    when 'deposit_pending'  then 'payment_requested'
    when 'confirmed'        then 'paid'
    else v_conversation.stage
  end;

  if not public.validate_booking_transition_v2(v_normalized_stage, 'accepted', 'vendor') then
    raise exception 'Booking cannot be accepted from the current stage.';
  end if;

  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'accepted');

  select *
  into v_booking
  from public.bookings
  where id = v_booking_id;

  update public.bookings
  set stage = 'accepted',
      updated_at = v_now
  where id = v_booking_id;

  update public.conversations
  set stage = 'accepted',
      last_activity_at = v_now
  where id = p_conversation_id;

  if v_booking.event_date is not null then
    if exists (
      select 1
      from public.vendor_availability va
      where va.vendor_id = v_conversation.vendor_id
        and va.date = v_booking.event_date
        and va.status in ('hold', 'booked', 'blocked')
        and coalesce(va.conversation_id, '00000000-0000-0000-0000-000000000000'::uuid) <> p_conversation_id
    ) then
      raise exception 'This vendor already has a conflicting booking or hold on that date.';
    end if;

    delete from public.vendor_availability
    where conversation_id = p_conversation_id
       or booking_id = v_booking_id;

    insert into public.vendor_availability (
      vendor_id,
      date,
      status,
      note,
      booking_id,
      conversation_id
    )
    values (
      v_conversation.vendor_id,
      v_booking.event_date,
      'hold',
      format('booking:%s', p_conversation_id),
      v_booking_id,
      p_conversation_id
    );
  end if;

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
    'Booking accepted by vendor.',
    'system',
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
    'accepted',
    p_vendor_id,
    'vendor',
    '{}'::jsonb,
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- Backfill legacy stage values on live rows so they render and validate
-- consistently going forward.

update public.conversations set stage = 'requested'         where stage = 'vendor_reviewing';
update public.conversations set stage = 'accepted'          where stage in ('quoted', 'host_reviewing');
update public.conversations set stage = 'payment_requested' where stage = 'deposit_pending';
update public.conversations set stage = 'paid'              where stage = 'confirmed';

update public.bookings      set stage = 'requested'         where stage = 'vendor_reviewing';
update public.bookings      set stage = 'accepted'          where stage in ('quoted', 'host_reviewing');
update public.bookings      set stage = 'payment_requested' where stage = 'deposit_pending';
update public.bookings      set stage = 'paid'              where stage = 'confirmed';
