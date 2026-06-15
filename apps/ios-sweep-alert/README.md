# SweepAlert iOS App

Native SwiftUI version of SweepAlert.

This app is intentionally structured so a background coding agent can modify it quickly and prove the full loop:

```text
Modal/Linux edit -> Revyl remote Xcode build -> Revyl iOS simulator validation
```

## Configure

Create a Revyl iOS app and paste its ID into `.revyl/config.yaml`:

```bash
revyl app create --name "SweepAlert Swift" --platform ios --json
```

Auth0 and Convex public client config live in `SweepAlertSwift/AppConfiguration.swift`,
`SweepAlertSwift/Auth0.plist`, and `SweepAlertSwift/Info.plist`. These are mobile-app identifiers,
not private secrets. Replace them for your own fork.

Current demo backend values:

- Auth0 domain: `dev-c15pmd5mlqf06u0m.us.auth0.com`
- Bundle identifier: `ai.revyl.sweepalert.swift`
- Convex URL: `https://upbeat-zebra-710.convex.cloud`
- Associated Domain: `applinks:getsweepalert.com`

Auth0 must allow these callback and logout URLs:

```text
https://dev-c15pmd5mlqf06u0m.us.auth0.com/ios/ai.revyl.sweepalert.swift/callback
ai.revyl.sweepalert.swift://dev-c15pmd5mlqf06u0m.us.auth0.com/ios/ai.revyl.sweepalert.swift/callback
```

Apple Developer capabilities for the explicit App ID:

- Associated Domains
- Push Notifications
- Time Sensitive Notifications

The Xcode project uses `SweepAlertSwift/SweepAlertSwift.entitlements`. Set your own Apple team in
Xcode or by passing `DEVELOPMENT_TEAM` during archive/export.
Debug builds register APNs tokens against the APNs sandbox environment.

Invite links are generated as `https://getsweepalert.com/invite/:token`. The app also handles
`ai.revyl.sweepalert.swift://invite/:token` as a fallback from the web invite page.

## TestFlight

The release script uses the `asc` App Store Connect CLI to archive, export, upload, and wait for
TestFlight processing:

```bash
brew install asc
cp apps/ios-sweep-alert/.env.testflight.example .env.testflight
```

Edit `.env.testflight` and replace `ASC_ISSUER_ID` with the issuer id from App Store Connect:

```text
Users and Access -> Integrations -> App Store Connect API -> Issuer ID
```

Then publish a build:

```bash
set -a
source .env.testflight
set +a
npm run ios:testflight
```

Required values:

- `ASC_ISSUER_ID`
- `ASC_KEY_ID`
- `ASC_PRIVATE_KEY_PATH`
- `APPLE_TEAM_ID`
- `ASC_BUNDLE_ID`
- `ASC_TESTFLIGHT_GROUP` when you want to distribute to a specific TestFlight group

Set `ASC_NOTIFY_TESTERS=1` or `ASC_TEST_NOTES` when you want the script to notify testers after
the upload finishes processing.

## Run

```bash
revyl dev --context ios-native --remote --platform ios --build --no-open
revyl dev rebuild --context ios-native --wait --json
revyl dev use ios-native
revyl device screenshot --out /tmp/sweepalert-ios.png
```

Do not run local `xcodebuild` inside Linux or Modal. `revyl dev --remote` sends the working tree to a Revyl Mac runner.
