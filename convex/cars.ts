import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { findUserBySubject, requireIdentity, upsertUserFromIdentity } from "./authHelpers";

const DEFAULT_CREW_NAME = "Apartment car crew";
const DEFAULT_CAR_NAME = "Roommates' Honda";
const DEFAULT_CAR_COLOR = "blue";

async function requireCrewMember(ctx: any, crewId: Id<"crews">, userId: Id<"users">) {
  const member = await ctx.db
    .query("crewMembers")
    .withIndex("byCrewUser", (q: any) => q.eq("crewId", crewId).eq("userId", userId))
    .unique();

  if (!member) {
    throw new Error("Crew access required");
  }

  return member;
}

async function legacyCarMembers(ctx: any, carId: Id<"cars">) {
  return await ctx.db
    .query("carMembers")
    .withIndex("byCar", (q: any) => q.eq("carId", carId))
    .collect();
}

async function migrateLegacyCarToCrew(
  ctx: any,
  carId: Id<"cars">,
  fallbackUserId: Id<"users">,
  now: number,
): Promise<Id<"crews">> {
  const car = await ctx.db.get(carId);
  if (!car) {
    throw new Error("Car not found");
  }

  if (car.crewId) {
    return car.crewId as Id<"crews">;
  }

  const crewId = await ctx.db.insert("crews", {
    name: DEFAULT_CREW_NAME,
    createdBy: car.createdBy ?? fallbackUserId,
    createdAt: now,
    updatedAt: now,
  });

  await ctx.db.patch(carId, {
    crewId,
    color: car.color ?? DEFAULT_CAR_COLOR,
    updatedAt: now,
  });

  const members = await legacyCarMembers(ctx, carId);
  if (members.length === 0) {
    await ctx.db.insert("crewMembers", {
      crewId,
      userId: fallbackUserId,
      role: "owner",
      pushAlerts: true,
      claimUpdates: true,
      firstReminderHours: 12,
      createdAt: now,
      updatedAt: now,
    });
    return crewId;
  }

  for (const member of members) {
    const existing = await ctx.db
      .query("crewMembers")
      .withIndex("byCrewUser", (q: any) => q.eq("crewId", crewId).eq("userId", member.userId))
      .unique();
    if (existing) {
      continue;
    }
    await ctx.db.insert("crewMembers", {
      crewId,
      userId: member.userId,
      role: member.role,
      pushAlerts: member.pushAlerts,
      claimUpdates: member.claimUpdates,
      firstReminderHours: member.firstReminderHours,
      createdAt: now,
      updatedAt: now,
    });
  }

  return crewId;
}

async function requireCarCrewMember(ctx: any, carId: Id<"cars">, userId: Id<"users">) {
  const car = await ctx.db.get(carId);
  if (!car) {
    throw new Error("Car not found");
  }

  const now = Date.now();
  const crewId = car.crewId ?? (await migrateLegacyCarToCrew(ctx, carId, userId, now));
  const member = await requireCrewMember(ctx, crewId, userId);
  return { car: { ...car, crewId }, crewId, member };
}

async function userName(ctx: any, userId?: Id<"users">) {
  if (!userId) {
    return undefined;
  }
  const user = await ctx.db.get(userId);
  return user?.displayName;
}

async function activeParkingSession(ctx: any, carId: Id<"cars">) {
  for (const status of ["claimed", "parked"] as const) {
    const session = await ctx.db
      .query("parkingSessions")
      .withIndex("byCarStatus", (q: any) => q.eq("carId", carId).eq("status", status))
      .first();
    if (session) {
      return session;
    }
  }
  return null;
}

