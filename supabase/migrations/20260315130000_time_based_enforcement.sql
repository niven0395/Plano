-- =============================================================================
-- Time-based enforcement: quote expiry, booking completion, request expiry
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Schema changes
-- ---------------------------------------------------------------------------

-- Add 'expired' and 'superseded' to booking_quotes status constraint
alter table public.booking_quotes drop constraint if exists booking_quotes_status_check;
alter table public.booking_quotes add constraint booking_quotes_status_check
  check (status in ('pending', 'accepted', 'paid', 'expired', 'superseded'));

-- Add response_window_hours to booking_requests
alter table public.booking_requests
  add column if not exists response_window_hours integer default 48;

-- Backfill response_window_hours from response_window_label
update public.booking_requests
set response_window_hours = case
  when response_window_label ilike '%24%hour%' then 24
  when response_window_label ilike '%48%hour%' then 48
  when response_window_label ilike '%72%hour%' then 72
  when response_window_label ilike '%1 day%' then 24
  when response_window_label ilike '%2 day%' then 48
  when response_window_label ilike '%3 day%' then 72
  when response_window_label ilike '%1 week%' then 168
  else 48
end
where response_window_hours is null;

-- ---------------------------------------------------------------------------
-- Extend validate_booking_transition for system-driven expiry and completion
-- ---------------------------------------------------------------------------
create or replace function public.validate_booking_transition(
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
    when lower(role) = 'host' and from_stage = 'draft' and to_stage in ('requested', 'vendor_reviewing') then true
    when lower(role) = 'host' and from_stage in ('quoted', 'host_reviewing') and to_stage in ('accepted', 'deposit_pending') then true
    when lower(role) = 'host' and from_stage in ('accepted', 'deposit_pending') and to_stage = 'confirmed' then true
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage in ('vendor_reviewing', 'quoted', 'host_reviewing', 'declined') then true
    when lower(role) = 'vendor' and from_stage = 'vendor_reviewing' and to_stage in ('quoted', 'host_reviewing', 'declined') then true
    when lower(role) = 'system' and from_stage = 'quoted' and to_stage = 'host_reviewing' then true
    when lower(role) = 'system' and from_stage = 'accepted' and to_stage in ('deposit_pending', 'confirmed') then true
    when lower(role) = 'system' and from_stage = 'deposit_pending' and to_stage = 'confirmed' then true
    when lower(role) = 'system' and from_stage = 'confirmed' and to_stage = 'completed' then true
    -- System can expire quotes: revert host_reviewing/quoted back to vendor_reviewing
    when lower(role) = 'system' and from_stage in ('quoted', 'host_reviewing') and to_stage = 'vendor_reviewing' then true
    -- System can expire stale requests: transition to declined
    when lower(role) = 'system' and from_stage in ('requested', 'vendor_reviewing') and to_stage = 'declined' then true
    when lower(role) in ('host', 'vendor')
      and from_stage in (
        'requested',
        'vendor_reviewing',
        'quoted',
        'host_reviewing',
        'accepted',
        'deposit_pending',
        'confirmed'
      )
      and to_stage = 'cancelled' then true
    else false
  end;
$$;

-- ---------------------------------------------------------------------------
-- expire_stale_quotes
-- ---------------------------------------------------------------------------
create or replace function public.expire_stale_quotes()
returns jsonb[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_results jsonb[] := '{}';
  v_now timestamptz := timezone('utc', now());
  v_conv_stage text;
  v_booking_id uuid;
begin
  for v_row in
    select bq.id as quote_id,
           bq.conversation_id,
           c.host_id,
           c.vendor_id,
           c.stage as conversation_stage
    from public.booking_quotes bq
    join public.conversations c on c.id = bq.conversation_id
    where bq.status = 'pending'
      and bq.expires_at is not null
      and bq.expires_at <= v_now
    for update of bq
  loop
    -- Expire the quote
    update public.booking_quotes
    set status = 'expired'
    where id = v_row.quote_id;

    v_conv_stage := v_row.conversation_stage;

    -- Reset conversation stage to vendor_reviewing so vendor can re-quote
    update public.conversations
    set stage = 'vendor_reviewing',
        last_activity_at = v_now
    where id = v_row.conversation_id;

    -- Insert system message
    insert into public.messages (
      conversation_id,
      sender_role,
      body,
      kind,
      created_at
    )
    values (
      v_row.conversation_id,
      'system',
      'The quote has expired. The vendor can send a new one.',
      'text',
      v_now
    );

    -- Get or create booking for audit trail
    v_booking_id := public.ensure_booking_for_conversation(
      v_row.conversation_id,
      'vendor_reviewing'
    );

    -- Insert audit record
    insert into public.booking_events (
      conversation_id,
      booking_id,
      from_stage,
      to_stage,
      triggered_by,
      trigger_role,
      metadata
    )
    values (
      v_row.conversation_id,
      v_booking_id,
      v_conv_stage,
      'vendor_reviewing',
      null,
      'system',
      jsonb_build_object(
        'event_type', 'quote_expired',
        'quote_id', v_row.quote_id
      )
    );

    v_results := array_append(v_results, jsonb_build_object(
      'conversation_id', v_row.conversation_id,
      'host_id', v_row.host_id,
      'vendor_id', v_row.vendor_id
    ));
  end loop;

  return v_results;
end;
$$;

-- ---------------------------------------------------------------------------
-- complete_past_bookings
-- ---------------------------------------------------------------------------
create or replace function public.complete_past_bookings()
returns jsonb[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_results jsonb[] := '{}';
  v_now timestamptz := timezone('utc', now());
begin
  for v_row in
    select b.id as booking_id,
           b.conversation_id,
           b.event_date,
           c.host_id,
           c.vendor_id,
           c.stage as conversation_stage
    from public.bookings b
    join public.conversations c on c.id = b.conversation_id
    where b.stage = 'confirmed'
      and b.event_date is not null
      and b.event_date < current_date
    for update of b
  loop
    -- Validate the transition
    if not public.validate_booking_transition('confirmed', 'completed', 'system') then
      continue;
    end if;

    -- Update booking stage
    update public.bookings
    set stage = 'completed',
        updated_at = v_now
    where id = v_row.booking_id;

    -- Update conversation stage
    update public.conversations
    set stage = 'completed',
        last_activity_at = v_now
    where id = v_row.conversation_id;

    -- Insert system message
    insert into public.messages (
      conversation_id,
      sender_role,
      body,
      kind,
      created_at
    )
    values (
      v_row.conversation_id,
      'system',
      'This event has concluded. The booking is now complete.',
      'text',
      v_now
    );

    -- Insert audit record
    insert into public.booking_events (
      conversation_id,
      booking_id,
      from_stage,
      to_stage,
      triggered_by,
      trigger_role,
      metadata
    )
    values (
      v_row.conversation_id,
      v_row.booking_id,
      v_row.conversation_stage,
      'completed',
      null,
      'system',
      jsonb_build_object(
        'event_type', 'auto_completed',
        'event_date', v_row.event_date
      )
    );

    v_results := array_append(v_results, jsonb_build_object(
      'conversation_id', v_row.conversation_id,
      'host_id', v_row.host_id,
      'vendor_id', v_row.vendor_id
    ));
  end loop;

  return v_results;
end;
$$;

-- ---------------------------------------------------------------------------
-- expire_stale_requests
-- ---------------------------------------------------------------------------
create or replace function public.expire_stale_requests()
returns jsonb[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_results jsonb[] := '{}';
  v_now timestamptz := timezone('utc', now());
  v_booking_id uuid;
begin
  for v_row in
    select c.id as conversation_id,
           c.host_id,
           c.vendor_id,
           c.stage as conversation_stage,
           br.id as request_id,
           br.created_at as request_created_at,
           br.response_window_hours
    from public.conversations c
    join public.booking_requests br on br.conversation_id = c.id
    where c.stage in ('requested', 'vendor_reviewing')
      and br.created_at + (coalesce(br.response_window_hours, 48) * interval '1 hour') < v_now
    for update of c
  loop
    -- Transition to declined using ensure_booking_for_conversation
    v_booking_id := public.ensure_booking_for_conversation(
      v_row.conversation_id,
      'declined'
    );

    -- Update booking stage
    update public.bookings
    set stage = 'declined',
        updated_at = v_now
    where id = v_booking_id;

    -- Update conversation stage
    update public.conversations
    set stage = 'declined',
        last_activity_at = v_now
    where id = v_row.conversation_id;

    -- Insert system message
    insert into public.messages (
      conversation_id,
      sender_role,
      body,
      kind,
      created_at
    )
    values (
      v_row.conversation_id,
      'system',
      'This request expired due to no vendor response.',
      'text',
      v_now
    );

    -- Insert audit record
    insert into public.booking_events (
      conversation_id,
      booking_id,
      from_stage,
      to_stage,
      triggered_by,
      trigger_role,
      reason,
      metadata
    )
    values (
      v_row.conversation_id,
      v_booking_id,
      v_row.conversation_stage,
      'declined',
      null,
      'system',
      'No response from vendor',
      jsonb_build_object(
        'event_type', 'request_expired',
        'request_id', v_row.request_id,
        'response_window_hours', coalesce(v_row.response_window_hours, 48),
        'request_created_at', v_row.request_created_at
      )
    );

    v_results := array_append(v_results, jsonb_build_object(
      'conversation_id', v_row.conversation_id,
      'host_id', v_row.host_id,
      'vendor_id', v_row.vendor_id
    ));
  end loop;

  return v_results;
end;
$$;

-- ---------------------------------------------------------------------------
-- Permissions: service_role only for cron-invoked functions
-- ---------------------------------------------------------------------------
revoke all on function public.expire_stale_quotes() from public, anon, authenticated;
grant execute on function public.expire_stale_quotes() to service_role;

revoke all on function public.complete_past_bookings() from public, anon, authenticated;
grant execute on function public.complete_past_bookings() to service_role;

revoke all on function public.expire_stale_requests() from public, anon, authenticated;
grant execute on function public.expire_stale_requests() to service_role;
