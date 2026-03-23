create table if not exists public.vendor_availability (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  date date not null,
  status text not null check (status in ('booked', 'blocked', 'hold')),
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (vendor_id, date)
);

create index if not exists vendor_availability_vendor_id_date_idx
on public.vendor_availability (vendor_id, date);

create index if not exists vendor_availability_date_status_idx
on public.vendor_availability (date, status);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events (id) on delete set null,
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  host_id uuid not null references public.users (id) on delete cascade,
  host_display_name text not null,
  vendor_display_name text not null,
  vendor_category text not null,
  event_title text,
  event_date_label text,
  event_context_line text,
  stage text not null check (
    stage in (
      'draft',
      'requested',
      'vendor_reviewing',
      'quoted',
      'host_reviewing',
      'accepted',
      'deposit_pending',
      'confirmed',
      'declined',
      'cancelled',
      'completed'
    )
  ) default 'requested',
  last_activity_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists conversations_host_id_last_activity_idx
on public.conversations (host_id, last_activity_at desc);

create index if not exists conversations_vendor_id_last_activity_idx
on public.conversations (vendor_id, last_activity_at desc);

create index if not exists conversations_event_id_last_activity_idx
on public.conversations (event_id, last_activity_at desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_role text not null check (sender_role in ('host', 'vendor', 'system')),
  body text not null,
  kind text not null check (kind in ('text', 'booking_request', 'quote', 'payment_receipt')) default 'text',
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists messages_conversation_id_created_at_idx
on public.messages (conversation_id, created_at);

create table if not exists public.booking_requests (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  title text not null,
  budget_label text not null,
  response_window_label text not null,
  requested_services text[] not null default '{}'::text[],
  note text not null default '',
  guest_count_label text not null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists booking_requests_conversation_id_created_at_idx
on public.booking_requests (conversation_id, created_at desc);

create table if not exists public.booking_quotes (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  title text not null,
  total_amount_label text not null,
  deposit_amount_label text not null,
  expires_at_label text not null,
  turnaround_label text not null,
  included_items text[] not null default '{}'::text[],
  note text not null default '',
  status text not null check (status in ('pending', 'accepted', 'paid')) default 'pending',
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists booking_quotes_conversation_id_created_at_idx
on public.booking_quotes (conversation_id, created_at desc);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  quote_id uuid references public.booking_quotes (id) on delete set null,
  event_id uuid references public.events (id) on delete set null,
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  host_id uuid not null references public.users (id) on delete cascade,
  deposit_amount_label text not null,
  deposit_method text,
  deposit_paid_at timestamptz,
  stage text not null check (
    stage in (
      'draft',
      'requested',
      'vendor_reviewing',
      'quoted',
      'host_reviewing',
      'accepted',
      'deposit_pending',
      'confirmed',
      'declined',
      'cancelled',
      'completed'
    )
  ) default 'requested',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists bookings_host_id_stage_idx
on public.bookings (host_id, stage, created_at desc);

create index if not exists bookings_vendor_id_stage_idx
on public.bookings (vendor_id, stage, created_at desc);

create index if not exists bookings_conversation_id_idx
on public.bookings (conversation_id);

drop trigger if exists conversations_set_updated_at on public.conversations;
create trigger conversations_set_updated_at
before update on public.conversations
for each row execute function public.set_updated_at();

drop trigger if exists bookings_set_updated_at on public.bookings;
create trigger bookings_set_updated_at
before update on public.bookings
for each row execute function public.set_updated_at();

alter table public.vendor_availability enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.booking_requests enable row level security;
alter table public.booking_quotes enable row level security;
alter table public.bookings enable row level security;

drop policy if exists "Anyone can read vendor availability" on public.vendor_availability;
create policy "Anyone can read vendor availability"
on public.vendor_availability
for select
using (true);

drop policy if exists "Vendors can insert own availability" on public.vendor_availability;
create policy "Vendors can insert own availability"
on public.vendor_availability
for insert
with check (vendor_id = auth.uid());

drop policy if exists "Vendors can update own availability" on public.vendor_availability;
create policy "Vendors can update own availability"
on public.vendor_availability
for update
using (vendor_id = auth.uid())
with check (vendor_id = auth.uid());

drop policy if exists "Vendors can delete own availability" on public.vendor_availability;
create policy "Vendors can delete own availability"
on public.vendor_availability
for delete
using (vendor_id = auth.uid());

drop policy if exists "Participants can read conversations" on public.conversations;
create policy "Participants can read conversations"
on public.conversations
for select
using (host_id = auth.uid() or vendor_id = auth.uid());

drop policy if exists "Hosts can create conversations" on public.conversations;
create policy "Hosts can create conversations"
on public.conversations
for insert
with check (host_id = auth.uid());

drop policy if exists "Participants can update conversations" on public.conversations;
create policy "Participants can update conversations"
on public.conversations
for update
using (host_id = auth.uid() or vendor_id = auth.uid())
with check (host_id = auth.uid() or vendor_id = auth.uid());

drop policy if exists "Participants can read messages" on public.messages;
create policy "Participants can read messages"
on public.messages
for select
using (
  exists (
    select 1
    from public.conversations
    where conversations.id = messages.conversation_id
      and (conversations.host_id = auth.uid() or conversations.vendor_id = auth.uid())
  )
);

drop policy if exists "Participants can create messages" on public.messages;
create policy "Participants can create messages"
on public.messages
for insert
with check (
  exists (
    select 1
    from public.conversations
    where conversations.id = messages.conversation_id
      and (
        (messages.sender_role = 'host' and conversations.host_id = auth.uid())
        or (messages.sender_role = 'vendor' and conversations.vendor_id = auth.uid())
        or (
          messages.sender_role = 'system'
          and (conversations.host_id = auth.uid() or conversations.vendor_id = auth.uid())
        )
      )
  )
);

drop policy if exists "Participants can read booking requests" on public.booking_requests;
create policy "Participants can read booking requests"
on public.booking_requests
for select
using (
  exists (
    select 1
    from public.conversations
    where conversations.id = booking_requests.conversation_id
      and (conversations.host_id = auth.uid() or conversations.vendor_id = auth.uid())
  )
);

drop policy if exists "Hosts can create booking requests" on public.booking_requests;
create policy "Hosts can create booking requests"
on public.booking_requests
for insert
with check (
  exists (
    select 1
    from public.conversations
    where conversations.id = booking_requests.conversation_id
      and conversations.host_id = auth.uid()
  )
);

drop policy if exists "Participants can read booking quotes" on public.booking_quotes;
create policy "Participants can read booking quotes"
on public.booking_quotes
for select
using (
  exists (
    select 1
    from public.conversations
    where conversations.id = booking_quotes.conversation_id
      and (conversations.host_id = auth.uid() or conversations.vendor_id = auth.uid())
  )
);

drop policy if exists "Vendors can create booking quotes" on public.booking_quotes;
create policy "Vendors can create booking quotes"
on public.booking_quotes
for insert
with check (
  exists (
    select 1
    from public.conversations
    where conversations.id = booking_quotes.conversation_id
      and conversations.vendor_id = auth.uid()
  )
);

drop policy if exists "Participants can update booking quotes" on public.booking_quotes;
create policy "Participants can update booking quotes"
on public.booking_quotes
for update
using (
  exists (
    select 1
    from public.conversations
    where conversations.id = booking_quotes.conversation_id
      and (conversations.host_id = auth.uid() or conversations.vendor_id = auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.conversations
    where conversations.id = booking_quotes.conversation_id
      and (conversations.host_id = auth.uid() or conversations.vendor_id = auth.uid())
  )
);

drop policy if exists "Participants can read bookings" on public.bookings;
create policy "Participants can read bookings"
on public.bookings
for select
using (host_id = auth.uid() or vendor_id = auth.uid());

drop policy if exists "Participants can create bookings" on public.bookings;
create policy "Participants can create bookings"
on public.bookings
for insert
with check (host_id = auth.uid() or vendor_id = auth.uid());

drop policy if exists "Participants can update bookings" on public.bookings;
create policy "Participants can update bookings"
on public.bookings
for update
using (host_id = auth.uid() or vendor_id = auth.uid())
with check (host_id = auth.uid() or vendor_id = auth.uid());
