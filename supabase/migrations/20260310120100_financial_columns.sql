alter table public.booking_quotes
  add column if not exists total_amount_cents integer,
  add column if not exists deposit_amount_cents integer,
  add column if not exists expires_at timestamptz,
  add column if not exists currency text not null default 'usd';

alter table public.booking_quotes
  drop constraint if exists booking_quotes_total_amount_cents_check,
  drop constraint if exists booking_quotes_deposit_amount_cents_check,
  drop constraint if exists booking_quotes_deposit_lte_total_check;

alter table public.booking_quotes
  add constraint booking_quotes_total_amount_cents_check
  check (total_amount_cents is null or total_amount_cents > 0),
  add constraint booking_quotes_deposit_amount_cents_check
  check (deposit_amount_cents is null or deposit_amount_cents > 0),
  add constraint booking_quotes_deposit_lte_total_check
  check (
    total_amount_cents is null
    or deposit_amount_cents is null
    or deposit_amount_cents <= total_amount_cents
  );

create index if not exists booking_quotes_expires_at_idx
on public.booking_quotes (expires_at);

alter table public.bookings
  alter column deposit_amount_label drop not null;

alter table public.bookings
  add column if not exists deposit_amount_cents integer,
  add column if not exists total_amount_cents integer,
  add column if not exists currency text not null default 'usd',
  add column if not exists event_date date,
  add column if not exists stripe_payment_intent_id text,
  add column if not exists cancelled_by uuid references public.users (id) on delete set null,
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancellation_reason text;

alter table public.bookings
  drop constraint if exists bookings_total_amount_cents_check,
  drop constraint if exists bookings_deposit_amount_cents_check,
  drop constraint if exists bookings_deposit_lte_total_check;

alter table public.bookings
  add constraint bookings_total_amount_cents_check
  check (total_amount_cents is null or total_amount_cents > 0),
  add constraint bookings_deposit_amount_cents_check
  check (deposit_amount_cents is null or deposit_amount_cents > 0),
  add constraint bookings_deposit_lte_total_check
  check (
    total_amount_cents is null
    or deposit_amount_cents is null
    or deposit_amount_cents <= total_amount_cents
  );

create index if not exists bookings_vendor_id_event_date_stage_idx
on public.bookings (vendor_id, event_date, stage);

create unique index if not exists bookings_stripe_payment_intent_id_unique_idx
on public.bookings (stripe_payment_intent_id)
where stripe_payment_intent_id is not null;

alter table public.booking_requests
  add column if not exists event_date date;

create index if not exists booking_requests_event_date_idx
on public.booking_requests (event_date);

create unique index if not exists conversations_event_vendor_host_unique_idx
on public.conversations (event_id, vendor_id, host_id)
where event_id is not null;

update public.booking_requests
set event_date = source.event_date
from (
  select
    conversations.id as conversation_id,
    (timezone('utc', events.date))::date as event_date
  from public.conversations
  join public.events
    on events.id = conversations.event_id
) as source
where booking_requests.conversation_id = source.conversation_id
  and booking_requests.event_date is null;

update public.bookings
set event_date = source.event_date
from (
  select
    conversations.id as conversation_id,
    (timezone('utc', events.date))::date as event_date
  from public.conversations
  join public.events
    on events.id = conversations.event_id
) as source
where bookings.conversation_id = source.conversation_id
  and bookings.event_date is null;
