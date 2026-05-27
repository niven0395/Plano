// book
//
// Public, unauthenticated. Serves the legacy web booking form at
// /book/<vendor_id> and handles the POST submission. Also serves
// /book/success (post-submit thank-you page) and /book/claim (deep-link
// landing page for external hosts who tap the email link on a device
// without the app).
//
// The canonical booking UI now lives in the Next.js app behind the
// Cloudflare Worker; this edge function is retained as a fallback for
// direct hits to the Supabase host.

import { corsHeaders } from "../_shared/http.ts";
import { createServiceClient } from "../_shared/supabase.ts";

const HTML_HEADERS = {
  ...corsHeaders,
  "Content-Type": "text/html; charset=utf-8",
  "Cache-Control": "no-store",
};

function html(body: string, status = 200): Response {
  return new Response(body, { status, headers: HTML_HEADERS });
}

function escape(value: string): string {
  return value.replace(/[&<>"']/g, (ch) => {
    switch (ch) {
      case "&": return "&amp;";
      case "<": return "&lt;";
      case ">": return "&gt;";
      case '"': return "&quot;";
      default: return "&#39;";
    }
  });
}

const BASE_STYLE = `
  *, *::before, *::after { box-sizing: border-box; }
  body { margin: 0; background: #fafafa; color: #111827; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
  .shell { max-width: 560px; margin: 0 auto; padding: 32px 20px 80px; }
  .header { text-align: center; margin-bottom: 24px; }
  .header h1 { font-size: 28px; font-weight: 700; margin: 0; letter-spacing: -0.01em; }
  .header .sub { color: #6b7280; margin-top: 6px; font-size: 15px; }
  .card { background: #ffffff; border: 1px solid #e5e7eb; border-radius: 20px; padding: 24px; box-shadow: 0 1px 2px rgba(0,0,0,0.04); }
  .field { display: flex; flex-direction: column; gap: 6px; margin-bottom: 18px; }
  .field label { font-size: 13px; font-weight: 600; color: #374151; }
  .field input, .field textarea, .field select { width: 100%; padding: 12px 14px; font-size: 16px; border: 1px solid #d1d5db; border-radius: 12px; background: #ffffff; color: #111827; font-family: inherit; }
  .field textarea { min-height: 96px; resize: vertical; }
  .field .hint { font-size: 12px; color: #6b7280; }
  .row { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
  button.primary { width: 100%; padding: 16px; font-size: 16px; font-weight: 600; background: #111827; color: #ffffff; border: none; border-radius: 14px; cursor: pointer; }
  button.primary:disabled { opacity: 0.6; cursor: default; }
  .error { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; padding: 12px 14px; border-radius: 12px; font-size: 14px; margin-bottom: 16px; }
  .success { text-align: center; padding: 48px 20px; }
  .success h1 { font-size: 30px; margin: 0 0 12px; letter-spacing: -0.01em; }
  .success p { color: #4b5563; max-width: 420px; margin: 0 auto 20px; line-height: 1.5; }
  .install { display: inline-block; background: #111827; color: #ffffff; padding: 14px 22px; border-radius: 14px; font-weight: 600; text-decoration: none; }
  .smart-banner { background: #f3f4f6; border-radius: 16px; padding: 14px 16px; display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 20px; }
  .smart-banner .copy { font-size: 14px; color: #374151; }
  .smart-banner a { color: #111827; font-weight: 600; text-decoration: none; font-size: 14px; }
`.trim();

