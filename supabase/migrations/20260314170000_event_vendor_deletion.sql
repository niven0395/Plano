-- =============================================================================
-- Event & Vendor Listing Deletion with Cascading Booking Cancellations
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Function 1: delete_event_with_cancellations
-- Deletes an event owned by the caller, cancelling all active bookings first.
-- ---------------------------------------------------------------------------
create or replace function public.delete_event_with_cancellations(p_event_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_host_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_conv record;
  v_booking record;
  v_now timestamptz := timezone('utc', now());
  v_cancelled_count integer := 0;
  v_active_stages text[] := array[
    'requested',
    'vendor_reviewing',
    'quoted',
    'host_reviewing',
    'accepted',
    'deposit_pending',
    'confirmed'
  ];
begin
  -- 1. Verify the event exists and belongs to the caller
  select *
  into v_event
  from public.events
  where id = p_event_id
    and host_id = v_host_id
  for update;

  if not found then
    raise exception 'Event not found or you do not have permission to delete it.';
  end if;

  -- 2. Loop through active conversations for this event and cancel them
  for v_conv in
    select *
    from public.conversations
    where event_id = p_event_id
      and stage = any(v_active_stages)
    for update
  loop
    -- Update conversation stage to cancelled
    update public.conversations
    set stage = 'cancelled',
        last_activity_at = v_now
    where id = v_conv.id;

    -- Update all active bookings for this conversation to cancelled
    for v_booking in
      select *
      from public.bookings
      where conversation_id = v_conv.id
        and stage = any(v_active_stages)
      for update
    loop
      update public.bookings
      set stage = 'cancelled',
          cancelled_by = v_host_id,
          cancelled_at = v_now,
          cancellation_reason = 'Event deleted by host',
          updated_at = v_now
      where id = v_booking.id;

      v_cancelled_count := v_cancelled_count + 1;
    end loop;

    -- Delete vendor availability tied to this vendor + conversation
    delete from public.vendor_availability
    where vendor_id = v_conv.vendor_id
      and conversation_id = v_conv.id;

    -- Also clean up legacy availability rows matched by note
    delete from public.vendor_availability
    where vendor_id = v_conv.vendor_id
      and conversation_id is null
      and note = format('booking:%s', v_conv.id);

    -- Insert a system message into the conversation
    insert into public.messages (
      conversation_id,
      sender_role,
      body,
      kind,
      created_at
    )
    values (
      v_conv.id,
      'system',
      'This event has been cancelled by the host. All associated bookings have been automatically cancelled.',
      'text',
      v_now
    );
  end loop;

  -- 3. Detach ALL conversations from this event (not just active ones)
  --    so the FK on conversations.event_id does not block event deletion
  update public.conversations
  set event_id = null
  where event_id = p_event_id;

  -- 4. Delete planned vendors for this event
  delete from public.planned_vendors
  where event_id = p_event_id;

  -- 5. Delete the event
  delete from public.events
  where id = p_event_id;

  -- 6. Return result
  return jsonb_build_object(
    'event_id', p_event_id,
    'cancelled_bookings', v_cancelled_count
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Function 2: delete_vendor_listing_with_cancellations
-- Removes the vendor listing for the caller, cancelling all active bookings.
-- ---------------------------------------------------------------------------
create or replace function public.delete_vendor_listing_with_cancellations()
returns jsonb
language plpgsql
security definer
as $$
declare
  v_vendor_id uuid := auth.uid();
  v_vendor_profile public.vendor_profiles%rowtype;
  v_conv record;
  v_booking record;
  v_now timestamptz := timezone('utc', now());
  v_cancelled_count integer := 0;
  v_active_stages text[] := array[
    'requested',
    'vendor_reviewing',
    'quoted',
    'host_reviewing',
    'accepted',
    'deposit_pending',
    'confirmed'
  ];
begin
  -- 1. Verify vendor profile exists for the caller
  select *
  into v_vendor_profile
  from public.vendor_profiles
  where user_id = v_vendor_id
  for update;

  if not found then
    raise exception 'Vendor profile not found for the current user.';
  end if;

  -- 2. Loop through active conversations for this vendor and cancel them
  for v_conv in
    select *
    from public.conversations
    where vendor_id = v_vendor_id
      and stage = any(v_active_stages)
    for update
  loop
    -- Update conversation stage to cancelled
    update public.conversations
    set stage = 'cancelled',
        last_activity_at = v_now
    where id = v_conv.id;

    -- Update all active bookings for this conversation to cancelled
    for v_booking in
      select *
      from public.bookings
      where conversation_id = v_conv.id
        and stage = any(v_active_stages)
      for update
    loop
      update public.bookings
      set stage = 'cancelled',
          cancelled_by = v_vendor_id,
          cancelled_at = v_now,
          cancellation_reason = 'Vendor listing removed',
          updated_at = v_now
      where id = v_booking.id;

      v_cancelled_count := v_cancelled_count + 1;
    end loop;

    -- Insert a system message into the conversation
    insert into public.messages (
      conversation_id,
      sender_role,
      body,
      kind,
      created_at
    )
    values (
      v_conv.id,
      'system',
      'This vendor has removed their listing from Plano. All associated bookings have been automatically cancelled.',
      'text',
      v_now
    );
  end loop;

  -- 3. Delete ALL vendor availability (not just from active conversations)
  delete from public.vendor_availability
  where vendor_id = v_vendor_id;

  -- 4. Delete vendor gallery images
  delete from public.vendor_gallery_images
  where vendor_id = v_vendor_id;

  -- 5. Delete vendor service items
  delete from public.vendor_service_items
  where vendor_id = v_vendor_id;

  -- 6. Delete the vendor profile
  delete from public.vendor_profiles
  where user_id = v_vendor_id;

  -- 7. Reset preferred_role to 'host' on the users table
  --    (column exists per phase1 migration)
  update public.users
  set preferred_role = 'host'
  where id = v_vendor_id;

  -- 8. Return result
  return jsonb_build_object(
    'vendor_id', v_vendor_id,
    'cancelled_bookings', v_cancelled_count
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Permissions: allow authenticated users to call these functions via RPC
-- ---------------------------------------------------------------------------
revoke all on function public.delete_event_with_cancellations(uuid) from public, anon;
grant execute on function public.delete_event_with_cancellations(uuid) to authenticated;

revoke all on function public.delete_vendor_listing_with_cancellations() from public, anon;
grant execute on function public.delete_vendor_listing_with_cancellations() to authenticated;
