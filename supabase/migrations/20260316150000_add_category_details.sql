-- Add category_details JSONB column to vendor_profiles
ALTER TABLE vendor_profiles
ADD COLUMN IF NOT EXISTS category_details jsonb DEFAULT '{}';

-- Add index for querying by category details type
CREATE INDEX IF NOT EXISTS idx_vendor_profiles_category_details_type
ON vendor_profiles ((category_details->>'type'))
WHERE category_details IS NOT NULL AND category_details != '{}'::jsonb;
