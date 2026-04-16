-- Allow vendors to skip the explicit accept step and jump straight from a
-- booking request to requesting payment. Some vendors require payment upfront
-- before they formally accept the job; others are happy to accept first.
--
-- Both validators are updated so the transition is legal via either pathway:
--   * validate_booking_transition_v2 is consulted by public.request_payment_server
--   * validate_booking_transition_v3 is consulted by the cancellation functions
--     (keeping them aligned avoids surprises if request-payment ever routes
--     through v3 in the future).

-- 1. v2: recognise vendor: requested -> payment_requested
create or replace function public.validate_booking_transition_v2(
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
    -- host transitions
    when lower(role) = 'host' and from_stage = 'requested' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'paid' then true
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage in ('paid', 'confirmed') and to_stage = 'cancelled' then true
    -- host -> cancellation_requested (policy-gated)
    when lower(role) = 'host' and from_stage = 'requested' and to_stage = 'cancellation_requested' then true
    when lower(role) = 'host' and from_stage = 'accepted' and to_stage = 'cancellation_requested' then true
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'cancellation_requested' then true
    when lower(role) = 'host' and from_stage in ('paid', 'confirmed') and to_stage = 'cancellation_requested' then true
    -- vendor transitions
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'accepted' then true
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'declined' then true
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'payment_requested' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'payment_requested' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'payment_requested' and to_stage = 'paid' then true
    when lower(role) = 'vendor' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage in ('paid', 'confirmed') and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'cancelled' then true
    -- vendor: revert cancellation_requested back to original stage
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'requested' then true
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'accepted' then true
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'payment_requested' then true
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage in ('paid', 'confirmed') then true
    -- system transitions
    when lower(role) = 'system' and from_stage in ('paid', 'confirmed') and to_stage = 'completed' then true
    else false
  end;
$$;

-- 2. v3: keep in sync so both paths agree
create or replace function public.validate_booking_transition_v3(
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

    -- host transitions (non-cancellation)
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'paid' then true

    -- host direct cancel (pre-payment: always allowed)
    when lower(role) = 'host' and from_stage = 'requested' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true
    -- host direct cancel (post-payment: allowed when no policy or outside deadline)
    when lower(role) = 'host' and from_stage in ('paid', 'confirmed') and to_stage = 'cancelled' then true

    -- host -> cancellation_requested (post-payment, policy-gated)
    when lower(role) = 'host' and from_stage in ('paid', 'confirmed') and to_stage = 'cancellation_requested' then true

    -- host responds to vendor's cancellation request
    when lower(role) = 'host' and from_stage = 'cancellation_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'host' and from_stage = 'cancellation_requested' and to_stage = 'paid' then true

    -- vendor transitions (non-cancellation)
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'accepted' then true
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'declined' then true
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'payment_requested' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'payment_requested' then true

    -- vendor direct cancel (pre-payment: always allowed)
    when lower(role) = 'vendor' and from_stage = 'requested' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'accepted' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'payment_requested' and to_stage = 'cancelled' then true

    -- vendor -> cancellation_requested (post-payment: always requires host approval)
    when lower(role) = 'vendor' and from_stage in ('paid', 'confirmed') and to_stage = 'cancellation_requested' then true

    -- vendor responds to host's cancellation request
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'cancelled' then true
    when lower(role) = 'vendor' and from_stage = 'cancellation_requested' and to_stage = 'paid' then true

    -- system transitions
    when lower(role) = 'system' and from_stage in ('paid', 'confirmed') and to_stage = 'completed' then true
    when lower(role) = 'system' and from_stage = 'cancellation_requested' and to_stage = 'cancelled' then true

    else false
  end;
$$;

revoke all on function public.validate_booking_transition_v2(text, text, text) from public, anon, authenticated;
grant execute on function public.validate_booking_transition_v2(text, text, text) to service_role;

revoke all on function public.validate_booking_transition_v3(text, text, text) from public, anon, authenticated;
grant execute on function public.validate_booking_transition_v3(text, text, text) to service_role;
