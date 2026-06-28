# SweepAlert Agent Contract

You are working in a native iOS app repo designed for cloud coding agents.

Primary app path:

- `apps/ios-sweep-alert`

Backend path:

- `convex`

Rules:

1. Keep app changes scoped to the iOS app, Convex backend, site, scripts, or docs in this repo.
2. Do not commit local credentials, `.env*` files, APNs keys, App Store Connect keys, Revyl sessions, or build artifacts.
3. Prefer Revyl remote builds for iOS validation when credentials are available.
4. Keep the Revyl dev context stable for a task, usually `ios-native`.
5. After changing user-visible behavior, rebuild and validate on a Revyl simulator before claiming completion.
6. After changing Convex functions or schema, run the Convex TypeScript check.

Useful commands:

```bash
npm install
npx tsc -p convex/tsconfig.json --noEmit
```

```bash
cd apps/ios-sweep-alert
revyl dev --context ios-native --remote --platform ios --build --no-open
revyl dev rebuild --context ios-native --wait --json
revyl dev use ios-native
revyl device screenshot --out /tmp/sweepalert-ios.png
revyl device instruction "Verify SweepAlert shows the selected car, parked location, next street-cleaning status, and crew controls."
```

Completion checklist:

- The app builds.
- Backend typecheck passes when backend files changed.
- Visible behavior is validated with a screenshot or device instruction.
- Any new setup requirement is documented in `README.md` or `docs/`.

## Cursor Cloud specific instructions

This VM is Linux with Node available but **no macOS/Xcode**. The two parts of the product have very different testability here:

- **Convex backend (`convex/`)** — fully runnable locally with no account. Run `npx convex dev` and choose `Start without an account (run Convex locally)`; it downloads a local backend, serves it at `http://127.0.0.1:3210` (HTTP actions at `:3211`), and writes deployment info to `.env.local` (gitignored). Keep this process running to develop. Local dashboard: `npx convex dashboard` (http://127.0.0.1:6790).
- **iOS app (`apps/ios-sweep-alert`)** — cannot be built/run on this VM. It requires Revyl remote builds (`REVYL_API_KEY`) plus Auth0/Apple credentials. Without those secrets, iOS build/validation is out of scope; do not run local `xcodebuild`.

Backend gotchas:

- The documented typecheck `npx tsc -p convex/tsconfig.json --noEmit` needs `@types/node` (the functions use `process.env`); it is in `devDependencies`, so `npm install` covers it.
- Pushing functions to the local deployment fails unless `AUTH0_DOMAIN` and `AUTH0_CLIENT_ID` are set on the deployment (they are referenced in `auth.config.ts`). For local-only dev set placeholders: `npx convex env set AUTH0_DOMAIN <any>` and `npx convex env set AUTH0_CLIENT_ID <any>`. These live on the local deployment, not in the repo.
- Every `cars.ts`/`users.ts` mutation/query calls `requireIdentity` and needs a real Auth0-issued token, so they can't be exercised end-to-end without Auth0 credentials. What you *can* test without secrets: the unauthenticated HTTP routes (`/.well-known/apple-app-site-association`, `/invite/:token`) via `curl`, and seeding/reading data through `npx convex run`/`npx convex data` or the dashboard.

