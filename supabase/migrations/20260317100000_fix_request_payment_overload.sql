-- Fix: drop the broken overload from 20260316170000 (no vendor validation,
-- security definer, no audit trail, no system message) and recreate the
-- correct function with payment_type support.

-- 1. Drop the bad 5-param overload (conversation_id, amount_cents, note, payment_type, idempotency_key)
drop function if exists public.request_payment_server(uuid, integer, text, text, uuid);

-- 2. Drop the good 5-param overload so we can recreate with 6 params
drop function if exists public.request_payment_server(uuid, uuid, integer, text, uuid);

-- 3. Single correct 6-param function
create or replace function public.request_payment_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_amount_cents integer,
  p_note text default null,
  p_payment_type text default 'deposit',
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_amount_label text;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_message_body text;
  v_type_label text;
begin
  -- Validate payment_type
  if p_payment_type not in ('deposit', 'full_payment') then
    raise exception 'payment_type must be deposit or full_payment.';
  end if;

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

  if p_amount_cents is null or p_amount_cents <= 0 then
    raise exception 'A positive payment amount is required.';
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
    raise exception 'Only the vendor can request payment.';
  end if;

  if not public.validate_booking_transition_v2(v_conversation.stage, 'payment_requested', 'vendor') then
    raise exception 'Payment cannot be requested from the current stage.';
  end if;

  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'payment_requested');

  update public.bookings
  set stage = 'payment_requested',
      payment_requested_amount_cents = p_amount_cents,
      payment_requested_at = v_now,
      payment_request_note = v_note,
      payment_type = p_payment_type,
      updated_at = v_now
  where id = v_booking_id;

  update public.conversations
  set stage = 'payment_requested',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Build system message with deposit vs full payment distinction
  v_amount_label := '$' || to_char(p_amount_cents / 100.0, 'FM999,999,990.00');
  v_type_label := case p_payment_type
    when 'full_payment' then 'Full payment'
    else 'Deposit'
  end;
  v_message_body := case
    when v_note is null then format('%s of %s requested.', v_type_label, v_amount_label)
    else format('%s of %s requested.%s%s', v_type_label, v_amount_label, E'\n', v_note)
  end;

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
    v_message_body,
    'payment_request',
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
    'payment_requested',
    p_vendor_id,
    'vendor',
    jsonb_build_object(
      'amount_cents', p_amount_cents,
      'note', coalesce(v_note, ''),
      'payment_type', p_payment_type
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

-- 4. Only service_role can call this function
revoke all on function public.request_payment_server(uuid, uuid, integer, text, text, uuid) from public;
revoke all on function public.request_payment_server(uuid, uuid, integer, text, text, uuid) from anon;
revoke all on function public.request_payment_server(uuid, uuid, integer, text, text, uuid) from authenticated;
grant execute on function public.request_payment_server(uuid, uuid, integer, text, text, uuid) to service_role;
