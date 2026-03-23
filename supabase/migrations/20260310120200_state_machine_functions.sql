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

create or replace function public.check_vendor_date_conflicts(
  lookup_vendor_id uuid,
  lookup_event_date date,
  exclude_conversation_id uuid default null
)
returns table (
  conversation_id uuid,
  event_title text,
  host_display_name text,
  stage text
)
language sql
stable
as $$
  select
    conversations.id as conversation_id,
    coalesce(conversations.event_title, events.title, 'Direct inquiry') as event_title,
    conversations.host_display_name,
    coalesce(bookings.stage, conversations.stage) as stage
  from public.conversations
  left join public.events
    on events.id = conversations.event_id
  left join lateral (
    select *
    from public.bookings
    where bookings.conversation_id = conversations.id
    order by bookings.updated_at desc nulls last, bookings.created_at desc nulls last
    limit 1
  ) as bookings on true
  where conversations.vendor_id = lookup_vendor_id
    and (exclude_conversation_id is null or conversations.id <> exclude_conversation_id)
    and coalesce(bookings.event_date, (timezone('utc', events.date))::date) = lookup_event_date
    and coalesce(bookings.stage, conversations.stage) not in ('draft', 'declined', 'cancelled')
  order by coalesce(bookings.updated_at, conversations.last_activity_at) desc;
$$;

create or replace function public.booking_transition_snapshot(
  p_conversation_id uuid,
  p_date_conflicts jsonb default '[]'::jsonb
)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'conversation_id', conversations.id,
    'stage', conversations.stage,
    'booking_id', booking_row.id,
    'date_conflicts', coalesce(p_date_conflicts, '[]'::jsonb)
  )
  from public.conversations
  left join lateral (
    select bookings.id
    from public.bookings
    where bookings.conversation_id = conversations.id
    order by bookings.updated_at desc nulls last, bookings.created_at desc nulls last
    limit 1
  ) as booking_row on true
  where conversations.id = p_conversation_id;
$$;

create or replace function public.ensure_booking_for_conversation(
  p_conversation_id uuid,
  p_stage text default null
)
returns uuid
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_event_date date;
  v_booking_id uuid;
begin
  select *
  into v_conversation
  from public.conversations
  where id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found.';
  end if;

  if v_conversation.event_id is not null then
    select (timezone('utc', events.date))::date
    into v_event_date
    from public.events
    where events.id = v_conversation.event_id;
  end if;

  select bookings.id
  into v_booking_id
  from public.bookings
  where bookings.conversation_id = p_conversation_id
  order by bookings.updated_at desc nulls last, bookings.created_at desc nulls last
  limit 1
  for update;

  if v_booking_id is not null then
    update public.bookings as existing_booking
    set event_id = coalesce(existing_booking.event_id, v_conversation.event_id),
        vendor_id = v_conversation.vendor_id,
        host_id = v_conversation.host_id,
        event_date = coalesce(existing_booking.event_date, v_event_date),
        stage = coalesce(p_stage, existing_booking.stage)
    where existing_booking.id = v_booking_id;

    return v_booking_id;
  end if;

  insert into public.bookings (
    conversation_id,
    event_id,
    vendor_id,
    host_id,
    stage,
    event_date
  )
  values (
    v_conversation.id,
    v_conversation.event_id,
    v_conversation.vendor_id,
    v_conversation.host_id,
    coalesce(p_stage, v_conversation.stage),
    v_event_date
  )
  returning id into v_booking_id;

  return v_booking_id;
end;
$$;

