-- =============================================================================
-- Fix: "no unique or exclusion constraint matching the ON CONFLICT specification"
--
-- The old unique constraint (vendor_id, date) on vendor_availability was dropped
-- in 20260313120000 and replaced with a 3-column expression index. Any function
-- that still references ON CONFLICT (vendor_id, date) will fail.
--
-- This migration re-deploys accept_booking_server, confirm_payment_server, and
-- vendor_confirm_payment_server using DELETE + INSERT to eliminate all ON CONFLICT
-- references against vendor_availability.
-- =============================================================================

-- 1. accept_booking_server — availability hold on acceptance
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
  v_booking_id uuid;
  v_booking public.bookings%rowtype;
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

  -- Validate vendor is participant
  if v_conversation.vendor_id <> p_vendor_id then
    raise exception 'Only the vendor can accept this booking.';
  end if;

  -- Validate stage transition
  if not public.validate_booking_transition_v2(v_conversation.stage, 'accepted', 'vendor') then
    raise exception 'Booking cannot be accepted from the current stage.';
  end if;

  -- Ensure booking exists and update stage
  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'accepted');

  -- Get booking for event_date
  select *
  into v_booking
  from public.bookings
  where id = v_booking_id;

  update public.bookings
  set stage = 'accepted',
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'accepted',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Reserve availability with 'hold' status (DELETE + INSERT, no ON CONFLICT)
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
    'Booking accepted by vendor.',
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
    'accepted',
    p_vendor_id,
    'vendor',
    '{}'::jsonb,
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- 2. confirm_payment_server — upgrade hold to booked (DELETE + INSERT)
create or replace function public.confirm_payment_server(
  p_conversation_id uuid,
  p_host_id uuid,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking public.bookings%rowtype;
  v_booking_id uuid;
  v_now timestamptz := timezone('utc', now());
begin
  if p_idempotency_key is not null then
    if exists (
      select 1 from public.booking_events where idempotency_key = p_idempotency_key
    ) then
      return public.booking_transition_snapshot(p_conversation_id);
    end if;
  end if;

  select * into v_conversation from public.conversations where id = p_conversation_id for update;
  if not found then raise exception 'Conversation not found.'; end if;

  if v_conversation.host_id <> p_host_id then
    raise exception 'Only the host can confirm payment.';
  end if;

  if not public.validate_booking_transition_v2(v_conversation.stage, 'paid', 'host') then
    raise exception 'Payment cannot be confirmed from the current stage.';
  end if;

  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'paid');

  select * into v_booking from public.bookings where id = v_booking_id for update;

  update public.bookings
  set stage = 'paid', payment_confirmed_at = v_now, updated_at = v_now
  where id = v_booking_id;

  update public.conversations
  set stage = 'paid', last_activity_at = v_now
  where id = p_conversation_id;

  -- Upgrade availability hold → booked (DELETE + INSERT, no ON CONFLICT)
  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where conversation_id = p_conversation_id
       or booking_id = v_booking_id;

    insert into public.vendor_availability (
      vendor_id, date, status, note, booking_id, conversation_id
    ) values (
      v_conversation.vendor_id, v_booking.event_date, 'booked',
      format('booking:%s', p_conversation_id), v_booking_id, p_conversation_id
    );
  end if;

  insert into public.messages (conversation_id, sender_role, body, kind, created_at)
  values (p_conversation_id, 'system', 'Payment confirmed. Booking is now paid.', 'system', v_now);

  insert into public.booking_events (
    conversation_id, booking_id, from_stage, to_stage, triggered_by, trigger_role, metadata, idempotency_key
  ) values (
    p_conversation_id, v_booking_id, v_conversation.stage, 'paid', p_host_id, 'host',
    jsonb_build_object('event_date', v_booking.event_date), p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- 3. vendor_confirm_payment_server — upgrade hold to booked (DELETE + INSERT)
create or replace function public.vendor_confirm_payment_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking public.bookings%rowtype;
  v_booking_id uuid;
  v_now timestamptz := timezone('utc', now());
begin
  if p_idempotency_key is not null then
    if exists (
      select 1 from public.booking_events where idempotency_key = p_idempotency_key
    ) then
      return public.booking_transition_snapshot(p_conversation_id);
    end if;
  end if;

  select * into v_conversation from public.conversations where id = p_conversation_id for update;
  if not found then raise exception 'Conversation not found.'; end if;

  if v_conversation.vendor_id <> p_vendor_id then
    raise exception 'Only the vendor can confirm payment.';
  end if;

  if not public.validate_booking_transition_v2(v_conversation.stage, 'paid', 'vendor') then
    raise exception 'Payment cannot be confirmed from the current stage.';
  end if;

  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'paid');

  select * into v_booking from public.bookings where id = v_booking_id for update;

  update public.bookings
  set stage = 'paid', payment_confirmed_at = v_now, updated_at = v_now
  where id = v_booking_id;

  update public.conversations
  set stage = 'paid', last_activity_at = v_now
  where id = p_conversation_id;

  -- Upgrade availability hold → booked (DELETE + INSERT, no ON CONFLICT)
  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where conversation_id = p_conversation_id
       or booking_id = v_booking_id;

    insert into public.vendor_availability (
      vendor_id, date, status, note, booking_id, conversation_id
    ) values (
      v_conversation.vendor_id, v_booking.event_date, 'booked',
      format('booking:%s', p_conversation_id), v_booking_id, p_conversation_id
    );
  end if;

  insert into public.messages (conversation_id, sender_role, body, kind, created_at)
  values (p_conversation_id, 'system', 'Vendor confirmed payment received. Booking is now paid.', 'system', v_now);

  insert into public.booking_events (
    conversation_id, booking_id, from_stage, to_stage, triggered_by, trigger_role, metadata, idempotency_key
  ) values (
    p_conversation_id, v_booking_id, v_conversation.stage, 'paid', p_vendor_id, 'vendor',
    jsonb_build_object('event_date', v_booking.event_date), p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- 4. Drop the legacy pay_deposit_server which still uses ON CONFLICT
drop function if exists public.pay_deposit_server(uuid, uuid, text, text, uuid);
