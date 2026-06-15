export async function requireIdentity(ctx: any) {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    throw new Error("Auth required");
  }
  return identity;
}

export async function findUserBySubject(ctx: any, subject: string) {
  return await ctx.db
    .query("users")
    .withIndex("byAuth0Subject", (q: any) => q.eq("auth0Subject", subject))
    .unique();
}

export async function upsertUserFromIdentity(ctx: any) {
  const identity = await requireIdentity(ctx);
  const now = Date.now();
  const existing = await findUserBySubject(ctx, identity.subject);
  const displayName = identity.name ?? identity.nickname ?? identity.email ?? "SweepAlert user";
  const email = identity.email;

  if (existing) {
    await ctx.db.patch(existing._id, {
      displayName,
      email,
      updatedAt: now,
    });
    return existing;
  }

  const userId = await ctx.db.insert("users", {
    auth0Subject: identity.subject,
    displayName,
    email,
    createdAt: now,
    updatedAt: now,
  });

  return {
    _id: userId,
    auth0Subject: identity.subject,
    displayName,
    email,
    createdAt: now,
    updatedAt: now,
  };
}
