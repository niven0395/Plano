-- Rebuild confirm payment from scratch for both host and vendor.
-- Replaces all prior versions of confirm_payment_server and
-- vendor_confirm_payment_server with clean, correct implementations.

------------------------------------------------------------------------
-- 1. confirm_payment_server  (host confirms payment)
------------------------------------------------------------------------
create or replace function public.confirm_payment_server(
  p_conversation_id uuid,
  p_host_id uuid,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conv  public.conversations%rowtype;
  v_book  public.bookings%rowtype;
  v_bid   uuid;
  v_now   timestamptz := timezone('utc', now());
begin
  ---------------------------------------------------------------- idempotency
  if p_idempotency_key is not null
     and exists (select 1 from public.booking_events
                 where idempotency_key = p_idempotency_key)
  then
    return public.booking_transition_snapshot(p_conversation_id);
  end if;

  -------------------------------------------------------------- lock & load
  select * into v_conv
  from public.conversations
  where id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found.';
  end if;

  if v_conv.host_id <> p_host_id then
    raise exception 'Only the host can confirm payment.';
  end if;

  if not public.validate_booking_transition_v2(v_conv.stage, 'paid', 'host') then
    raise exception 'Payment cannot be confirmed from the current stage.';
  end if;

  --------------------------------------------------------- booking upsert
  v_bid := public.ensure_booking_for_conversation(p_conversation_id, 'paid');

  select * into v_book
  from public.bookings
  where id = v_bid
  for update;

  update public.bookings
  set stage              = 'paid',
      payment_confirmed_at = v_now,
      updated_at         = v_now
  where id = v_bid;

  update public.conversations
  set stage           = 'paid',
      last_activity_at = v_now
  where id = p_conversation_id;

  ------------------------------------------------- vendor availability
  if v_book.event_date is not null then
    delete from public.vendor_availability
    where booking_id = v_bid;

    insert into public.vendor_availability
           (vendor_id, date, status, note, booking_id, conversation_id)
    values (v_conv.vendor_id, v_book.event_date, 'booked',
            format('booking:%s', p_conversation_id),
            v_bid, p_conversation_id);
  end if;

  ---------------------------------------------------- system message
  insert into public.messages
         (conversation_id, sender_role, body, kind, created_at)
  values (p_conversation_id, 'system',
          'Payment confirmed. Booking is now paid.',
          'system', v_now);

  ------------------------------------------------------ audit event
  insert into public.booking_events
         (conversation_id, booking_id, from_stage, to_stage,
          triggered_by, trigger_role, metadata, idempotency_key)
  values (p_conversation_id, v_bid, v_conv.stage, 'paid',
          p_host_id, 'host',
          jsonb_build_object('event_date', v_book.event_date),
          p_idempotency_key);

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

------------------------------------------------------------------------
-- 2. vendor_confirm_payment_server  (vendor confirms payment received)
------------------------------------------------------------------------
create or replace function public.vendor_confirm_payment_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conv  public.conversations%rowtype;
  v_book  public.bookings%rowtype;
  v_bid   uuid;
  v_now   timestamptz := timezone('utc', now());
begin
  ---------------------------------------------------------------- idempotency
  if p_idempotency_key is not null
     and exists (select 1 from public.booking_events
                 where idempotency_key = p_idempotency_key)
  then
    return public.booking_transition_snapshot(p_conversation_id);
  end if;

  -------------------------------------------------------------- lock & load
  select * into v_conv
  from public.conversations
  where id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found.';
  end if;

  if v_conv.vendor_id <> p_vendor_id then
    raise exception 'Only the vendor can confirm payment.';
  end if;

  if not public.validate_booking_transition_v2(v_conv.stage, 'paid', 'vendor') then
    raise exception 'Payment cannot be confirmed from the current stage.';
  end if;

  --------------------------------------------------------- booking upsert
  v_bid := public.ensure_booking_for_conversation(p_conversation_id, 'paid');

  select * into v_book
  from public.bookings
  where id = v_bid
  for update;

  update public.bookings
  set stage              = 'paid',
      payment_confirmed_at = v_now,
      updated_at         = v_now
  where id = v_bid;

  update public.conversations
  set stage           = 'paid',
      last_activity_at = v_now
  where id = p_conversation_id;

  ------------------------------------------------- vendor availability
  if v_book.event_date is not null then
    delete from public.vendor_availability
    where booking_id = v_bid;

    insert into public.vendor_availability
           (vendor_id, date, status, note, booking_id, conversation_id)
    values (v_conv.vendor_id, v_book.event_date, 'booked',
            format('booking:%s', p_conversation_id),
            v_bid, p_conversation_id);
  end if;

  ---------------------------------------------------- system message
  insert into public.messages
         (conversation_id, sender_role, body, kind, created_at)
  values (p_conversation_id, 'system',
          'Vendor confirmed payment received. Booking is now paid.',
          'system', v_now);

  ------------------------------------------------------ audit event
  insert into public.booking_events
         (conversation_id, booking_id, from_stage, to_stage,
          triggered_by, trigger_role, metadata, idempotency_key)
  values (p_conversation_id, v_bid, v_conv.stage, 'paid',
          p_vendor_id, 'vendor',
          jsonb_build_object('event_date', v_book.event_date),
          p_idempotency_key);

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

------------------------------------------------------------------------
-- 3. Grants — service_role only
------------------------------------------------------------------------
revoke all on function public.confirm_payment_server(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.confirm_payment_server(uuid, uuid, uuid) to service_role;

revoke all on function public.vendor_confirm_payment_server(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.vendor_confirm_payment_server(uuid, uuid, uuid) to service_role;
