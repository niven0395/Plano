alter table public.bookings
add column if not exists payment_request_note text;

create or replace function public.request_payment_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_amount_cents integer,
  p_note text default null,
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
      updated_at = v_now
  where id = v_booking_id;

  update public.conversations
  set stage = 'payment_requested',
      last_activity_at = v_now
  where id = p_conversation_id;

  v_amount_label := '$' || to_char(p_amount_cents / 100.0, 'FM999,999,990.00');
  v_message_body := case
    when v_note is null then format('Payment of %s requested.', v_amount_label)
    else format('Payment of %s requested.%s%s', v_amount_label, E'\n', v_note)
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
      'note', coalesce(v_note, '')
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;
