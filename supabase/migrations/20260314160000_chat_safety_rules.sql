-- Chat safety rules: self-messaging prevention and co-vendor visibility
-- Migration: 20260314160000_chat_safety_rules

--------------------------------------------------------------------------------
-- 1. Prevent self-messaging
--    A conversation must always involve two distinct parties. Block any row
--    where the host and vendor refer to the same user.
--------------------------------------------------------------------------------

ALTER TABLE conversations
ADD CONSTRAINT conversations_no_self_messaging CHECK (host_id <> vendor_id);

--------------------------------------------------------------------------------
-- 2. Co-vendor visibility for a given event
--    Returns confirmed co-vendors so a vendor can see who else is booked for
--    the same event. The requesting vendor must themselves be confirmed on the
--    event; otherwise the function raises an exception.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION event_confirmed_vendors(p_event_id uuid, p_requesting_vendor_id uuid)
RETURNS TABLE (
    vendor_id uuid,
    vendor_display_name text,
    vendor_category text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validate the requesting vendor is themselves confirmed on this event
    IF NOT EXISTS (
        SELECT 1 FROM conversations
        WHERE event_id = p_event_id
          AND vendor_id = p_requesting_vendor_id
          AND stage = 'confirmed'
    ) THEN
        RAISE EXCEPTION 'Requesting vendor is not confirmed on this event';
    END IF;

    RETURN QUERY
    SELECT c.vendor_id,
           c.vendor_display_name,
           c.vendor_category
    FROM conversations c
    WHERE c.event_id = p_event_id
      AND c.stage = 'confirmed'
      AND c.vendor_id <> p_requesting_vendor_id;
END;
$$;
