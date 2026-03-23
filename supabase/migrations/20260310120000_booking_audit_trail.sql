create table if not exists public.booking_events (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  booking_id uuid references public.bookings (id) on delete set null,
  from_stage text not null check (
    from_stage in (
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
  ),
  to_stage text not null check (
    to_stage in (
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
  ),
  triggered_by uuid references public.users (id) on delete set null,
  trigger_role text not null check (trigger_role in ('host', 'vendor', 'system')),
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  idempotency_key uuid,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists booking_events_conversation_id_created_at_idx
on public.booking_events (conversation_id, created_at desc);

create index if not exists booking_events_booking_id_created_at_idx
on public.booking_events (booking_id, created_at desc);

create unique index if not exists booking_events_idempotency_key_unique_idx
on public.booking_events (idempotency_key)
where idempotency_key is not null;

alter table public.booking_events enable row level security;

drop policy if exists "Participants can read booking events" on public.booking_events;
create policy "Participants can read booking events"
on public.booking_events
for select
using (
  exists (
    select 1
    from public.conversations
    where conversations.id = booking_events.conversation_id
      and (conversations.host_id = auth.uid() or conversations.vendor_id = auth.uid())
  )
);

drop policy if exists "Direct booking event inserts disabled" on public.booking_events;
create policy "Direct booking event inserts disabled"
on public.booking_events
for insert
with check (false);

drop policy if exists "Direct booking event updates disabled" on public.booking_events;
create policy "Direct booking event updates disabled"
on public.booking_events
for update
using (false)
with check (false);

drop policy if exists "Direct booking event deletes disabled" on public.booking_events;
create policy "Direct booking event deletes disabled"
on public.booking_events
for delete
using (false);
