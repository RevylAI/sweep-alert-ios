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

This is a Linux VM. The iOS app in `apps/ios-sweep-alert` cannot be built or run here
(`xcodebuild`/Xcode and the Revyl CLI are not available). The runnable/testable service in
this environment is the **Convex TypeScript backend** in `convex/`. iOS validation still
requires Revyl remote builds with `REVYL_API_KEY` (see `README.md` / `docs/revyl-dev-loop.md`).

Backend dev/test (non-obvious caveats):

- The standalone backend typecheck `npx tsc -p convex/tsconfig.json --noEmit` needs the
  `@types/node` devDependency (the `convex/*.ts` files use `process.env`); it is included via
  the update script's `npm install`.
- Run a local Convex backend **without an account** by setting `CONVEX_AGENT_MODE=anonymous`
  (a beta flag) on every `convex` invocation, e.g. `CONVEX_AGENT_MODE=anonymous npx convex dev`.
  The first run downloads a local backend binary and writes the local deployment URLs to
  `.env.local` (client API on `:3210`, HTTP actions / Universal Links on `:3211`).
- Deploying functions fails until the Auth0 env vars exist on the deployment. For local-only
  testing set placeholders once: `CONVEX_AGENT_MODE=anonymous npx convex env set AUTH0_DOMAIN <x>`
  and `... env set AUTH0_CLIENT_ID <y>`. Real Auth0/APNs values are only needed for true E2E.
- All public functions in `convex/cars.ts` and `convex/users.ts` are auth-gated via
  `requireIdentity` and throw `Auth required` when called without a valid Auth0 identity, so
  `npx convex run <fn>` cannot exercise them directly without a real token. To smoke-test core
  domain logic locally, drive the schema/scheduler through a temporary `convex/` function and
  delete it afterward.
- Call functions / inspect state against the local backend with
  `CONVEX_AGENT_MODE=anonymous npx convex run <module>:<fn>` and
  `... npx convex function-spec`.

