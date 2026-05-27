import { supabase } from "./supabase";

export type IntakeResponseType =
  | "short_text"
  | "long_text"
  | "single_choice"
  | "multi_choice"
  | "number";

export interface IntakeQuestion {
  id: string;
  prompt: string;
  helperText: string;
  placeholder: string;
  responseType: IntakeResponseType;
  options: string[];
  isRequired: boolean;
  isEnabled: boolean;
}

export interface VendorSummary {
  id: string;
  businessName: string;
  category: string;
  coverImageURL: string | null;
  intakeQuestions: IntakeQuestion[];
  collectsGuestCount: boolean;
}

interface RawVendorRow {
  user_id: string;
  business_name: string | null;
  category: string | null;
  listing_image_path: string | null;
  lead_intake_questions: unknown;
  collects_guest_count: boolean | null;
}

const LISTING_BUCKET = "vendor-galleries";
const LISTING_URL_TTL_SECONDS = 60 * 60;

function normalizeQuestion(raw: unknown): IntakeQuestion | null {
  if (!raw || typeof raw !== "object") return null;
  const q = raw as Record<string, unknown>;
  const id = typeof q.id === "string" ? q.id : null;
  const prompt = typeof q.prompt === "string" ? q.prompt : null;
  if (!id || !prompt) return null;
  const rt = typeof q.responseType === "string" ? q.responseType : "short_text";
  const responseType: IntakeResponseType =
    rt === "long_text" ||
    rt === "single_choice" ||
    rt === "multi_choice" ||
    rt === "number"
      ? rt
      : "short_text";
  return {
    id,
    prompt,
    helperText: typeof q.helperText === "string" ? q.helperText : "",
    placeholder: typeof q.placeholder === "string" ? q.placeholder : "",
    responseType,
    options: Array.isArray(q.options) ? q.options.filter((o): o is string => typeof o === "string") : [],
    isRequired: q.isRequired === true,
    isEnabled: q.isEnabled !== false,
  };
}

async function resolveCoverImageURL(path: string | null): Promise<string | null> {
  if (!path) return null;
  const { data, error } = await supabase()
    .storage.from(LISTING_BUCKET)
    .createSignedUrl(path, LISTING_URL_TTL_SECONDS);
  if (error || !data?.signedUrl) return null;
  return data.signedUrl;
}

export async function fetchVendorSummary(vendorId: string): Promise<VendorSummary | null> {
  const { data, error } = await supabase()
    .from("vendor_profiles")
    .select("user_id, business_name, category, listing_image_path, lead_intake_questions, collects_guest_count")
    .eq("user_id", vendorId)
    .maybeSingle<RawVendorRow>();

  if (error || !data) return null;

  const rawQuestions = Array.isArray(data.lead_intake_questions) ? data.lead_intake_questions : [];
  const intakeQuestions = rawQuestions
    .map(normalizeQuestion)
    .filter((q): q is IntakeQuestion => q !== null && q.isEnabled);

  const coverImageURL = await resolveCoverImageURL(data.listing_image_path);

  return {
    id: data.user_id,
    businessName: data.business_name?.trim() || "Vendor",
    category: data.category?.trim() || "",
    coverImageURL,
    intakeQuestions,
    collectsGuestCount: data.collects_guest_count ?? true,
  };
}
