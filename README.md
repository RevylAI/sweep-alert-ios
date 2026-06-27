# SweepAlert iOS

SweepAlert is a native SwiftUI example app for building mobile products with cloud-based coding agents.

This repo is intentionally app-focused. It contains the iOS app, its Convex backend, invite-link site, and the instructions an agent needs to safely modify, build, and validate the app with Revyl.

The separate cloud-agent runner should live in another repo. That runner can clone this repo, edit files in a Linux sandbox, call Revyl for native iOS builds, and validate the result on a cloud simulator.

## What Is Included

| Path | Purpose |
|---|---|
| `apps/ios-sweep-alert` | Native SwiftUI app, WidgetKit extension, Xcode project, Revyl config example. |
| `convex` | App backend for users, crews, cars, invites, APNs tokens, and notifications. |
| `site` | Static invite-link fallback for Universal Links. |
| `scripts` | App-specific release and automation scripts. |
| `docs` | Agent, App Store, and Revyl workflow notes. |

## Agent Loop

The intended development loop is:

```text
agent edits repo -> Revyl remote iOS build -> Revyl simulator validation -> patch/report
```

The agent does not need a full macOS sandbox. It needs this repo, Revyl credentials, and the commands in `AGENTS.md`.
GitHub PR previews are managed by the repo-level `.revyl/config.yaml`.

## Setup

Install JavaScript dependencies for Convex tooling:

```bash
npm install
```

Create local environment files from the examples:

```bash
cp .env.example .env.local
cp apps/ios-sweep-alert/.env.testflight.example .env.testflight
cp apps/ios-sweep-alert/.revyl/config.yaml.example apps/ios-sweep-alert/.revyl/config.yaml
```

Then fill in the values for your Auth0, Convex, Revyl, Apple Developer, and App Store Connect accounts.

## Backend

Run Convex locally:

```bash
npm run convex:dev
```

Deploy Convex:

```bash
npm run convex:deploy
```

See `convex/README.md` for Auth0 and APNs environment variables.

## iOS App

Open the app:

```bash
open apps/ios-sweep-alert/SweepAlertSwift.xcodeproj
```

Run the Revyl remote loop:

```bash
cd apps/ios-sweep-alert
revyl dev --context ios-native --remote --platform ios --build --no-open
revyl dev rebuild --context ios-native --wait --json
revyl dev use ios-native
revyl device screenshot --out /tmp/sweepalert-ios.png
```

## TestFlight

The TestFlight script requires App Store Connect credentials in `.env.testflight`:

```bash
set -a
source .env.testflight
set +a
npm run ios:testflight
```

No private keys or production credentials should be committed.
