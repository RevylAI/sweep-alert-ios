import { internal } from "./_generated/api";
import { internalAction, internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";

type ApnsEnvironment = "sandbox" | "production";

let cachedProviderToken: { token: string; expiresAt: number } | null = null;
let cachedSigningKey: CryptoKey | null = null;

function requiredEnv(name: string) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required Convex environment variable ${name}`);
  }
  return value;
}

function base64ToBytes(value: string) {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function base64UrlEncode(value: string | ArrayBuffer | Uint8Array) {
  const bytes =
    typeof value === "string"
      ? new TextEncoder().encode(value)
      : value instanceof Uint8Array
        ? value
        : new Uint8Array(value);

  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function signingKey() {
  if (cachedSigningKey) {
    return cachedSigningKey;
  }

  const pem = new TextDecoder().decode(base64ToBytes(requiredEnv("APNS_PRIVATE_KEY_BASE64")));
  const pkcs8 = base64ToBytes(
    pem
      .replace("-----BEGIN PRIVATE KEY-----", "")
      .replace("-----END PRIVATE KEY-----", "")
      .replace(/\s/g, ""),
  );

  cachedSigningKey = await crypto.subtle.importKey(
    "pkcs8",
    pkcs8,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  return cachedSigningKey;
}

async function providerToken() {
  const now = Math.floor(Date.now() / 1000);
  if (cachedProviderToken && cachedProviderToken.expiresAt > now + 60) {
    return cachedProviderToken.token;
  }

  const header = {
    alg: "ES256",
    kid: requiredEnv("APNS_KEY_ID"),
  };
  const claims = {
    iss: requiredEnv("APNS_TEAM_ID"),
    iat: now,
  };
  const signingInput = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(claims))}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    await signingKey(),
    new TextEncoder().encode(signingInput),
  );

  const token = `${signingInput}.${base64UrlEncode(signature)}`;
  cachedProviderToken = { token, expiresAt: now + 50 * 60 };
  return token;
}

async function sendApnsAlert(args: {
  pushToken: string;
  title: string;
  body: string;
  environment: ApnsEnvironment;
}) {
  const host =
    args.environment === "production"
      ? "https://api.push.apple.com"
      : "https://api.sandbox.push.apple.com";
  const topic = requiredEnv("APNS_TOPIC");

  const response = await fetch(`${host}/3/device/${args.pushToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerToken()}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: {
          title: args.title,
          body: args.body,
        },
        sound: "default",
        "interruption-level": "time-sensitive",
      },
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`APNs ${response.status}: ${errorBody}`);
  }
}

function deviceApnsEnvironment(device: { pushEnvironment?: ApnsEnvironment }) {
  return device.pushEnvironment ?? "sandbox";
}

async function membersForCar(ctx: any, carId: any) {
  const car = await ctx.db.get(carId);
  if (car?.crewId) {
    return await ctx.db
      .query("crewMembers")
      .withIndex("byCrew", (q: any) => q.eq("crewId", car.crewId))
      .collect();
  }

  return await ctx.db
    .query("carMembers")
    .withIndex("byCar", (q: any) => q.eq("carId", carId))
    .collect();
}

export const getReminderPayload = internalQuery({
  args: {
    parkingSessionId: v.id("parkingSessions"),
  },
  handler: async (ctx, args) => {
    const session = await ctx.db.get(args.parkingSessionId);
    if (!session || session.status === "moved") {
      return null;
    }

    const car = await ctx.db.get(session.carId);
    const members = await membersForCar(ctx, session.carId);
    const devices = [];
    for (const member of members) {
      if (!member.pushAlerts) {
        continue;
      }
      const memberDevices = await ctx.db
        .query("devices")
        .withIndex("byUser", (q) => q.eq("userId", member.userId))
        .collect();
      devices.push(...memberDevices.filter((device) => device.enabled));
    }

    return {
      parkingSessionId: session._id,
      carName: car?.name ?? "Your car",
      corridor: session.corridor,
      side: session.side,
      scheduleLabel: session.scheduleLabel,
      devices,
    };
  },
});

export const getCrewUpdatePayload = internalQuery({
  args: {
    carId: v.id("cars"),
    actorUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, args) => {
    const members = await membersForCar(ctx, args.carId);

    const devices = [];
    for (const member of members) {
      if (args.actorUserId && member.userId === args.actorUserId) {
        continue;
      }
      if (!member.claimUpdates) {
        continue;
      }
      const memberDevices = await ctx.db
        .query("devices")
        .withIndex("byUser", (q) => q.eq("userId", member.userId))
        .collect();
      devices.push(...memberDevices.filter((device) => device.enabled));
    }

    return { devices };
  },
});

export const markReminderSent = internalMutation({
  args: {
    parkingSessionId: v.id("parkingSessions"),
    status: v.union(v.literal("sent"), v.literal("failed")),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const jobs = await ctx.db
      .query("alertJobs")
      .withIndex("bySession", (q) => q.eq("parkingSessionId", args.parkingSessionId))
      .collect();

    for (const job of jobs) {
      if (job.status === "scheduled") {
        await ctx.db.patch(job._id, { status: args.status, updatedAt: now });
      }
    }
  },
});

export const sendParkingReminder = internalAction({
  args: {
    parkingSessionId: v.id("parkingSessions"),
  },
  handler: async (ctx, args) => {
    const payload = await ctx.runQuery(internal.notifications.getReminderPayload, args);
    if (!payload) {
      return;
    }

    let sentCount = 0;
    let failedCount = 0;

    for (const device of payload.devices) {
      if (device.platform !== "ios") {
        continue;
      }
      const environment = deviceApnsEnvironment(device);

      try {
        await sendApnsAlert({
          pushToken: device.pushToken,
          title: `${payload.carName}: street cleaning soon`,
          body: `${payload.corridor} ${payload.side} side - ${payload.scheduleLabel}`,
          environment,
        });
        sentCount += 1;
      } catch (error) {
        failedCount += 1;
        console.error("[push:apns-failed]", {
          pushToken: device.pushToken,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    await ctx.runMutation(internal.notifications.markReminderSent, {
      ...args,
      status: failedCount > 0 && sentCount === 0 ? "failed" : "sent",
    });
  },
});

export const sendCrewUpdate = internalAction({
  args: {
    carId: v.id("cars"),
    title: v.string(),
    body: v.string(),
    actorUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, args) => {
    const payload = await ctx.runQuery(internal.notifications.getCrewUpdatePayload, {
      carId: args.carId,
      actorUserId: args.actorUserId,
    });
    for (const device of payload.devices) {
      if (device.platform !== "ios") {
        continue;
      }
      const environment = deviceApnsEnvironment(device);

      try {
        await sendApnsAlert({
          pushToken: device.pushToken,
          title: args.title,
          body: args.body,
          environment,
        });
      } catch (error) {
        console.error("[push:crew-update-failed]", {
          pushToken: device.pushToken,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  },
});