async function serializeParkingSession(ctx: any, session: any) {
  if (!session) {
    return null;
  }

  return {
    id: session._id,
    status: session.status,
    latitude: session.latitude,
    longitude: session.longitude,
    corridor: session.corridor,
    side: session.side,
    ruleId: session.ruleId,
    scheduleLabel: session.scheduleLabel,
    nextSweepAt: session.nextSweepAt,
    parkedByName: await userName(ctx, session.parkedBy),
    claimedByName: await userName(ctx, session.claimedBy),
    claimedAt: session.claimedAt,
    movedByName: await userName(ctx, session.movedBy),
    movedAt: session.movedAt,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
  };
}

async function serializeCrew(ctx: any, crewId: Id<"crews">, currentUserId: Id<"users">) {
  const crew = await ctx.db.get(crewId);
  if (!crew) {
    throw new Error("Crew not found");
  }

  const members = await ctx.db
    .query("crewMembers")
    .withIndex("byCrew", (q: any) => q.eq("crewId", crewId))
    .collect();

  const cars = await ctx.db
    .query("cars")
    .withIndex("byCrew", (q: any) => q.eq("crewId", crewId))
    .collect();

  const serializedCars = await Promise.all(
    cars.map(async (car: any) => ({
      id: car._id,
      name: car.name,
      color: car.color ?? DEFAULT_CAR_COLOR,
      activeSession: await serializeParkingSession(ctx, await activeParkingSession(ctx, car._id)),
    })),
  );

  return {
    id: crew._id,
    name: crew.name,
    carName: serializedCars[0]?.name ?? DEFAULT_CAR_NAME,
    members: await Promise.all(
      members.map(async (member: any) => {
        const user = await ctx.db.get(member.userId);
        return {
          id: member.userId,
          name: user?.displayName ?? "SweepAlert user",
          role: member.role,
          isCurrentUser: member.userId === currentUserId,
        };
      }),
    ),
    cars: serializedCars,
  };
}

function inviteToken() {
  return crypto.randomUUID().replaceAll("-", "").slice(0, 16);
}

async function cancelScheduledJobs(ctx: any, parkingSessionId: Id<"parkingSessions">, now: number) {
  const jobs = await ctx.db
    .query("alertJobs")
    .withIndex("bySession", (q: any) => q.eq("parkingSessionId", parkingSessionId))
    .collect();

  for (const job of jobs) {
    if (job.status === "scheduled" && job.scheduledFunctionId) {
      await ctx.scheduler.cancel(job.scheduledFunctionId);
      await ctx.db.patch(job._id, { status: "canceled", updatedAt: now });
    }
  }
}

async function createParkingSession(
  ctx: any,
  carId: Id<"cars">,
  userId: Id<"users">,
  args: {
    latitude: number;
    longitude: number;
    corridor: string;
    side: string;
    ruleId: string;
    scheduleLabel: string;
    nextSweepAt: number;
    firstReminderHours?: number;
  },
  now: number,
) {
  const parkingSessionId = await ctx.db.insert("parkingSessions", {
    carId,
    parkedBy: userId,
    status: "parked",
    latitude: args.latitude,
    longitude: args.longitude,
    corridor: args.corridor,
    side: args.side,
    ruleId: args.ruleId,
    scheduleLabel: args.scheduleLabel,
    nextSweepAt: args.nextSweepAt,
    createdAt: now,
    updatedAt: now,
  });

  const leadHours = args.firstReminderHours ?? 12;
  const leadReminderAt = args.nextSweepAt - leadHours * 60 * 60 * 1000;
  const latestUsefulReminderAt = Math.max(args.nextSweepAt - 15 * 60 * 1000, now + 60_000);
  const fireAt = leadReminderAt > now ? leadReminderAt : Math.min(now + 15 * 60 * 1000, latestUsefulReminderAt);
  if (fireAt <= now || fireAt >= args.nextSweepAt) {
    return parkingSessionId;
  }

  const scheduledFunctionId = await ctx.scheduler.runAt(fireAt, internal.notifications.sendParkingReminder, {
    parkingSessionId,
  });

  await ctx.db.insert("alertJobs", {
    parkingSessionId,
    carId,
    kind: "first_reminder",
    fireAt,
    status: "scheduled",
    scheduledFunctionId,
    createdAt: now,
    updatedAt: now,
  });

  return parkingSessionId;
}