async function renderForm(vendorID: string, errorMessage?: string): Promise<Response> {
  const serviceClient = createServiceClient();
  const { data: vendor } = await serviceClient
    .from("vendor_profiles")
    .select("user_id, business_name, category, listing_image_path, lead_intake_questions")
    .eq("user_id", vendorID)
    .single();

  if (!vendor) {
    return html(`<!doctype html><html><head><meta charset="utf-8"><title>Vendor not found</title><style>${BASE_STYLE}</style></head><body><div class="shell"><div class="success"><h1>Vendor not found</h1><p>This link looks invalid. Please ask the vendor to resend it.</p></div></div></body></html>`, 404);
  }

  const vendorName = vendor.business_name ?? "Vendor";
  const questions = Array.isArray(vendor.lead_intake_questions) ? vendor.lead_intake_questions : [];
  // listing_image_path is a storage object path; build a public URL via the
  // storage endpoint. Most buckets are public for listing images.
  const heroURL = vendor.listing_image_path
    ? `${Deno.env.get("SUPABASE_URL")}/storage/v1/object/public/vendor-media/${vendor.listing_image_path}`
    : null;
  const heroHTML = heroURL
    ? `<img src="${escape(heroURL)}" alt="" style="width: 100%; height: 180px; object-fit: cover; border-radius: 20px; margin-bottom: 20px;" />`
    : "";

  const intakeHTML = questions
    .filter((q: { isEnabled?: boolean }) => q?.isEnabled !== false)
    .map((q: { id: string; prompt: string; helperText?: string; placeholder?: string; responseType?: string; options?: string[]; isRequired?: boolean }, idx: number) => {
      const name = `intake:${escape(q.id ?? `q${idx}`)}`;
      const promptText = escape(q.prompt ?? "");
      const helper = q.helperText ? `<div class="hint">${escape(q.helperText)}</div>` : "";
      const placeholder = q.placeholder ? `placeholder="${escape(q.placeholder)}"` : "";
      const req = q.isRequired ? "required" : "";
      let control = "";
      switch (q.responseType) {
        case "long_text":
          control = `<textarea name="${name}" ${placeholder} ${req}></textarea>`;
          break;
        case "number":
          control = `<input type="number" inputmode="numeric" name="${name}" ${placeholder} ${req} />`;
          break;
        case "single_choice":
        case "multi_choice": {
          const multiple = q.responseType === "multi_choice" ? "multiple" : "";
          const opts = (q.options ?? []).map((opt: string) => `<option value="${escape(opt)}">${escape(opt)}</option>`).join("");
          control = `<select name="${name}" ${multiple} ${req}>${q.responseType === "single_choice" ? `<option value="">Select…</option>` : ""}${opts}</select>`;
          break;
        }
        default:
          control = `<input type="text" name="${name}" ${placeholder} ${req} />`;
      }
      return `<div class="field"><label>${promptText}${q.isRequired ? " *" : ""}</label>${control}${helper}</div>`;
    })
    .join("");

  const errorBanner = errorMessage ? `<div class="error">${escape(errorMessage)}</div>` : "";

  const body = `
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      <title>Book ${escape(vendorName)}</title>
      <meta name="description" content="Send a booking request to ${escape(vendorName)} — no account needed." />
      <meta property="og:type" content="website" />
      <meta property="og:title" content="Book ${escape(vendorName)}" />
      <meta property="og:description" content="Send a booking request — no account needed." />
      ${heroURL ? `<meta property="og:image" content="${escape(heroURL)}" />` : ""}
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:title" content="Book ${escape(vendorName)}" />
      <meta name="twitter:description" content="Send a booking request — no account needed." />
      ${heroURL ? `<meta name="twitter:image" content="${escape(heroURL)}" />` : ""}
      <style>${BASE_STYLE}</style>
    </head>
    <body>
      <div class="shell">
        <div class="smart-banner">
          <div class="copy">Open in the Plano app for the best experience.</div>
          <a href="https://apps.apple.com/app/plano/id0000000000">Get app</a>
        </div>
        ${heroHTML}
        <div class="header">
          <h1>${escape(vendorName)}</h1>
          <div class="sub">Send a booking request — no account needed.</div>
        </div>
        <div class="card">
          ${errorBanner}
          <form method="POST" action="/functions/v1/book/${escape(vendorID)}">
            <div class="row">
              <div class="field">
                <label for="first_name">First name *</label>
                <input id="first_name" type="text" name="first_name" autocomplete="given-name" required />
              </div>
              <div class="field">
                <label for="last_name">Last name *</label>
                <input id="last_name" type="text" name="last_name" autocomplete="family-name" required />
              </div>
            </div>
            <div class="field">
              <label for="email">Email *</label>
              <input id="email" type="email" name="email" autocomplete="email" required />
              <div class="hint">${escape(vendorName)}'s replies will be emailed to you until you install the app.</div>
            </div>
            <div class="row">
              <div class="field">
                <label for="event_date">Event date *</label>
                <input id="event_date" type="date" name="event_date" required />
              </div>
              <div class="field">
                <label for="guest_count">Guest count</label>
                <input id="guest_count" type="number" inputmode="numeric" name="guest_count" min="1" />
              </div>
            </div>
            ${intakeHTML}
            <div class="field">
              <label for="note">Anything else to share?</label>
              <textarea id="note" name="note" placeholder="Tell the vendor what you're planning"></textarea>
            </div>
            <button class="primary" type="submit">Send request</button>
          </form>
        </div>
      </div>
    </body>
    </html>
  `.trim();

  return html(body);
}

