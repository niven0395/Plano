import { createServiceClient, requireUser } from "../_shared/supabase.ts";
import {
  corsHeaders,
  ensureMethod,
  errorResponse,
  jsonResponse,
  optionsResponse,
  HTTPError,
} from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    ensureMethod(req, "POST");

    const { serviceClient, user } = await requireUser(req);

    // Create a deletion request
    const { data: request, error: insertError } = await serviceClient
      .from("data_deletion_requests")
      .insert({
        user_id: user.id,
        status: "pending",
      })
      .select()
      .single();

    if (insertError) {
      throw new HTTPError(500, "Failed to create deletion request.");
    }

    // Execute the deletion
    const { error: deleteError } = await serviceClient.rpc(
      "execute_data_deletion",
      {
        p_request_id: request.id,
      }
    );

    if (deleteError) {
      // Mark request as failed
      await serviceClient
        .from("data_deletion_requests")
        .update({ status: "failed", metadata: { error: deleteError.message } })
        .eq("id", request.id);

      throw new HTTPError(500, "Data deletion failed: " + deleteError.message);
    }

    // Delete storage objects for this user's message attachments
    const { data: files } = await serviceClient.storage
      .from("message-attachments")
      .list(user.id);

    if (files && files.length > 0) {
      const paths = files.map(
        (f: { name: string }) => `${user.id}/${f.name}`
      );
      await serviceClient.storage.from("message-attachments").remove(paths);
    }

    return jsonResponse({
      success: true,
      request_id: request.id,
      message:
        "Your data has been deleted. Message content has been redacted and personal data removed.",
    });
  } catch (err) {
    return errorResponse(err);
  }
});
