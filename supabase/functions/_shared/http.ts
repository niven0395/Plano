export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export class HTTPError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export function optionsResponse(): Response {
  return new Response("ok", { headers: corsHeaders });
}

export function ensureMethod(request: Request, method: string): void {
  if (request.method !== method) {
    throw new HTTPError(405, `Method ${request.method} not allowed.`);
  }
}

export async function parseJSON<T>(request: Request): Promise<T> {
  try {
    return await request.json() as T;
  } catch {
    throw new HTTPError(400, "Invalid JSON body.");
  }
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function errorResponse(error: unknown): Response {
  if (error instanceof HTTPError) {
    return jsonResponse({ error: error.message }, error.status);
  }

  console.error(error);
  return jsonResponse({ error: "Unexpected server error." }, 500);
}
