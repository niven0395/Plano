-- Allow vendors to confirm payment (payment_requested -> paid)
-- and create a vendor-specific confirm payment server function.

-- 1. Update validate_booking_transition_v2 to allow vendor payment_requested -> paid
create or replace function public.validate_booking_transition_v2(
  from_stage text,
  to_stage text,
  role text
)
returns boolean
language sql
immutable
as $$
  select case
    when from_stage is null or to_stage is null or role is null then false
    when from_stage = to_stage then false
    -- host transitions
    when lower(role) = 'host' and from_stage = 'requested' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'paid' then true
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'paid' and to_stage = 'cancelled' then true
    -- vendor transitions
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'accepted' then true
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'declined' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'payment_requested' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'payment_requested' and to_stage = 'paid' then true
    when lower(role) = 'vendor' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'paid' and to_stage = 'cancelled' then true
    -- system transitions
    when lower(role) = 'system' and from_stage = 'paid' and to_stage = 'completed' then true
    else false
  end;
$$;

-- 2. Create vendor_confirm_payment_server function
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
    raise exception 'Only the vendor can confirm payment.';
  end if;

  -- Validate stage transition: payment_requested -> paid
  if not public.validate_booking_transition_v2(v_conversation.stage, 'paid', 'vendor') then
    raise exception 'Payment cannot be confirmed from the current stage.';
  end if;

  -- Ensure booking exists and update stage
  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'paid');

  -- Get booking for event_date
  select *
  into v_booking
  from public.bookings
  where id = v_booking_id
  for update;

  -- Update booking with payment confirmation
  update public.bookings
  set stage = 'paid',
      payment_confirmed_at = v_now,
      updated_at = v_now
  where id = v_booking_id;

  -- Update conversation stage
  update public.conversations
  set stage = 'paid',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Create vendor_availability entry with status='booked'
  if v_booking.event_date is not null then
    insert into public.vendor_availability (
      vendor_id,
      date,
      status,
      note
    )
    values (
      v_conversation.vendor_id,
      v_booking.event_date,
      'booked',
      format('booking:%s', p_conversation_id)
    )
    on conflict (vendor_id, date)
    do update set
      status = excluded.status,
      note = excluded.note;
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
    'Vendor confirmed payment received. Booking is now paid.',
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
    'paid',
    p_vendor_id,
    'vendor',
    jsonb_build_object(
      'event_date', v_booking.event_date
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- 3. Grant execute to service_role only
revoke all on function public.vendor_confirm_payment_server(uuid, uuid, uuid) from public;
revoke all on function public.vendor_confirm_payment_server(uuid, uuid, uuid) from anon;
revoke all on function public.vendor_confirm_payment_server(uuid, uuid, uuid) from authenticated;
grant execute on function public.vendor_confirm_payment_server(uuid, uuid, uuid) to service_role;
