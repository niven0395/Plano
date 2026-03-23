-- =============================================================================
-- Quick Party ↔ Booking Bridge Migration
-- Covers: planned_vendors (B), multi-booking (C), event stage (F),
--         vendor control (D), booking robustness (H)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- B: planned_vendors table — persist vendor selections server-side
-- ---------------------------------------------------------------------------
create table if not exists public.planned_vendors (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  category text not null,
  status text not null check (status in ('planned', 'request_sent', 'booked', 'removed')) default 'planned',
  availability_checked_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (event_id, vendor_id)
);

create index if not exists planned_vendors_event_id_idx
on public.planned_vendors (event_id);

create index if not exists planned_vendors_vendor_id_idx
on public.planned_vendors (vendor_id);

create index if not exists planned_vendors_status_idx
on public.planned_vendors (status);

drop trigger if exists planned_vendors_set_updated_at on public.planned_vendors;
create trigger planned_vendors_set_updated_at
before update on public.planned_vendors
for each row execute function public.set_updated_at();

alter table public.planned_vendors enable row level security;

drop policy if exists "Hosts can read own planned vendors" on public.planned_vendors;
create policy "Hosts can read own planned vendors"
on public.planned_vendors
for select
using (
  exists (
    select 1 from public.events
    where events.id = planned_vendors.event_id
      and events.host_id = auth.uid()
  )
);

drop policy if exists "Hosts can insert own planned vendors" on public.planned_vendors;
create policy "Hosts can insert own planned vendors"
on public.planned_vendors
for insert
with check (
  exists (
    select 1 from public.events
    where events.id = planned_vendors.event_id
      and events.host_id = auth.uid()
  )
);

drop policy if exists "Hosts can update own planned vendors" on public.planned_vendors;
create policy "Hosts can update own planned vendors"
on public.planned_vendors
for update
using (
  exists (
    select 1 from public.events
    where events.id = planned_vendors.event_id
      and events.host_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.events
    where events.id = planned_vendors.event_id
      and events.host_id = auth.uid()
  )
);

drop policy if exists "Hosts can delete own planned vendors" on public.planned_vendors;
create policy "Hosts can delete own planned vendors"
on public.planned_vendors
for delete
using (
  exists (
    select 1 from public.events
    where events.id = planned_vendors.event_id
      and events.host_id = auth.uid()
  )
);

-- ---------------------------------------------------------------------------
-- C: Multi-booking per day — replace UNIQUE(vendor_id, date) with capacity
-- ---------------------------------------------------------------------------

-- Drop the old unique constraint that prevents multiple bookings per day
alter table public.vendor_availability
  drop constraint if exists vendor_availability_vendor_id_date_key;

-- Add booking_id and conversation_id columns to tie availability to bookings
alter table public.vendor_availability
  add column if not exists booking_id uuid references public.bookings (id) on delete set null,
  add column if not exists conversation_id uuid references public.conversations (id) on delete set null;

-- New unique constraint: one availability row per vendor+date+booking
-- This allows multiple bookings on the same date for the same vendor
create unique index if not exists vendor_availability_vendor_date_booking_idx
on public.vendor_availability (vendor_id, date, coalesce(booking_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- D: Vendor control panel fields
alter table public.vendor_profiles
  add column if not exists daily_event_capacity integer not null default 1,
  add column if not exists minimum_event_spend_cents integer,
  add column if not exists preferred_event_types text[] not null default '{}'::text[],
  add column if not exists max_pending_leads integer;

-- ---------------------------------------------------------------------------
-- F: Event stage — separate from booking stage
-- ---------------------------------------------------------------------------
alter table public.events
  add column if not exists event_stage text not null default 'planning'
    check (event_stage in (
      'planning',
      'requesting',
      'confirming',
      'ready',
      'completed',
      'cancelled'
    ));

-- ---------------------------------------------------------------------------
-- H: Booking robustness — vendor_category on bookings
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists vendor_category text;

-- Backfill vendor_category from conversations
update public.bookings
set vendor_category = conversations.vendor_category
from public.conversations
where bookings.conversation_id = conversations.id
  and bookings.vendor_category is null;

-- ---------------------------------------------------------------------------
-- C: Updated conflict check that respects vendor capacity
-- ---------------------------------------------------------------------------
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

-- Helper function to check if vendor has capacity on a given date
create or replace function public.vendor_has_capacity(
  p_vendor_id uuid,
  p_date date,
  p_exclude_booking_id uuid default null
)
returns boolean
language sql
stable
as $$
  select (
    select coalesce(vp.daily_event_capacity, 1)
    from public.vendor_profiles vp
    where vp.user_id = p_vendor_id
  ) > (
    select count(*)
    from public.vendor_availability va
    where va.vendor_id = p_vendor_id
      and va.date = p_date
      and va.status = 'booked'
      and (p_exclude_booking_id is null or va.booking_id is distinct from p_exclude_booking_id)
  );
$$;

-- ---------------------------------------------------------------------------
-- Update pay_deposit_server to use capacity-aware availability
-- ---------------------------------------------------------------------------
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

  -- Check vendor capacity before confirming
  if v_booking.event_date is not null
     and not public.vendor_has_capacity(v_conversation.vendor_id, v_booking.event_date, v_booking_id) then
    raise exception 'This vendor has reached their daily event capacity for this date.';
  end if;

  update public.booking_quotes
  set status = 'paid'
  where id = v_booking.quote_id;

  update public.bookings
  set stage = 'confirmed',
      stripe_payment_intent_id = btrim(p_payment_intent_id),
      deposit_method = btrim(coalesce(p_deposit_method, 'Apple Pay')),
      deposit_paid_at = v_now,
      vendor_category = coalesce(v_booking.vendor_category, v_conversation.vendor_category),
      updated_at = v_now
  where id = v_booking_id;

  update public.conversations
  set stage = 'confirmed',
      last_activity_at = v_now
  where id = p_conversation_id;

  -- Insert availability with booking reference (multi-booking aware)
  if v_booking.event_date is not null then
    insert into public.vendor_availability (
      vendor_id,
      date,
      status,
      booking_id,
      conversation_id,
      note
    )
    values (
      v_conversation.vendor_id,
      v_booking.event_date,
      'booked',
      v_booking_id,
      p_conversation_id,
      format('booking:%s', p_conversation_id)
    )
    on conflict (vendor_id, date, coalesce(booking_id, '00000000-0000-0000-0000-000000000000'::uuid))
    do update set
      status = excluded.status,
      conversation_id = excluded.conversation_id,
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

-- ---------------------------------------------------------------------------
-- Update cancel_booking_server to delete the specific availability row
-- ---------------------------------------------------------------------------
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

  -- Delete specific availability row by booking_id (multi-booking aware)
  if v_booking.event_date is not null then
    delete from public.vendor_availability
    where vendor_id = v_conversation.vendor_id
      and date = v_booking.event_date
      and booking_id = v_booking.id;

    -- Fallback: also clean up legacy rows matched by note
    delete from public.vendor_availability
    where vendor_id = v_conversation.vendor_id
      and date = v_booking.event_date
      and booking_id is null
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

-- Grant permissions
revoke all on function public.vendor_has_capacity(uuid, date, uuid) from public, anon;
grant execute on function public.vendor_has_capacity(uuid, date, uuid) to authenticated, service_role;
