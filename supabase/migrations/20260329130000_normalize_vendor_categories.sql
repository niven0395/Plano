-- Normalize legacy vendor category values to their current rawValue equivalents.
-- The Swift enum VendorCategory uses camelCase raw values ("eventSpace", "desserts",
-- "entertainer"), but older code paths may have written legacy aliases.

-- vendor_profiles.category
UPDATE public.vendor_profiles SET category = 'eventSpace'  WHERE category = 'venue';
UPDATE public.vendor_profiles SET category = 'desserts'    WHERE category = 'candyBuffet';
UPDATE public.vendor_profiles SET category = 'entertainer' WHERE category IN ('stationer', 'other');

-- conversations.vendor_category
UPDATE public.conversations SET vendor_category = 'eventSpace'  WHERE vendor_category = 'venue';
UPDATE public.conversations SET vendor_category = 'desserts'    WHERE vendor_category = 'candyBuffet';
UPDATE public.conversations SET vendor_category = 'entertainer' WHERE vendor_category IN ('stationer', 'other');

-- bookings.vendor_category
UPDATE public.bookings SET vendor_category = 'eventSpace'  WHERE vendor_category = 'venue';
UPDATE public.bookings SET vendor_category = 'desserts'    WHERE vendor_category = 'candyBuffet';
UPDATE public.bookings SET vendor_category = 'entertainer' WHERE vendor_category IN ('stationer', 'other');

-- planned_vendors.category
UPDATE public.planned_vendors SET category = 'eventSpace'  WHERE category = 'venue';
UPDATE public.planned_vendors SET category = 'desserts'    WHERE category = 'candyBuffet';
UPDATE public.planned_vendors SET category = 'entertainer' WHERE category IN ('stationer', 'other');

-- category_benchmarks_daily.category
UPDATE public.category_benchmarks_daily SET category = 'eventSpace'  WHERE category = 'venue';
UPDATE public.category_benchmarks_daily SET category = 'desserts'    WHERE category = 'candyBuffet';
UPDATE public.category_benchmarks_daily SET category = 'entertainer' WHERE category IN ('stationer', 'other');
