-- Fix: Add ILIKE prefix fallback for short queries (1-2 chars)
-- PostgreSQL plainto_tsquery drops single-letter tokens, causing empty results.
-- This adds a prefix ILIKE fallback on business_name and city for short inputs.

CREATE OR REPLACE FUNCTION public.search_vendors_server(
  p_query text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_event_date date DEFAULT NULL,
  p_price_min integer DEFAULT NULL,
  p_price_max integer DEFAULT NULL,
  p_limit integer DEFAULT 24,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(row_result ORDER BY rank DESC, profile_completeness DESC, business_name), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      row_to_json(vp.*)::jsonb AS row_result,
      vp.profile_completeness,
      vp.business_name,
      CASE
        WHEN p_query IS NOT NULL AND btrim(p_query) <> ''
          THEN ts_rank(vp.search_vector, plainto_tsquery('english', p_query))
        ELSE 0
      END AS rank
    FROM public.vendor_profiles vp
    LEFT JOIN public.vendor_availability va
      ON va.vendor_id = vp.user_id
      AND va.date = p_event_date
      AND va.status IN ('booked', 'blocked')
    WHERE
      -- Text search filter
      (
        p_query IS NULL
        OR btrim(p_query) = ''
        OR vp.search_vector @@ plainto_tsquery('english', p_query)
        OR (
          length(btrim(p_query)) BETWEEN 1 AND 2
          AND (
            vp.business_name ILIKE btrim(p_query) || '%'
            OR vp.city ILIKE btrim(p_query) || '%'
          )
        )
      )
      -- Category filter
      AND (
        p_category IS NULL
        OR vp.category = p_category
      )
      -- City filter (partial, case-insensitive)
      AND (
        p_city IS NULL
        OR vp.city ILIKE '%' || p_city || '%'
      )
      -- Availability filter: exclude vendors booked/blocked on the requested date
      AND (
        p_event_date IS NULL
        OR va.id IS NULL
      )
      -- Only include vendors that have completed onboarding
      AND vp.onboarded_at IS NOT NULL
    ORDER BY rank DESC, vp.profile_completeness DESC, vp.business_name
    LIMIT p_limit
    OFFSET p_offset
  ) AS sub;

  RETURN v_result;
END;
$$;

-- Re-grant permissions (CREATE OR REPLACE preserves grants, but be explicit)
REVOKE ALL ON FUNCTION public.search_vendors_server(text, text, text, date, integer, integer, integer, integer) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.search_vendors_server(text, text, text, date, integer, integer, integer, integer) TO service_role;
