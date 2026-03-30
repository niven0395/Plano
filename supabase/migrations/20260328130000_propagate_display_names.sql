-- Propagate display name changes to existing conversations.
-- When a vendor updates their business_name or a host updates their display_name,
-- all conversations involving that participant are updated to reflect the new name.

--------------------------------------------------------------------------------
-- 1. Vendor business name → conversations.vendor_display_name
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.propagate_vendor_display_name()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.business_name IS DISTINCT FROM OLD.business_name THEN
    UPDATE conversations
    SET vendor_display_name = NEW.business_name,
        updated_at = timezone('utc', now())
    WHERE vendor_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_propagate_vendor_display_name
  AFTER UPDATE OF business_name ON vendor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION propagate_vendor_display_name();

--------------------------------------------------------------------------------
-- 2. Host display name → conversations.host_display_name
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.propagate_host_display_name()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.display_name IS DISTINCT FROM OLD.display_name THEN
    UPDATE conversations
    SET host_display_name = NEW.display_name,
        updated_at = timezone('utc', now())
    WHERE host_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_propagate_host_display_name
  AFTER UPDATE OF display_name ON users
  FOR EACH ROW
  EXECUTE FUNCTION propagate_host_display_name();
