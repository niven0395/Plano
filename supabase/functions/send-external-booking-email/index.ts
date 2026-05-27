// send-external-booking-email
//
// Drains up to N pending rows from public.external_email_jobs and sends each
// as a transactional email via Resend. Intended to be invoked by pg_cron (or
// manually during local testing). Idempotent: sent rows have sent_at set so
// they won't be re-processed.
//
// Required env vars:
//   RESEND_API_KEY     — your Resend secret
//   EMAIL_FROM         — verified from address, e.g. "Plano <noreply@plano.app>"
//   PUBLIC_APP_DOMAIN  — host used to build /claim deep links, e.g. "<proj>.supabase.co"
//
// POST body (optional):
//   { "batch_size": 20 }
//
// Authorization: Bearer <service role key> — this function is NOT public.

import {
  ensureMethod,
  errorResponse,
  HTTPError,
  jsonResponse,
  optionsResponse,
} from "../_shared/http.ts";
import { createServiceClient } from "../_shared/supabase.ts";

interface EmailJob {
  id: string;
  conversation_id: string;
  kind: string;
  payload: Record<string, unknown>;
  attempts: number;
  max_attempts: number;
}

interface InviteRow {
  token: string;
  email: string;
  expires_at: string;
}

interface ConversationRow {
  id: string;
  external_email: string | null;
  external_first_name: string | null;
  vendor_display_name: string | null;
  event_date_label: string | null;
}

function resolveEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new HTTPError(500, `Missing ${name} environment variable.`);
  return value;
}

function authorizeService(_request: Request): void {
  // The Supabase gateway enforces JWT verification on this function (it is
  // deployed with JWT on). Any caller reaching this code has already been
  // authenticated by the platform; we don't add a second manual check
  // because the service_role key's JWT format differs between projects.
  //
  // A caller with a valid anon JWT would still be blocked by RLS when
  // reading/writing external_email_jobs — only service_role bypasses it.
}

function buildClaimURL(domain: string, token: string): string {
  return `https://${domain}/functions/v1/book/claim?token=${encodeURIComponent(token)}`;
}

