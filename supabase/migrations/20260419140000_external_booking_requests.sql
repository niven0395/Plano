-- Migration: external_booking_requests table + request-first flow
--
-- Web form submissions used to create a full conversation + booking_request +
-- invite immediately. That bled into the vendor's chat inbox before they had a
-- chance to review. Web submissions now land in a dedicated
-- external_booking_requests table with status='pending'. The vendor sees them
-- in their requests view, and a conversation + booking is only created when
-- the vendor accepts.

begin;

-- 1. external_booking_requests table

create table if not exists public.external_booking_requests (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.users(id) on delete cascade,
  first_name text not null,
  last_name text not null,
  email text not null,
  event_date date not null,
  guest_count int,
  note text not null default '',
  intake_answers jsonb not null default '[]'::jsonb,
  source text not null default 'web' check (source in ('web')),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  accepted_conversation_id uuid references public.conversations(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists external_booking_requests_vendor_pending_idx
  on public.external_booking_requests (vendor_id, created_at desc)
  where status = 'pending';

create index if not exists external_booking_requests_email_idx
  on public.external_booking_requests (lower(email));

alter table public.external_booking_requests enable row level security;
-- Service-role only at the table level; RPCs control vendor/public access.

-- 2. Replace submit_external_booking_request: insert into new table only

create or replace function public.submit_external_booking_request(
  p_vendor_id uuid,
  p_first_name text,
  p_last_name text,
  p_email text,
  p_event_date date,
  p_guest_count int default null,
  p_note text default '',
  p_intake_answers jsonb default '[]'::jsonb,
  p_source text default 'web'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_request_id uuid;
  v_email text := lower(trim(p_email));
  v_first text := trim(p_first_name);
  v_last text := trim(p_last_name);
begin
  if v_email is null or v_email = '' or v_email not like '%@%' then
    raise exception 'A valid email address is required.';
  end if;
  if v_first is null or v_first = '' or v_last is null or v_last = '' then
    raise exception 'First and last name are required.';
  end if;
  if p_event_date is null then
    raise exception 'Event date is required.';
  end if;

  if not exists (select 1 from public.vendor_profiles where user_id = p_vendor_id) then
    raise exception 'Vendor not found.';
  end if;

  insert into public.external_booking_requests (
    vendor_id, first_name, last_name, email, event_date,
    guest_count, note, intake_answers, source, status
  )
  values (
    p_vendor_id, v_first, v_last, v_email, p_event_date,
    p_guest_count, coalesce(p_note, ''), coalesce(p_intake_answers, '[]'::jsonb),
    coalesce(p_source, 'web'), 'pending'
  )
  returning id into v_request_id;

  return jsonb_build_object('request_id', v_request_id);
end;
$$;

revoke all on function public.submit_external_booking_request(
  uuid, text, text, text, date, int, text, jsonb, text
) from public, anon, authenticated;
grant execute on function public.submit_external_booking_request(
  uuid, text, text, text, date, int, text, jsonb, text
) to service_role;

-- 3. list_pending_external_requests_for_vendor — vendor reads their own queue

create or replace function public.list_pending_external_requests_for_vendor()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_vendor_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_vendor_id is null then
    raise exception 'Not authenticated.';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', r.id,
      'vendor_id', r.vendor_id,
      'first_name', r.first_name,
      'last_name', r.last_name,
      'email', r.email,
      'event_date', r.event_date,
      'guest_count', r.guest_count,
      'note', r.note,
      'intake_answers', r.intake_answers,
      'source', r.source,
      'status', r.status,
      'created_at', r.created_at
    ) order by r.created_at desc
  ), '[]'::jsonb)
  into v_result
  from public.external_booking_requests r
  where r.vendor_id = v_vendor_id and r.status = 'pending';

  return v_result;
end;
$$;

revoke all on function public.list_pending_external_requests_for_vendor()
  from public, anon;
grant execute on function public.list_pending_external_requests_for_vendor()
  to authenticated, service_role;

-- 4. accept_external_booking_request — vendor accepts a pending request

