-- =============================================================================
-- Fix: restore vendor payment_requested → paid transition
--
-- This rule was added in 20260316180000_vendor_confirm_payment.sql but lost
-- when 20260321120000_fix_confirmed_cancellation_compat.sql redefined
-- validate_booking_transition_v2 for cancellation policy support.
-- =============================================================================

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