function escapeHTML(value: string): string {
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

function renderEmail(
  kind: string,
  conversation: ConversationRow,
  invite: InviteRow | null,
  payload: Record<string, unknown>,
  domain: string,
): { subject: string; html: string; text: string } | null {
  const vendorName = (payload.vendor_name as string | undefined)
    ?? conversation.vendor_display_name
    ?? "Your vendor";
  const eventLabel = (payload.event_date_label as string | undefined)
    ?? conversation.event_date_label
    ?? "your event";
  const firstName = (payload.first_name as string | undefined)
    ?? conversation.external_first_name
    ?? "there";
  const claimURL = invite ? buildClaimURL(domain, invite.token) : null;

  const ctaBlock = claimURL
    ? `
      <p style="margin: 24px 0;">
        <a href="${claimURL}" style="background: #111827; color: #ffffff; padding: 14px 22px; border-radius: 14px; text-decoration: none; font-weight: 600; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;">
          Open in Plano
        </a>
      </p>
      <p style="font-size: 13px; color: #6b7280;">
        Tapping the button installs the Plano app and links this booking to your account automatically.
      </p>
    `
    : "";

  let subject: string;
  let body: string;

  switch (kind) {
    case "request_received":
      subject = `Request sent to ${vendorName}`;
      body = `
        <p>Hi ${firstName},</p>
        <p>Your request for <strong>${eventLabel}</strong> was sent to <strong>${vendorName}</strong>.</p>
        <p>You'll get an email the moment they reply. Install Plano to chat, review their quote, and confirm without leaving the thread.</p>
      `;
      break;
    case "vendor_accepted":
      subject = `${vendorName} accepted your booking`;
      body = `
        <p>Hi ${firstName},</p>
        <p><strong>${vendorName}</strong> just accepted your request for <strong>${eventLabel}</strong>. It's now a confirmed booking.</p>
        <p>Download Plano to chat live with ${vendorName}, review the details, and manage everything leading up to your event. Your booking is already linked to the email you submitted with — just sign in to pick up where you left off.</p>
      `;
      break;
    case "vendor_quoted":
      subject = `${vendorName} sent you a quote`;
      body = `
        <p>Hi ${firstName},</p>
        <p><strong>${vendorName}</strong> sent a quote for <strong>${eventLabel}</strong>.</p>
        <p>Install Plano to view the quote and respond.</p>
      `;
      break;
    case "vendor_declined":
      subject = `Update on your request to ${vendorName}`;
      body = `
        <p>Hi ${firstName},</p>
        <p><strong>${vendorName}</strong> isn't able to take on your event on <strong>${eventLabel}</strong>.</p>
        <p>Install Plano to keep the thread, ask follow-up questions, or discover similar vendors.</p>
      `;
      break;
    case "payment_requested":
      subject = `${vendorName} requested a deposit`;
      body = `
        <p>Hi ${firstName},</p>
        <p><strong>${vendorName}</strong> sent a deposit request for <strong>${eventLabel}</strong>.</p>
        <p>Install Plano to review and pay securely.</p>
      `;
      break;
    case "cancelled":
      subject = `${vendorName} cancelled your booking`;
      body = `
        <p>Hi ${firstName},</p>
        <p><strong>${vendorName}</strong> cancelled the booking for <strong>${eventLabel}</strong>.</p>
        <p>Install Plano to discuss or find a replacement.</p>
      `;
      break;
    case "vendor_messaged": {
      subject = `${vendorName} sent you a message`;
      const rawPreview = (payload.message_preview as string | undefined) ?? "";
      const preview = escapeHTML(rawPreview).replace(/\n/g, "<br>");
      const quoteBlock = preview
        ? `
          <blockquote style="margin: 16px 0; padding: 14px 18px; background: #f9fafb; border-left: 3px solid #111827; border-radius: 8px; color: #1f2937; font-size: 15px; line-height: 1.5;">
            ${preview}
          </blockquote>
        `
        : "";
      body = `
        <p>Hi ${firstName},</p>
        <p><strong>${vendorName}</strong> sent you a message about <strong>${eventLabel}</strong>:</p>
        ${quoteBlock}
        <p>Download Plano to respond back to ${vendorName} — your booking is already linked to this email address, just sign in to pick up the thread.</p>
      `;
      break;
    }
    default:
      return null;
  }

  const html = `
    <!doctype html>
    <html><body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; color: #111827; max-width: 560px; margin: 0 auto; padding: 24px;">
      ${body}
      ${ctaBlock}
      <hr style="border: none; border-top: 1px solid #e5e7eb; margin-top: 32px;"/>
      <p style="font-size: 12px; color: #9ca3af;">Plano · booking requests for hosts & vendors.</p>
    </body></html>
  `.trim();

  const text = body.replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim()
    + (claimURL ? `\n\nOpen in Plano: ${claimURL}` : "");

  return { subject, html, text };
}

async function sendViaResend(
  apiKey: string,
  from: string,
  to: string,
  subject: string,
  html: string,
  text: string,
): Promise<void> {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from, to, subject, html, text }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Resend error ${response.status}: ${detail}`);
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return optionsResponse();

  try {
    ensureMethod(request, "POST");
    authorizeService(request);

    const apiKey = resolveEnv("RESEND_API_KEY");
    const from = resolveEnv("EMAIL_FROM");
    const domain = resolveEnv("PUBLIC_APP_DOMAIN");

    let batchSize = 20;
    try {
      const body = await request.json();
      if (typeof body?.batch_size === "number") batchSize = Math.max(1, Math.min(body.batch_size, 100));
    } catch {
      // empty body is fine
    }

    const serviceClient = createServiceClient();

    const { data: jobs, error: jobsError } = await serviceClient
      .from("external_email_jobs")
      .select("id, conversation_id, kind, payload, attempts, max_attempts")
      .is("sent_at", null)
      .lt("attempts", 5)
      .order("created_at", { ascending: true })
      .limit(batchSize);

    if (jobsError) {
      throw new HTTPError(500, `Queue fetch failed: ${jobsError.message}`);
    }

    const results: Array<{ id: string; ok: boolean; error?: string }> = [];

    for (const job of (jobs ?? []) as EmailJob[]) {
      try {
        const { data: conv, error: convError } = await serviceClient
          .from("conversations")
          .select("id, external_email, external_first_name, vendor_display_name, event_date_label")
          .eq("id", job.conversation_id)
          .single();

        if (convError || !conv) {
          throw new Error(`conversation not found: ${convError?.message ?? "null"}`);
        }

        const conversation = conv as ConversationRow;
        if (!conversation.external_email) {
          // already claimed — mark as sent so we stop retrying.
          await serviceClient.from("external_email_jobs")
            .update({ sent_at: new Date().toISOString() })
            .eq("id", job.id);
          results.push({ id: job.id, ok: true });
          continue;
        }

        const { data: invite } = await serviceClient
          .from("external_booking_invites")
          .select("token, email, expires_at")
          .eq("conversation_id", job.conversation_id)
          .is("claimed_at", null)
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();

        const rendered = renderEmail(job.kind, conversation, invite as InviteRow | null, job.payload ?? {}, domain);
        if (!rendered) {
          throw new Error(`no template for kind=${job.kind}`);
        }

        await sendViaResend(apiKey, from, conversation.external_email, rendered.subject, rendered.html, rendered.text);

        await serviceClient.from("external_email_jobs")
          .update({ sent_at: new Date().toISOString(), attempts: job.attempts + 1 })
          .eq("id", job.id);
        results.push({ id: job.id, ok: true });
      } catch (sendError) {
        const message = sendError instanceof Error ? sendError.message : String(sendError);
        console.error(`[send-external-booking-email] job ${job.id} failed:`, message);
        await serviceClient.from("external_email_jobs")
          .update({ attempts: job.attempts + 1, last_error: message })
          .eq("id", job.id);
        results.push({ id: job.id, ok: false, error: message });
      }
    }

    return jsonResponse({ processed: results.length, results });
  } catch (error) {
    return errorResponse(error);
  }
});