create or replace function public.accept_external_booking_request(
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_vendor_id uuid := auth.uid();
  v_request public.external_booking_requests%rowtype;
  v_vendor public.vendor_profiles%rowtype;
  v_conversation_id uuid;
  v_booking_request_id uuid;
  v_booking_id uuid;
  v_token text;
  v_host_display text;
  v_event_date_label text;
  v_event_context_line text;
  v_guest_label text;
  v_now timestamptz := timezone('utc', now());
begin
  if v_vendor_id is null then
    raise exception 'Not authenticated.';
  end if;

  select * into v_request
  from public.external_booking_requests
  where id = p_request_id
  for update;
  if not found then
    raise exception 'Request not found.';
  end if;
  if v_request.vendor_id <> v_vendor_id then
    raise exception 'Not authorized for this request.';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'Request is no longer pending (status: %).', v_request.status;
  end if;

  select * into v_vendor
  from public.vendor_profiles
  where user_id = v_vendor_id;
  if not found then
    raise exception 'Vendor profile not found.';
  end if;

  v_host_display := v_request.first_name || ' ' || v_request.last_name;
  v_event_date_label := to_char(v_request.event_date, 'Mon DD, YYYY');
  v_event_context_line := 'Booking request for ' || v_event_date_label;
  if v_request.guest_count is not null and v_request.guest_count > 0 then
    v_guest_label := v_request.guest_count::text || ' guests';
  else
    v_guest_label := '';
  end if;

  -- Conversation for the chat thread (host_id stays NULL until guest claims).
  insert into public.conversations (
    event_id, vendor_id, host_id, host_display_name, vendor_display_name,
    vendor_category, event_title, event_date_label, event_context_line,
    stage, last_activity_at, created_at, updated_at,
    external_email, external_first_name, external_last_name, external_source
  )
  values (
    null, v_vendor_id, null, v_host_display, v_vendor.business_name,
    coalesce(v_vendor.category, 'General'), 'Booking request',
    v_event_date_label, v_event_context_line,
    'accepted', v_now, v_now, v_now,
    v_request.email, v_request.first_name, v_request.last_name, v_request.source
  )
  returning id into v_conversation_id;

  -- booking_requests row so the inbox renders the request details card.
  insert into public.booking_requests (
    conversation_id, title, budget_label, response_window_label,
    requested_services, note, guest_count_label, event_date, intake_answers
  )
  values (
    v_conversation_id, 'External booking request', '', '',
    '{}'::text[], v_request.note, v_guest_label, v_request.event_date,
    v_request.intake_answers
  )
  returning id into v_booking_request_id;

  -- bookings row with host_id=NULL. Claim flow attaches host_id on sign-in.
  insert into public.bookings (
    conversation_id, event_id, vendor_id, host_id, stage, created_at, updated_at
  )
  values (
    v_conversation_id, null, v_vendor_id, null, 'accepted', v_now, v_now
  )
  returning id into v_booking_id;

  -- System message visible to the vendor once the guest joins.
  insert into public.messages (conversation_id, sender_role, body, kind, created_at)
  values (
    v_conversation_id, 'system',
    'You accepted ' || v_host_display || '''s booking for ' || v_event_date_label,
    'system', v_now
  );

  -- Claim invite — 60-day expiry so the guest has time to install.
  v_token := encode(extensions.gen_random_bytes(24), 'base64');
  v_token := replace(replace(replace(v_token, '+', '-'), '/', '_'), '=', '');
  insert into public.external_booking_invites (conversation_id, email, token, expires_at)
  values (v_conversation_id, v_request.email, v_token, v_now + interval '60 days');

  -- Accepted email: "vendor accepted your booking — download Plano to chat"
  insert into public.external_email_jobs (conversation_id, kind, payload)
  values (
    v_conversation_id, 'vendor_accepted',
    jsonb_build_object(
      'vendor_name', v_vendor.business_name,
      'event_date_label', v_event_date_label,
      'first_name', v_request.first_name
    )
  );

  update public.external_booking_requests
  set status = 'accepted',
      accepted_conversation_id = v_conversation_id,
      updated_at = v_now
  where id = p_request_id;

  return jsonb_build_object(
    'request_id', p_request_id,
    'conversation_id', v_conversation_id,
    'booking_id', v_booking_id,
    'invite_token', v_token
  );
end;
$$;

revoke all on function public.accept_external_booking_request(uuid)
  from public, anon;
grant execute on function public.accept_external_booking_request(uuid)
  to authenticated, service_role;

-- 5. decline_external_booking_request — vendor declines a pending request

create or replace function public.decline_external_booking_request(
  p_request_id uuid,
  p_reason text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vendor_id uuid := auth.uid();
  v_request public.external_booking_requests%rowtype;
  v_now timestamptz := timezone('utc', now());
begin
  if v_vendor_id is null then
    raise exception 'Not authenticated.';
  end if;

  select * into v_request
  from public.external_booking_requests
  where id = p_request_id
  for update;
  if not found then
    raise exception 'Request not found.';
  end if;
  if v_request.vendor_id <> v_vendor_id then
    raise exception 'Not authorized for this request.';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'Request is no longer pending (status: %).', v_request.status;
  end if;

  update public.external_booking_requests
  set status = 'declined', updated_at = v_now
  where id = p_request_id;

  return jsonb_build_object('request_id', p_request_id, 'status', 'declined');
end;
$$;

revoke all on function public.decline_external_booking_request(uuid, text)
  from public, anon;
grant execute on function public.decline_external_booking_request(uuid, text)
  to authenticated, service_role;

commit;
