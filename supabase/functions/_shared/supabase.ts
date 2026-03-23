import { createClient } from "jsr:@supabase/supabase-js@2";
import { HTTPError } from "./http.ts";

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new HTTPError(500, `Missing ${name} environment variable.`);
  }

  return value;
}

const supabaseURL = requireEnv("SUPABASE_URL");
const anonKey = requireEnv("SUPABASE_ANON_KEY");
const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");

export function createServiceClient() {
  return createClient(supabaseURL, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

export async function requireUser(request: Request) {
  console.log("[requireUser] Edge function reached — validating auth");

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    console.warn("[requireUser] No Authorization header present");
    throw new HTTPError(401, "Missing authorization header.");
  }

  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) {
    console.warn("[requireUser] Authorization header present but no bearer token");
    throw new HTTPError(401, "Missing bearer token.");
  }

  console.log(`[requireUser] Token present (length=${token.length}), verifying with Supabase auth`);

  const serviceClient = createServiceClient();
  const { data, error } = await serviceClient.auth.getUser(token);
  if (error || !data.user) {
    console.warn(`[requireUser] getUser failed: ${error?.message ?? "no user returned"}`);
    throw new HTTPError(401, "Authentication required.");
  }

  console.log(`[requireUser] Authenticated user ${data.user.id}`);
  return { serviceClient, user: data.user };
}
