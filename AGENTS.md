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

