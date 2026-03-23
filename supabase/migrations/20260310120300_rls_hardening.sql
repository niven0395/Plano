drop policy if exists "Hosts can create booking requests" on public.booking_requests;
drop policy if exists "Direct booking request inserts disabled" on public.booking_requests;
create policy "Direct booking request inserts disabled"
on public.booking_requests
for insert
with check (false);

drop policy if exists "Vendors can create booking quotes" on public.booking_quotes;
drop policy if exists "Participants can update booking quotes" on public.booking_quotes;
drop policy if exists "Direct booking quote inserts disabled" on public.booking_quotes;
create policy "Direct booking quote inserts disabled"
on public.booking_quotes
for insert
with check (false);

drop policy if exists "Direct booking quote updates disabled" on public.booking_quotes;
create policy "Direct booking quote updates disabled"
on public.booking_quotes
for update
using (false)
with check (false);

drop policy if exists "Participants can create bookings" on public.bookings;
drop policy if exists "Participants can update bookings" on public.bookings;
drop policy if exists "Direct booking inserts disabled" on public.bookings;
create policy "Direct booking inserts disabled"
on public.bookings
for insert
with check (false);

drop policy if exists "Direct booking updates disabled" on public.bookings;
create policy "Direct booking updates disabled"
on public.bookings
for update
using (false)
with check (false);

drop policy if exists "Participants can update conversations" on public.conversations;
create policy "Participants can update conversations except stage" on public.conversations
for update
using (host_id = auth.uid() or vendor_id = auth.uid())
with check (
  (host_id = auth.uid() or vendor_id = auth.uid())
  and stage = (
    select current_conversation.stage
    from public.conversations as current_conversation
    where current_conversation.id = conversations.id
  )
);
