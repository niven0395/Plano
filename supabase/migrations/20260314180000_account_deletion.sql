-- =============================================================================
-- Account Deletion with Cascading Booking Cancellations
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Function: delete_account_with_cascades
-- Permanently deletes the caller's account from public.users, cascading
-- through all child tables (events, conversations, bookings, vendor_profiles,
-- host_profiles, saved_vendors, etc.).
--
-- Before deleting, it cancels all active bookings the user is involved in
-- (as host or vendor) and posts system messages so counterparties are notified.
-- ---------------------------------------------------------------------------
create or replace function public.delete_account_with_cascades()
returns jsonb
language plpgsql
security definer
as $$
declare
  v_user_id uuid := auth.uid();
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
  if v_user_id is null then
    raise exception 'Not authenticated.';
  end if;

  -- Verify the user exists
  if not exists (select 1 from public.users where id = v_user_id) then
    raise exception 'User not found.';
  end if;

  -- 1. Cancel all active conversations where the user is host or vendor
  for v_conv in
    select *
    from public.conversations
    where (host_id = v_user_id or vendor_id = v_user_id)
      and stage = any(v_active_stages)
    for update
  loop
    -- Update conversation stage to cancelled
    update public.conversations
    set stage = 'cancelled',
        last_activity_at = v_now
    where id = v_conv.id;

    -- Cancel all active bookings for this conversation
    for v_booking in
      select *
      from public.bookings
      where conversation_id = v_conv.id
        and stage = any(v_active_stages)
      for update
    loop
      update public.bookings
      set stage = 'cancelled',
          cancelled_by = v_user_id,
          cancelled_at = v_now,
          cancellation_reason = 'Account deleted by user',
          updated_at = v_now
      where id = v_booking.id;

      v_cancelled_count := v_cancelled_count + 1;
    end loop;

    -- Delete vendor availability tied to this conversation
    delete from public.vendor_availability
    where conversation_id = v_conv.id;

    -- Insert a system message so the counterparty sees what happened
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
      'This user has deleted their account. All associated bookings have been automatically cancelled.',
      'text',
      v_now
    );
  end loop;

  -- 2. Detach all conversations from events owned by this user
  --    so the FK on conversations.event_id does not block event deletion
  update public.conversations
  set event_id = null
  where event_id in (
    select id from public.events where host_id = v_user_id
  );

  -- 3. Nullify host_id / vendor_id on conversations to avoid FK violations
  --    (keeps the conversation shell so counterparties still see the history)
  update public.conversations
  set host_id = null
  where host_id = v_user_id;

  update public.conversations
  set vendor_id = null
  where vendor_id = v_user_id;

  -- 4. Delete the user row — cascades through all owned child tables
  delete from public.users
  where id = v_user_id;

  -- 5. Return result
  return jsonb_build_object(
    'cancelled_bookings', v_cancelled_count
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
revoke all on function public.delete_account_with_cascades() from public, anon;
grant execute on function public.delete_account_with_cascades() to authenticated;
