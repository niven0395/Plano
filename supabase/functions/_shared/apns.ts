interface APNSNotificationPayload {
  title: string;
  body: string;
  data: Record<string, string>;
  tokens: string[];
}

interface APNSConfig {
  teamID: string;
  keyID: string;
  privateKey: string;
  bundleID: string;
  useSandbox: boolean;
}

interface APNSDeliveryResult {
  delivered: number;
  failed: number;
  invalidTokens: string[];
  skipped: boolean;
  reason?: string;
}

export async function deliverAPNsNotifications(
  payload: APNSNotificationPayload,
): Promise<APNSDeliveryResult> {
  if (payload.tokens.length === 0) {
    return { delivered: 0, failed: 0, invalidTokens: [], skipped: true, reason: "no_tokens" };
  }

  const config = loadAPNSConfig();
  if (!config) {
    return {
      delivered: 0,
      failed: 0,
      invalidTokens: [],
      skipped: true,
      reason: "missing_apns_env",
    };
  }

  const authToken = await createAPNSToken(config);
  const endpoint = config.useSandbox
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";

  const body = JSON.stringify({
    aps: {
      alert: {
        title: payload.title,
        body: payload.body,
      },
      sound: "default",
    },
    ...payload.data,
  });

  let delivered = 0;
  let failed = 0;
  const invalidTokens: string[] = [];

  for (const token of payload.tokens) {
    const response = await fetch(`${endpoint}/3/device/${token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${authToken}`,
        "apns-topic": config.bundleID,
        "apns-push-type": "alert",
        "content-type": "application/json",
      },
      body,
    });

    if (response.ok) {
      delivered += 1;
      continue;
    }

    failed += 1;
    const failureReason = await readFailureReason(response);
    console.error(
      `APNs delivery failed for token ${token.slice(0, 12)}… (${response.status}): ${failureReason}`,
    );

    if (
      failureReason === "BadDeviceToken" ||
      failureReason === "DeviceTokenNotForTopic" ||
      failureReason === "Unregistered"
    ) {
      invalidTokens.push(token);
    }
  }

  return { delivered, failed, invalidTokens, skipped: false };
}

function loadAPNSConfig(): APNSConfig | null {
  const teamID = Deno.env.get("APNS_TEAM_ID");
  const keyID = Deno.env.get("APNS_KEY_ID");
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY");
  const bundleID = Deno.env.get("APNS_BUNDLE_ID");

  if (!teamID || !keyID || !privateKey || !bundleID) {
    return null;
  }

  return {
    teamID,
    keyID,
    privateKey: privateKey.replace(/\\n/g, "\n"),
    bundleID,
    useSandbox: Deno.env.get("APNS_USE_SANDBOX") !== "false",
  };
}

async function createAPNSToken(config: APNSConfig): Promise<string> {
  const header = base64UrlEncodeJSON({ alg: "ES256", kid: config.keyID });
  const claims = base64UrlEncodeJSON({
    iss: config.teamID,
    iat: Math.floor(Date.now() / 1000),
  });
  const signingInput = `${header}.${claims}`;

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(config.privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const derSignature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${derSignatureToJose(derSignature)}`;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const normalized = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = atob(normalized);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return bytes.buffer;
}

function base64UrlEncodeJSON(value: unknown): string {
  return base64UrlEncodeBytes(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlEncodeBytes(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function derSignatureToJose(signature: ArrayBuffer): string {
  const bytes = new Uint8Array(signature);
  if (bytes[0] !== 0x30) {
    throw new Error("Invalid DER signature format.");
  }

  let offset = 2;
  if (bytes[offset] !== 0x02) {
    throw new Error("Invalid DER signature R marker.");
  }
  offset += 1;

  const rLength = bytes[offset];
  offset += 1;
  const r = bytes.slice(offset, offset + rLength);
  offset += rLength;

  if (bytes[offset] !== 0x02) {
    throw new Error("Invalid DER signature S marker.");
  }
  offset += 1;

  const sLength = bytes[offset];
  offset += 1;
  const s = bytes.slice(offset, offset + sLength);

  const joseSignature = new Uint8Array(64);
  joseSignature.set(leftPad(removeLeadingZero(r), 32), 0);
  joseSignature.set(leftPad(removeLeadingZero(s), 32), 32);

  return base64UrlEncodeBytes(joseSignature);
}

function removeLeadingZero(bytes: Uint8Array): Uint8Array {
  return bytes[0] === 0x00 ? bytes.slice(1) : bytes;
}

function leftPad(bytes: Uint8Array, length: number): Uint8Array {
  if (bytes.length >= length) {
    return bytes.slice(bytes.length - length);
  }

  const padded = new Uint8Array(length);
  padded.set(bytes, length - bytes.length);
  return padded;
}

async function readFailureReason(response: Response): Promise<string> {
  try {
    const json = await response.json() as { reason?: string };
    return json.reason ?? response.statusText;
  } catch {
    return response.statusText;
  }
}