create or replace function public.submit_booking_request_server(
  p_conversation_id uuid,
  p_host_id uuid,
  p_title text,
  p_budget_label text,
  p_response_window_label text,
  p_requested_services text[],
  p_note text,
  p_guest_count_label text,
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

  if not public.validate_booking_transition(v_conversation.stage, 'vendor_reviewing', 'host') then
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
    event_date
  )
  values (
    p_conversation_id,
    btrim(p_title),
    btrim(p_budget_label),
    btrim(p_response_window_label),
    coalesce(p_requested_services, '{}'::text[]),
    coalesce(p_note, ''),
    btrim(p_guest_count_label),
    v_event_date
  )
  returning id into v_request_id;

  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'vendor_reviewing');

  update public.conversations
  set stage = 'vendor_reviewing',
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
    'vendor_reviewing',
    p_host_id,
    'host',
    jsonb_build_object(
      'booking_request_id', v_request_id,
      'event_date', v_event_date,
      'requested_services', coalesce(to_jsonb(p_requested_services), '[]'::jsonb)
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

create or replace function public.send_quote_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_title text,
  p_total_amount_label text,
  p_deposit_amount_label text,
  p_total_amount_cents integer,
  p_deposit_amount_cents integer,
  p_expires_at timestamptz,
  p_turnaround_label text,
  p_included_items text[],
  p_note text,
  p_currency text default 'usd',
  p_conflict_acknowledged boolean default false,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_event_date date;
  v_booking_id uuid;
  v_quote_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_date_conflicts jsonb := '[]'::jsonb;
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

  if p_total_amount_cents is null or p_total_amount_cents <= 0 then
    raise exception 'A positive total amount is required.';
  end if;

  if p_deposit_amount_cents is null or p_deposit_amount_cents <= 0 then
    raise exception 'A positive deposit amount is required.';
  end if;

  if p_deposit_amount_cents > p_total_amount_cents then
    raise exception 'Deposit cannot exceed the quote total.';
  end if;

  if p_expires_at is null or p_expires_at <= v_now then
    raise exception 'Quote expiry must be in the future.';
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
    raise exception 'Only the vendor can send a quote.';
  end if;

  if not public.validate_booking_transition(v_conversation.stage, 'host_reviewing', 'vendor') then
    raise exception 'A quote cannot be sent from the current stage.';
  end if;

  if v_conversation.event_id is not null then
    select (timezone('utc', events.date))::date
    into v_event_date
    from public.events
    where events.id = v_conversation.event_id;
  end if;

  if v_event_date is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'conversation_id', conflicts.conversation_id,
          'event_title', conflicts.event_title,
          'host_display_name', conflicts.host_display_name,
          'stage', conflicts.stage
        )
      ),
      '[]'::jsonb
    )
    into v_date_conflicts
    from public.check_vendor_date_conflicts(
      v_conversation.vendor_id,
      v_event_date,
      p_conversation_id
    ) as conflicts;
  end if;

  insert into public.booking_quotes (
    conversation_id,
    title,
    total_amount_label,
    deposit_amount_label,
    expires_at_label,
    turnaround_label,
    included_items,
    note,
    status,
    total_amount_cents,
    deposit_amount_cents,
    expires_at,
    currency
  )
  values (
    p_conversation_id,
    btrim(p_title),
    btrim(p_total_amount_label),
    btrim(p_deposit_amount_label),
    to_char(p_expires_at at time zone 'utc', 'Mon DD, YYYY HH24:MI UTC'),
    btrim(p_turnaround_label),
    coalesce(p_included_items, '{}'::text[]),
    coalesce(p_note, ''),
    'pending',
    p_total_amount_cents,
    p_deposit_amount_cents,
    p_expires_at,
    lower(coalesce(p_currency, 'usd'))
  )
  returning id into v_quote_id;

  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'host_reviewing');

  update public.conversations
  set stage = 'host_reviewing',
      last_activity_at = v_now
  where id = p_conversation_id;

  update public.bookings as existing_booking
  set quote_id = v_quote_id,
      event_date = coalesce(existing_booking.event_date, v_event_date),
      updated_at = v_now
  where existing_booking.id = v_booking_id;

  insert into public.messages (
    conversation_id,
    sender_role,
    body,
    kind,
    created_at
  )
  values (
    p_conversation_id,
    'vendor',
    format('Quote sent for %s.', btrim(p_total_amount_label)),
    'quote',
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
    'host_reviewing',
    p_vendor_id,
    'vendor',
    jsonb_build_object(
      'quote_id', v_quote_id,
      'expires_at', p_expires_at,
      'conflict_acknowledged', p_conflict_acknowledged,
      'date_conflicts', v_date_conflicts
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id, v_date_conflicts)
    || jsonb_build_object('quote_id', v_quote_id);
end;
$$;

create or replace function public.accept_quote_server(
  p_conversation_id uuid,
  p_quote_id uuid,
  p_host_id uuid,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_quote public.booking_quotes%rowtype;
  v_booking_id uuid;
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
    raise exception 'Only the host can accept a quote.';
  end if;

  if not public.validate_booking_transition(v_conversation.stage, 'deposit_pending', 'host') then
    raise exception 'Quote cannot be accepted from the current stage.';
  end if;

  select *
  into v_quote
  from public.booking_quotes
  where id = p_quote_id
    and conversation_id = p_conversation_id
  for update;

  if not found then
    raise exception 'Quote not found.';
  end if;

  if v_quote.status <> 'pending' then
    raise exception 'Only a pending quote can be accepted.';
  end if;

  if v_quote.expires_at is not null and v_quote.expires_at <= v_now then
    raise exception 'This quote has expired.';
  end if;

  update public.booking_quotes
  set status = 'accepted'
  where id = v_quote.id;

  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'deposit_pending');

  update public.bookings
  set quote_id = v_quote.id,
      stage = 'deposit_pending',
      total_amount_cents = v_quote.total_amount_cents,
      deposit_amount_cents = v_quote.deposit_amount_cents,
      deposit_amount_label = v_quote.deposit_amount_label,
      currency = lower(coalesce(v_quote.currency, 'usd')),
      updated_at = v_now
  where id = v_booking_id;

  update public.conversations
  set stage = 'deposit_pending',
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
    'system',
    'Quote accepted. Deposit is now due to confirm the booking.',
    'text',
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
    'deposit_pending',
    p_host_id,
    'host',
    jsonb_build_object(
      'quote_id', v_quote.id,
      'intermediate_stage', 'accepted',
      'total_amount_cents', v_quote.total_amount_cents,
      'deposit_amount_cents', v_quote.deposit_amount_cents,
      'currency', lower(coalesce(v_quote.currency, 'usd'))
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

create or replace function public.pay_deposit_server(
  p_conversation_id uuid,
  p_host_id uuid,
  p_payment_intent_id text,
  p_deposit_method text default 'Apple Pay',
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking public.bookings%rowtype;
  v_existing_conversation_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_booking_id uuid;
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

  if btrim(coalesce(p_payment_intent_id, '')) = '' then
    raise exception 'A payment intent identifier is required.';
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
    raise exception 'Only the host can pay the deposit.';
  end if;

  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, v_conversation.stage);

  select *
  into v_booking
  from public.bookings
  where id = v_booking_id
  for update;

  if not public.validate_booking_transition(v_conversation.stage, 'confirmed', 'host')
     and not public.validate_booking_transition(v_conversation.stage, 'confirmed', 'system') then
    raise exception 'Deposit cannot be applied from the current stage.';
  end if;

  select conversation_id
  into v_existing_conversation_id
  from public.bookings
  where stripe_payment_intent_id = btrim(p_payment_intent_id)
  limit 1;

  if v_existing_conversation_id is not null and v_existing_conversation_id <> p_conversation_id then
    raise exception 'This payment intent has already been used.';
  end if;

  if v_existing_conversation_id = p_conversation_id
     and v_booking.stage in ('confirmed', 'completed') then
    return public.booking_transition_snapshot(p_conversation_id);
  end if;

  if v_booking.quote_id is null then
    raise exception 'A quote must be accepted before the deposit can be paid.';
  end if;

  update public.booking_quotes
  set status = 'paid'
  where id = v_booking.quote_id;

  update public.bookings
  set stage = 'confirmed',
      stripe_payment_intent_id = btrim(p_payment_intent_id),
      deposit_method = btrim(coalesce(p_deposit_method, 'Apple Pay')),
      deposit_paid_at = v_now,
      updated_at = v_now
  where id = v_booking_id;

  update public.conversations
  set stage = 'confirmed',
      last_activity_at = v_now
  where id = p_conversation_id;

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
    'Deposit paid. Booking confirmed.',
    'payment_receipt',
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
    'confirmed',
    p_host_id,
    'host',
    jsonb_build_object(
      'payment_intent_id', btrim(p_payment_intent_id),
      'deposit_method', btrim(coalesce(p_deposit_method, 'Apple Pay')),
      'event_date', v_booking.event_date
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

create or replace function public.decline_request_server(
  p_conversation_id uuid,
  p_vendor_id uuid,
  p_reason text default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_message text := 'The vendor declined this request.';
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
    raise exception 'Only the vendor can decline this request.';
  end if;

  if v_conversation.stage not in ('requested', 'vendor_reviewing') then
    raise exception 'Requests can only be declined while they are awaiting vendor review.';
  end if;

  v_booking_id := public.ensure_booking_for_conversation(p_conversation_id, 'declined');

  update public.bookings
  set stage = 'declined',
      updated_at = v_now
  where id = v_booking_id;

  update public.conversations
  set stage = 'declined',
      last_activity_at = v_now
  where id = p_conversation_id;

  if btrim(coalesce(p_reason, '')) <> '' then
    v_message := format('The vendor declined this request. %s', btrim(p_reason));
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
    v_message,
    'text',
    v_now
  );

  insert into public.booking_events (
    conversation_id,
    booking_id,
    from_stage,
    to_stage,
    triggered_by,
    trigger_role,
    reason,
    metadata,
    idempotency_key
  )
  values (
    p_conversation_id,
    v_booking_id,
    v_conversation.stage,
    'declined',
    p_vendor_id,
    'vendor',
    nullif(btrim(coalesce(p_reason, '')), ''),
    jsonb_build_object('reason_provided', btrim(coalesce(p_reason, '')) <> ''),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

create or replace function public.cancel_booking_server(
  p_conversation_id uuid,
  p_actor_id uuid,
  p_reason text default null,
  p_idempotency_key uuid default null
)
returns jsonb
language plpgsql
as $$
declare
  v_conversation public.conversations%rowtype;
  v_booking public.bookings%rowtype;
  v_trigger_role text;
  v_now timestamptz := timezone('utc', now());
  v_message text := 'The booking was cancelled.';
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

  if v_conversation.host_id = p_actor_id then
    v_trigger_role := 'host';
  elsif v_conversation.vendor_id = p_actor_id then
    v_trigger_role := 'vendor';
  else
    raise exception 'Only a conversation participant can cancel this booking.';
  end if;

  if not public.validate_booking_transition(v_conversation.stage, 'cancelled', v_trigger_role) then
    raise exception 'This booking cannot be cancelled from the current stage.';
  end if;

  perform public.ensure_booking_for_conversation(p_conversation_id, 'cancelled');

  select *
  into v_booking
  from public.bookings
  where conversation_id = p_conversation_id
  order by updated_at desc nulls last, created_at desc nulls last
  limit 1
  for update;

  update public.bookings
  set stage = 'cancelled',
      cancelled_by = p_actor_id,
      cancelled_at = v_now,
      cancellation_reason = nullif(btrim(coalesce(p_reason, '')), ''),
      updated_at = v_now
  where id = v_booking.id;

  update public.conversations
  set stage = 'cancelled',
      last_activity_at = v_now
  where id = p_conversation_id;

  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where vendor_id = v_conversation.vendor_id
      and date = v_booking.event_date
      and note = format('booking:%s', p_conversation_id);
  end if;

  if btrim(coalesce(p_reason, '')) <> '' then
    v_message := format('The booking was cancelled. %s', btrim(p_reason));
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
    v_message,
    'text',
    v_now
  );

  insert into public.booking_events (
    conversation_id,
    booking_id,
    from_stage,
    to_stage,
    triggered_by,
    trigger_role,
    reason,
    metadata,
    idempotency_key
  )
  values (
    p_conversation_id,
    v_booking.id,
    v_conversation.stage,
    'cancelled',
    p_actor_id,
    v_trigger_role,
    nullif(btrim(coalesce(p_reason, '')), ''),
    jsonb_build_object(
      'refund_required', v_conversation.stage = 'confirmed',
      'event_date', v_booking.event_date
    ),
    p_idempotency_key
  );

  return public.booking_transition_snapshot(p_conversation_id);
end;
$$;

revoke all on function public.booking_transition_snapshot(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.booking_transition_snapshot(uuid, jsonb) to service_role;

revoke all on function public.ensure_booking_for_conversation(uuid, text) from public, anon, authenticated;
grant execute on function public.ensure_booking_for_conversation(uuid, text) to service_role;

revoke all on function public.submit_booking_request_server(uuid, uuid, text, text, text, text[], text, text, uuid) from public, anon, authenticated;
grant execute on function public.submit_booking_request_server(uuid, uuid, text, text, text, text[], text, text, uuid) to service_role;

revoke all on function public.send_quote_server(uuid, uuid, text, text, text, integer, integer, timestamptz, text, text[], text, text, boolean, uuid) from public, anon, authenticated;
grant execute on function public.send_quote_server(uuid, uuid, text, text, text, integer, integer, timestamptz, text, text[], text, text, boolean, uuid) to service_role;

revoke all on function public.accept_quote_server(uuid, uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.accept_quote_server(uuid, uuid, uuid, uuid) to service_role;

revoke all on function public.pay_deposit_server(uuid, uuid, text, text, uuid) from public, anon, authenticated;
grant execute on function public.pay_deposit_server(uuid, uuid, text, text, uuid) to service_role;

revoke all on function public.decline_request_server(uuid, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.decline_request_server(uuid, uuid, text, uuid) to service_role;

revoke all on function public.cancel_booking_server(uuid, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.cancel_booking_server(uuid, uuid, text, uuid) to service_role;

revoke all on function public.check_vendor_date_conflicts(uuid, date, uuid) from public, anon;
grant execute on function public.check_vendor_date_conflicts(uuid, date, uuid) to authenticated, service_role;