async function ensureDefaultCrewForUser(ctx: any, user: any): Promise<Id<"crews">> {
  const existingMembership = await ctx.db
    .query("crewMembers")
    .withIndex("byUser", (q: any) => q.eq("userId", user._id))
    .first();

  if (existingMembership) {
    return existingMembership.crewId as Id<"crews">;
  }

  const legacyMembership = await ctx.db
    .query("carMembers")
    .withIndex("byUser", (q: any) => q.eq("userId", user._id))
    .first();

  if (legacyMembership) {
    return await migrateLegacyCarToCrew(ctx, legacyMembership.carId, user._id, Date.now());
  }

  const now = Date.now();
  const crewId = await ctx.db.insert("crews", {
    name: DEFAULT_CREW_NAME,
    createdBy: user._id,
    createdAt: now,
    updatedAt: now,
  });

  await ctx.db.insert("crewMembers", {
    crewId,
    userId: user._id,
    role: "owner",
    pushAlerts: true,
    claimUpdates: true,
    firstReminderHours: 12,
    createdAt: now,
    updatedAt: now,
  });

  await ctx.db.insert("cars", {
    crewId,
    name: DEFAULT_CAR_NAME,
    color: DEFAULT_CAR_COLOR,
    createdBy: user._id,
    createdAt: now,
    updatedAt: now,
  });

  return crewId;
}

async function crewIdFromInvite(ctx: any, invite: any, userId: Id<"users">): Promise<Id<"crews">> {
  if (invite.crewId) {
    return invite.crewId as Id<"crews">;
  }
  if (invite.carId) {
    return await migrateLegacyCarToCrew(ctx, invite.carId, userId, Date.now());
  }
  throw new Error("Invite is missing a crew");
}

export const getMyCars = query({
  args: {},
  handler: async (ctx) => {
    const identity = await requireIdentity(ctx);
    const user = await findUserBySubject(ctx, identity.subject);
    if (!user) {
      return [];
    }

    const memberships = await ctx.db
      .query("crewMembers")
      .withIndex("byUser", (q) => q.eq("userId", user._id))
      .collect();

    const cars = [];
    for (const membership of memberships) {
      const crewCars = await ctx.db
        .query("cars")
        .withIndex("byCrew", (q) => q.eq("crewId", membership.crewId))
        .collect();
      cars.push(...crewCars.map((car) => ({ car, membership })));
    }

    return cars;
  },
});

export const ensureDefaultCrew = mutation({
  args: {
    name: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    const crewId = await ensureDefaultCrewForUser(ctx, user);
    if (args.name) {
      const crew = await ctx.db.get(crewId);
      if (crew && crew.name === DEFAULT_CREW_NAME) {
        await ctx.db.patch(crewId, { name: args.name, updatedAt: Date.now() });
      }
    }
    return await serializeCrew(ctx, crewId, user._id);
  },
});

export const ensureDefaultCar = mutation({
  args: {
    name: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    const crewId = await ensureDefaultCrewForUser(ctx, user);
    const cars = await ctx.db
      .query("cars")
      .withIndex("byCrew", (q) => q.eq("crewId", crewId))
      .collect();

    if (args.name && cars.length === 1 && cars[0].name === DEFAULT_CAR_NAME) {
      await ctx.db.patch(cars[0]._id, { name: args.name, updatedAt: Date.now() });
    }

    return await serializeCrew(ctx, crewId, user._id);
  },
});

export const createCar = mutation({
  args: {
    crewId: v.id("crews"),
    name: v.string(),
    color: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    await requireCrewMember(ctx, args.crewId, user._id);
    const now = Date.now();
    await ctx.db.insert("cars", {
      crewId: args.crewId,
      name: args.name,
      color: args.color ?? "green",
      createdBy: user._id,
      createdAt: now,
      updatedAt: now,
    });

    return await serializeCrew(ctx, args.crewId, user._id);
  },
});

