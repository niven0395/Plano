-- =============================================================================
-- Vendor analytics: raw event stream, daily aggregates, category benchmarks
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. analytics_events — raw event stream
-- ---------------------------------------------------------------------------

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null check (
    event_type in (
      'search_impression',
      'profile_view',
      'gallery_scroll',
      'social_link_click',
      'vendor_saved',
      'vendor_unsaved',
      'conversation_started',
      'booking_requested',
      'booking_confirmed',
      'booking_completed',
      'booking_declined',
      'booking_cancelled'
    )
  ),
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  actor_id uuid references auth.users (id) on delete set null,
  event_id uuid references public.events (id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists analytics_events_vendor_id_created_at_idx
on public.analytics_events (vendor_id, created_at);

create index if not exists analytics_events_event_type_created_at_idx
on public.analytics_events (event_type, created_at);

alter table public.analytics_events enable row level security;

-- No authenticated policies — all access via service_role only.
-- Privacy: hosts are never individually identifiable to vendors.

-- ---------------------------------------------------------------------------
-- 2. vendor_analytics_daily — pre-aggregated daily snapshots
-- ---------------------------------------------------------------------------

create table if not exists public.vendor_analytics_daily (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendor_profiles (user_id) on delete cascade,
  period_date date not null,
  search_impressions integer not null default 0,
  profile_views integer not null default 0,
  gallery_scrolls integer not null default 0,
  social_link_clicks integer not null default 0,
  vendors_saved integer not null default 0,
  vendors_unsaved integer not null default 0,
  conversations_started integer not null default 0,
  bookings_requested integer not null default 0,
  bookings_confirmed integer not null default 0,
  bookings_completed integer not null default 0,
  bookings_declined integer not null default 0,
  bookings_cancelled integer not null default 0,
  unique_profile_viewers integer not null default 0,
  revenue_confirmed_cents bigint not null default 0,
  revenue_completed_cents bigint not null default 0,
  avg_response_minutes numeric(10,2),
  avg_search_position numeric(10,2),
  top_search_queries jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint vendor_analytics_daily_vendor_period_unique unique (vendor_id, period_date)
);

alter table public.vendor_analytics_daily enable row level security;

drop trigger if exists vendor_analytics_daily_set_updated_at on public.vendor_analytics_daily;
create trigger vendor_analytics_daily_set_updated_at
before update on public.vendor_analytics_daily
for each row execute function public.set_updated_at();

drop policy if exists "Vendors can read own analytics" on public.vendor_analytics_daily;
create policy "Vendors can read own analytics"
on public.vendor_analytics_daily
for select
using (vendor_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3. category_benchmarks_daily — category averages
-- ---------------------------------------------------------------------------

create table if not exists public.category_benchmarks_daily (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  period_date date not null,
  avg_response_minutes numeric(10,2),
  avg_conversion_rate numeric(5,4),
  avg_profile_view_count numeric(10,2),
  median_rating numeric(3,2),
  vendor_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint category_benchmarks_daily_category_period_unique unique (category, period_date)
);

alter table public.category_benchmarks_daily enable row level security;

drop trigger if exists category_benchmarks_daily_set_updated_at on public.category_benchmarks_daily;
create trigger category_benchmarks_daily_set_updated_at
before update on public.category_benchmarks_daily
for each row execute function public.set_updated_at();

drop policy if exists "Authenticated users can read category benchmarks" on public.category_benchmarks_daily;
create policy "Authenticated users can read category benchmarks"
on public.category_benchmarks_daily
for select
using (auth.role() = 'authenticated');

-- ---------------------------------------------------------------------------
-- 4. aggregate_vendor_analytics_daily(target_date date)
-- ---------------------------------------------------------------------------

create or replace function public.aggregate_vendor_analytics_daily(target_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start timestamptz := target_date::timestamptz;
  v_end   timestamptz := (target_date + interval '1 day')::timestamptz;
begin
  -- -------------------------------------------------------------------------
  -- 4a. Upsert vendor_analytics_daily from analytics_events
  -- -------------------------------------------------------------------------
  insert into public.vendor_analytics_daily (
    vendor_id,
    period_date,
    search_impressions,
    profile_views,
    gallery_scrolls,
    social_link_clicks,
    vendors_saved,
    vendors_unsaved,
    conversations_started,
    bookings_requested,
    bookings_confirmed,
    bookings_completed,
    bookings_declined,
    bookings_cancelled,
    unique_profile_viewers
  )
  select
    ae.vendor_id,
    target_date,
    count(*) filter (where ae.event_type = 'search_impression'),
    count(*) filter (where ae.event_type = 'profile_view'),
    count(*) filter (where ae.event_type = 'gallery_scroll'),
    count(*) filter (where ae.event_type = 'social_link_click'),
    count(*) filter (where ae.event_type = 'vendor_saved'),
    count(*) filter (where ae.event_type = 'vendor_unsaved'),
    count(*) filter (where ae.event_type = 'conversation_started'),
    count(*) filter (where ae.event_type = 'booking_requested'),
    count(*) filter (where ae.event_type = 'booking_confirmed'),
    count(*) filter (where ae.event_type = 'booking_completed'),
    count(*) filter (where ae.event_type = 'booking_declined'),
    count(*) filter (where ae.event_type = 'booking_cancelled'),
    count(distinct ae.actor_id) filter (where ae.event_type = 'profile_view')
  from public.analytics_events ae
  where ae.created_at >= v_start
    and ae.created_at < v_end
  group by ae.vendor_id
  on conflict (vendor_id, period_date) do update set
    search_impressions    = excluded.search_impressions,
    profile_views         = excluded.profile_views,
    gallery_scrolls       = excluded.gallery_scrolls,
    social_link_clicks    = excluded.social_link_clicks,
    vendors_saved         = excluded.vendors_saved,
    vendors_unsaved       = excluded.vendors_unsaved,
    conversations_started = excluded.conversations_started,
    bookings_requested    = excluded.bookings_requested,
    bookings_confirmed    = excluded.bookings_confirmed,
    bookings_completed    = excluded.bookings_completed,
    bookings_declined     = excluded.bookings_declined,
    bookings_cancelled    = excluded.bookings_cancelled,
    unique_profile_viewers = excluded.unique_profile_viewers;

  -- -------------------------------------------------------------------------
  -- 4b. Compute avg_response_minutes per vendor
  --     For conversations created on target_date, find the first vendor
  --     message and compute the difference from conversation created_at.
  -- -------------------------------------------------------------------------
  update public.vendor_analytics_daily vad
  set avg_response_minutes = resp.avg_minutes
  from (
    select
      c.vendor_id,
      avg(
        extract(epoch from (first_vendor_msg.created_at - c.created_at)) / 60.0
      )::numeric(10,2) as avg_minutes
    from public.conversations c
    inner join lateral (
      select m.created_at
      from public.messages m
      where m.conversation_id = c.id
        and m.sender_role = 'vendor'
      order by m.created_at asc
      limit 1
    ) first_vendor_msg on true
    where c.created_at >= v_start
      and c.created_at < v_end
    group by c.vendor_id
  ) resp
  where vad.vendor_id = resp.vendor_id
    and vad.period_date = target_date;

  -- -------------------------------------------------------------------------
  -- 4c. Compute top_search_queries from metadata->>'query' frequency
  -- -------------------------------------------------------------------------
  update public.vendor_analytics_daily vad
  set top_search_queries = coalesce(sq.queries, '[]'::jsonb)
  from (
    select
      ae.vendor_id,
      jsonb_agg(
        jsonb_build_object('query', query_text, 'count', query_count)
        order by query_count desc
      ) as queries
    from (
      select
        ae2.vendor_id,
        ae2.metadata->>'query' as query_text,
        count(*) as query_count
      from public.analytics_events ae2
      where ae2.event_type = 'search_impression'
        and ae2.created_at >= v_start
        and ae2.created_at < v_end
        and ae2.metadata->>'query' is not null
        and ae2.metadata->>'query' <> ''
      group by ae2.vendor_id, ae2.metadata->>'query'
    ) ae
    group by ae.vendor_id
  ) sq
  where vad.vendor_id = sq.vendor_id
    and vad.period_date = target_date;

  -- -------------------------------------------------------------------------
  -- 4d. Compute revenue from booking_events stage transitions on target_date
  --     revenue_confirmed_cents: bookings that transitioned to 'confirmed' or
  --       'paid' on target_date (using the simplified booking model)
  --     revenue_completed_cents: bookings that transitioned to 'completed'
  -- -------------------------------------------------------------------------
  update public.vendor_analytics_daily vad
  set revenue_confirmed_cents = coalesce(rev.confirmed_cents, 0),
      revenue_completed_cents = coalesce(rev.completed_cents, 0)
  from (
    select
      b.vendor_id,
      sum(
        case
          when be.to_stage in ('confirmed', 'paid')
          then coalesce(b.total_amount_cents, b.payment_requested_amount_cents, 0)
          else 0
        end
      ) as confirmed_cents,
      sum(
        case
          when be.to_stage = 'completed'
          then coalesce(b.total_amount_cents, b.payment_requested_amount_cents, 0)
          else 0
        end
      ) as completed_cents
    from public.booking_events be
    inner join public.bookings b on b.id = be.booking_id
    where be.created_at >= v_start
      and be.created_at < v_end
      and be.to_stage in ('confirmed', 'paid', 'completed')
    group by b.vendor_id
  ) rev
  where vad.vendor_id = rev.vendor_id
    and vad.period_date = target_date;

  -- -------------------------------------------------------------------------
  -- 4e. Populate category_benchmarks_daily
  -- -------------------------------------------------------------------------
  insert into public.category_benchmarks_daily (
    category,
    period_date,
    avg_response_minutes,
    avg_conversion_rate,
    avg_profile_view_count,
    median_rating,
    vendor_count
  )
  select
    vp.category,
    target_date,
    avg(vad.avg_response_minutes)::numeric(10,2),
    -- conversion_rate = bookings_confirmed / nullif(profile_views, 0)
    avg(
      case
        when vad.profile_views > 0
        then vad.bookings_confirmed::numeric / vad.profile_views
        else null
      end
    )::numeric(5,4),
    avg(vad.profile_views)::numeric(10,2),
    -- median_rating: percentile_cont across vendor average ratings
    -- Uses a subquery to compute per-vendor average rating from reviews if the table exists;
    -- for now, null until reviews table is populated.
    null,
    count(distinct vad.vendor_id)::integer
  from public.vendor_analytics_daily vad
  inner join public.vendor_profiles vp on vp.user_id = vad.vendor_id
  where vad.period_date = target_date
    and vp.category is not null
  group by vp.category
  on conflict (category, period_date) do update set
    avg_response_minutes  = excluded.avg_response_minutes,
    avg_conversion_rate   = excluded.avg_conversion_rate,
    avg_profile_view_count = excluded.avg_profile_view_count,
    median_rating         = excluded.median_rating,
    vendor_count          = excluded.vendor_count;
end;
$$;

alter function public.aggregate_vendor_analytics_daily(date) owner to postgres;

revoke all on function public.aggregate_vendor_analytics_daily(date) from public, anon, authenticated;
grant execute on function public.aggregate_vendor_analytics_daily(date) to service_role;
