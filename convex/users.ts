import { mutation } from "./_generated/server";
import { v } from "convex/values";
import { findUserBySubject, requireIdentity } from "./authHelpers";

export const upsertCurrentUser = mutation({
  args: {
    displayName: v.optional(v.string()),
    email: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await requireIdentity(ctx);

    const now = Date.now();
    const existing = await findUserBySubject(ctx, identity.subject);

    const displayName = args.displayName ?? identity.name ?? identity.nickname ?? "SweepAlert user";
    const email = args.email ?? identity.email;

    if (existing) {
      await ctx.db.patch(existing._id, {
        displayName,
        email,
        updatedAt: now,
      });
      return existing._id;
    }

    return await ctx.db.insert("users", {
      auth0Subject: identity.subject,
      displayName,
      email,
      createdAt: now,
      updatedAt: now,
    });
  },
});
