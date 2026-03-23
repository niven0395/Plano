create table public.vendor_notes (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  content text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (conversation_id, vendor_id)
);

alter table public.vendor_notes enable row level security;

create policy "Vendors read own notes" on public.vendor_notes
  for select using (vendor_id = auth.uid());
create policy "Vendors insert own notes" on public.vendor_notes
  for insert with check (vendor_id = auth.uid());
create policy "Vendors update own notes" on public.vendor_notes
  for update using (vendor_id = auth.uid());
