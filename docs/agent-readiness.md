# Agent Readiness

SweepAlert is structured so a cloud agent can work on it without a full Mac sandbox.

## Required Capabilities

- Clone the repo into an isolated filesystem.
- Edit Swift, Convex, site, and docs files.
- Run Node tooling for Convex checks.
- Call Revyl CLI for remote iOS builds and simulator validation.

## Stable Commands

```bash
npm install
npx tsc -p convex/tsconfig.json --noEmit
```

```bash
cd apps/ios-sweep-alert
revyl dev --context ios-native --remote --platform ios --build --no-open
revyl dev rebuild --context ios-native --wait --json
revyl device screenshot --out /tmp/sweepalert-ios.png
```

## Validation Expectations

For UI changes, the agent should produce device evidence: a screenshot, a device instruction result, or a short run log from the active Revyl session.

For backend changes, the agent should run the Convex TypeScript check and document any required environment-variable changes.