export const renameCrew = mutation({
  args: {
    crewId: v.id("crews"),
    name: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    await requireCrewMember(ctx, args.crewId, user._id);
    await ctx.db.patch(args.crewId, {
      name: args.name.trim() || DEFAULT_CREW_NAME,
      updatedAt: Date.now(),
    });
    return await serializeCrew(ctx, args.crewId, user._id);
  },
});

export const renameCar = mutation({
  args: {
    carId: v.id("cars"),
    name: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    const { crewId } = await requireCarCrewMember(ctx, args.carId, user._id);
    await ctx.db.patch(args.carId, {
      name: args.name.trim() || "Shared car",
      updatedAt: Date.now(),
    });
    return await serializeCrew(ctx, crewId, user._id);
  },
});

export const createInvite = mutation({
  args: {
    crewId: v.optional(v.id("crews")),
    carId: v.optional(v.id("cars")),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    let crewId = args.crewId;
    if (!crewId && args.carId) {
      crewId = (await requireCarCrewMember(ctx, args.carId, user._id)).crewId;
    }
    const resolvedCrewId = crewId ?? (await ensureDefaultCrewForUser(ctx, user));
    await requireCrewMember(ctx, resolvedCrewId, user._id);

    const now = Date.now();
    const token = inviteToken();
    await ctx.db.insert("invites", {
      crewId: resolvedCrewId,
      inviterUserId: user._id,
      token,
      expiresAt: now + 1000 * 60 * 60 * 24 * 14,
      createdAt: now,
    });

    return {
      token,
      url: `https://getsweepalert.com/invite/${token}`,
    };
  },
});

export const acceptInvite = mutation({
  args: {
    token: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    const invite = await ctx.db
      .query("invites")
      .withIndex("byToken", (q) => q.eq("token", args.token))
      .unique();

    if (!invite || invite.expiresAt < Date.now()) {
      throw new Error("Invite expired");
    }

    const crewId = await crewIdFromInvite(ctx, invite, user._id);
    const existing = await ctx.db
      .query("crewMembers")
      .withIndex("byCrewUser", (q) => q.eq("crewId", crewId).eq("userId", user._id))
      .unique();

    if (!existing) {
      const now = Date.now();
      await ctx.db.insert("crewMembers", {
        crewId,
        userId: user._id,
        role: "can_move",
        pushAlerts: true,
        claimUpdates: true,
        firstReminderHours: 12,
        createdAt: now,
        updatedAt: now,
      });
    }

    await ctx.db.patch(invite._id, {
      acceptedBy: user._id,
      acceptedAt: Date.now(),
    });

    return await serializeCrew(ctx, crewId, user._id);
  },
});

