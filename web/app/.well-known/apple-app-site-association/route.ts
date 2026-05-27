import { NextResponse } from "next/server";
import { APP_BUNDLE_ID_FULL } from "@/lib/env";

// Apple fetches AASA from https://<domain>/.well-known/apple-app-site-association
// so iOS devices with the Plano app installed open booking links directly in
// the app (universal links) instead of the browser.
export async function GET() {
  const body = {
    applinks: {
      apps: [],
      details: [
        {
          appIDs: [APP_BUNDLE_ID_FULL],
          components: [
            { "/": "/book/*" },
            { "/": "/functions/v1/book/*" },
            { "/": "/claim*" },
            { "/": "/functions/v1/book/claim*" },
          ],
        },
      ],
    },
  };

  return NextResponse.json(body, {
    headers: {
      "Cache-Control": "public, max-age=300",
      "Content-Type": "application/json",
    },
  });
}