async function renderSuccess(vendorID: string): Promise<Response> {
  const serviceClient = createServiceClient();
  const { data: vendor } = await serviceClient
    .from("vendor_profiles")
    .select("business_name")
    .eq("user_id", vendorID)
    .single();

  const vendorName = vendor?.business_name ?? "the vendor";

  return html(`
    <!doctype html>
    <html><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /><title>Request sent</title><style>${BASE_STYLE}</style></head>
    <body><div class="shell"><div class="success">
      <h1>Request sent</h1>
      <p>${escape(vendorName)} will reply by email. Install Plano to chat directly, review their quote, and confirm your booking without leaving the thread.</p>
      <a class="install" href="https://apps.apple.com/app/plano/id0000000000">Install Plano</a>
    </div></div></body></html>
  `.trim());
}

async function renderClaim(token: string): Promise<Response> {
  return html(`
    <!doctype html>
    <html><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /><title>Open in Plano</title><style>${BASE_STYLE}</style></head>
    <body><div class="shell"><div class="success">
      <h1>Open in Plano</h1>
      <p>If you have Plano installed this page should have opened in the app automatically. Otherwise, install Plano and sign in with the email address this link was sent to — your booking will appear there.</p>
      <a class="install" href="https://apps.apple.com/app/plano/id0000000000?referrer=${encodeURIComponent(token)}">Install Plano</a>
    </div></div></body></html>
  `.trim());
}

async function processSubmission(request: Request, vendorID: string): Promise<Response> {
  const form = await request.formData();

  const payload = {
    vendor_id: vendorID,
    first_name: String(form.get("first_name") ?? "").trim(),
    last_name: String(form.get("last_name") ?? "").trim(),
    email: String(form.get("email") ?? "").trim(),
    event_date: String(form.get("event_date") ?? "").trim(),
    guest_count: form.get("guest_count") ? Number(form.get("guest_count")) : null,
    note: String(form.get("note") ?? "").trim(),
    source: "web",
    intake_answers: [] as Array<{ questionID: string; prompt: string; responseType: string; values: string[] }>,
  };

  for (const [key, value] of form.entries()) {
    if (!key.startsWith("intake:")) continue;
    const questionID = key.slice("intake:".length);
    const values = Array.isArray(value) ? value.map(String) : [String(value)];
    payload.intake_answers.push({
      questionID,
      prompt: questionID,
      responseType: "short_text",
      values,
    });
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  const resp = await fetch(`${supabaseURL}/functions/v1/submit-external-booking`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": anonKey,
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) {
    const errorBody = await resp.json().catch(() => ({ error: "Unknown error" }));
    return renderForm(vendorID, errorBody.error ?? "Something went wrong. Please try again.");
  }

  return new Response(null, {
    status: 303,
    headers: {
      ...HTML_HEADERS,
      Location: `/functions/v1/book/success?vendor=${encodeURIComponent(vendorID)}`,
    },
  });
}

Deno.serve(async (request) => {
  const url = new URL(request.url);
  // The Supabase edge router rewrites paths so the handler sees either
  // "/functions/v1/book/<tail>" (raw) or "/book/<tail>" (after prefix peel).
  // Strip whichever form so `parts[0]` is the vendor id / sub-route.
  const pathname = url.pathname
    .replace(/^\/functions\/v1\/book/, "")
    .replace(/^\/book/, "")
    || "/";
  const parts = pathname.split("/").filter(Boolean);

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // /book/claim?token=...
  if (parts[0] === "claim") {
    const token = url.searchParams.get("token") ?? "";
    return renderClaim(token);
  }

  // /book/success?vendor=...
  if (parts[0] === "success") {
    const vendorID = url.searchParams.get("vendor") ?? "";
    return renderSuccess(vendorID);
  }

  // /book/<vendor_id>
  const vendorID = parts[0];
  if (!vendorID) {
    return html(`<!doctype html><html><body><p>Missing vendor ID.</p></body></html>`, 400);
  }

  if (request.method === "POST") {
    return processSubmission(request, vendorID);
  }

  return renderForm(vendorID);
});