export const registerDevice = mutation({
  args: {
    platform: v.union(v.literal("ios"), v.literal("android")),
    pushToken: v.string(),
    timezone: v.optional(v.string()),
    environment: v.optional(v.union(v.literal("sandbox"), v.literal("production"))),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    const now = Date.now();
    const existing = await ctx.db
      .query("devices")
      .withIndex("byPushToken", (q) => q.eq("pushToken", args.pushToken))
      .unique();

    if (existing) {
      await ctx.db.patch(existing._id, {
        userId: user._id,
        platform: args.platform,
        pushEnvironment: args.environment ?? "sandbox",
        timezone: args.timezone,
        enabled: true,
        updatedAt: now,
      });
      return existing._id;
    }

    return await ctx.db.insert("devices", {
      userId: user._id,
      platform: args.platform,
      pushToken: args.pushToken,
      pushEnvironment: args.environment ?? "sandbox",
      timezone: args.timezone,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const updateNotificationPreferences = mutation({
  args: {
    crewId: v.optional(v.id("crews")),
    carId: v.optional(v.id("cars")),
    pushAlerts: v.boolean(),
    claimUpdates: v.boolean(),
    firstReminderHours: v.number(),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    let crewId = args.crewId;
    if (!crewId && args.carId) {
      crewId = (await requireCarCrewMember(ctx, args.carId, user._id)).crewId;
    }
    const resolvedCrewId = crewId ?? (await ensureDefaultCrewForUser(ctx, user));

    const member = await requireCrewMember(ctx, resolvedCrewId, user._id);
    const now = Date.now();

    await ctx.db.patch(member._id, {
      pushAlerts: args.pushAlerts,
      claimUpdates: args.claimUpdates,
      firstReminderHours: args.firstReminderHours,
      updatedAt: now,
    });
  },
});

export const parkCar = mutation({
  args: {
    carId: v.id("cars"),
    latitude: v.number(),
    longitude: v.number(),
    corridor: v.string(),
    side: v.string(),
    ruleId: v.string(),
    scheduleLabel: v.string(),
    nextSweepAt: v.number(),
    firstReminderHours: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    const { crewId } = await requireCarCrewMember(ctx, args.carId, user._id);

    const now = Date.now();
    for (const status of ["parked", "claimed"] as const) {
      const active = await ctx.db
        .query("parkingSessions")
        .withIndex("byCarStatus", (q) => q.eq("carId", args.carId).eq("status", status))
        .first();
      if (active) {
        await ctx.db.patch(active._id, { status: "moved", movedAt: now, movedBy: user._id, updatedAt: now });
        await cancelScheduledJobs(ctx, active._id, now);
      }
    }

    await createParkingSession(ctx, args.carId, user._id, args, now);
    return await serializeCrew(ctx, crewId, user._id);
  },
});

export const claimMove = mutation({
  args: {
    parkingSessionId: v.id("parkingSessions"),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    const session = await ctx.db.get(args.parkingSessionId);
    if (!session || session.status === "moved") {
      throw new Error("No active parking session");
    }
    const { car, crewId } = await requireCarCrewMember(ctx, session.carId, user._id);

    await ctx.db.patch(session._id, {
      status: "claimed",
      claimedBy: user._id,
      claimedAt: Date.now(),
      updatedAt: Date.now(),
    });

    await ctx.scheduler.runAfter(0, internal.notifications.sendCrewUpdate, {
      carId: session.carId,
      title: "Move claimed",
      body: `${user.displayName} is moving ${car.name}.`,
      actorUserId: user._id,
    });

    return await serializeCrew(ctx, crewId, user._id);
  },
});

export const completeMove = mutation({
  args: {
    previousParkingSessionId: v.id("parkingSessions"),
    latitude: v.number(),
    longitude: v.number(),
    corridor: v.string(),
    side: v.string(),
    ruleId: v.string(),
    scheduleLabel: v.string(),
    nextSweepAt: v.number(),
    firstReminderHours: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const user = await upsertUserFromIdentity(ctx);
    const session = await ctx.db.get(args.previousParkingSessionId);
    if (!session || session.status === "moved") {
      throw new Error("No active parking session");
    }
    const { car, crewId } = await requireCarCrewMember(ctx, session.carId, user._id);

    const now = Date.now();
    await ctx.db.patch(session._id, {
      status: "moved",
      movedBy: user._id,
      movedAt: now,
      updatedAt: now,
    });

    await cancelScheduledJobs(ctx, session._id, now);

    await createParkingSession(ctx, session.carId, user._id, args, now);
    await ctx.scheduler.runAfter(0, internal.notifications.sendCrewUpdate, {
      carId: session.carId,
      title: `${car.name} re-parked`,
      body: `${user.displayName} set the new parking spot.`,
      actorUserId: user._id,
    });

    return await serializeCrew(ctx, crewId, user._id);
  },
});
