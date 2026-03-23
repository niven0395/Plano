-- Add payment_type column to bookings table
-- Tracks whether a payment request is for a deposit or full payment.
alter table bookings
  add column if not exists payment_type text default 'deposit';

-- Update request_payment_server to accept and store payment_type
create or replace function request_payment_server(
  p_conversation_id uuid,
  p_amount_cents integer,
  p_note text default null,
  p_payment_type text default 'deposit',
  p_idempotency_key uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_booking_id uuid;
  v_result jsonb;
begin
  -- Find the booking for this conversation
  select id into v_booking_id
  from bookings
  where conversation_id = p_conversation_id
  limit 1;

  if v_booking_id is null then
    raise exception 'No booking found for conversation %', p_conversation_id;
  end if;

  -- Update the booking with payment request details
  update bookings
  set
    payment_requested_amount_cents = p_amount_cents,
    payment_request_note = p_note,
    payment_type = p_payment_type,
    payment_requested_at = now(),
    stage = 'payment_requested',
    updated_at = now()
  where id = v_booking_id;

  -- Update the conversation stage
  update conversations
  set
    stage = 'payment_requested',
    last_activity_at = now(),
    updated_at = now()
  where id = p_conversation_id;

  select jsonb_build_object(
    'conversation_id', p_conversation_id,
    'stage', 'payment_requested',
    'booking_id', v_booking_id
  ) into v_result;

  return v_result;
end;
$$;
