import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    auth0Subject: v.string(),
    displayName: v.string(),
    email: v.optional(v.string()),
    createdAt: v.number(),
    updatedAt: v.number(),
  }).index("byAuth0Subject", ["auth0Subject"]),

  devices: defineTable({
    userId: v.id("users"),
    platform: v.union(v.literal("ios"), v.literal("android")),
    pushToken: v.string(),
    pushEnvironment: v.optional(v.union(v.literal("sandbox"), v.literal("production"))),
    enabled: v.boolean(),
    timezone: v.optional(v.string()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("byUser", ["userId"])
    .index("byPushToken", ["pushToken"]),

  crews: defineTable({
    name: v.string(),
    createdBy: v.id("users"),
    createdAt: v.number(),
    updatedAt: v.number(),
  }).index("byCreatedBy", ["createdBy"]),

  crewMembers: defineTable({
    crewId: v.id("crews"),
    userId: v.id("users"),
    role: v.union(v.literal("owner"), v.literal("can_move")),
    pushAlerts: v.boolean(),
    claimUpdates: v.boolean(),
    firstReminderHours: v.number(),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("byCrew", ["crewId"])
    .index("byUser", ["userId"])
    .index("byCrewUser", ["crewId", "userId"]),

  cars: defineTable({
    crewId: v.optional(v.id("crews")),
    name: v.string(),
    color: v.optional(v.string()),
    createdBy: v.id("users"),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("byCreatedBy", ["createdBy"])
    .index("byCrew", ["crewId"]),

  carMembers: defineTable({
    carId: v.id("cars"),
    userId: v.id("users"),
    role: v.union(v.literal("owner"), v.literal("can_move")),
    pushAlerts: v.boolean(),
    claimUpdates: v.boolean(),
    firstReminderHours: v.number(),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("byCar", ["carId"])
    .index("byUser", ["userId"])
    .index("byCarUser", ["carId", "userId"]),

  invites: defineTable({
    crewId: v.optional(v.id("crews")),
    carId: v.optional(v.id("cars")),
    inviterUserId: v.id("users"),
    token: v.string(),
    expiresAt: v.number(),
    acceptedBy: v.optional(v.id("users")),
    acceptedAt: v.optional(v.number()),
    createdAt: v.number(),
  }).index("byToken", ["token"]),

  parkingSessions: defineTable({
    carId: v.id("cars"),
    parkedBy: v.id("users"),
    status: v.union(v.literal("parked"), v.literal("claimed"), v.literal("moved")),
    latitude: v.number(),
    longitude: v.number(),
    corridor: v.string(),
    side: v.string(),
    ruleId: v.string(),
    scheduleLabel: v.string(),
    nextSweepAt: v.number(),
    claimedBy: v.optional(v.id("users")),
    claimedAt: v.optional(v.number()),
    movedBy: v.optional(v.id("users")),
    movedAt: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("byCarStatus", ["carId", "status"])
    .index("byNextSweep", ["nextSweepAt"]),

  alertJobs: defineTable({
    parkingSessionId: v.id("parkingSessions"),
    carId: v.id("cars"),
    kind: v.union(v.literal("first_reminder"), v.literal("final_reminder")),
    fireAt: v.number(),
    status: v.union(v.literal("scheduled"), v.literal("sent"), v.literal("canceled"), v.literal("failed")),
    scheduledFunctionId: v.optional(v.id("_scheduled_functions")),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("bySession", ["parkingSessionId"])
    .index("byFireAt", ["fireAt"]),
});
