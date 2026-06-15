# SweepAlert Swift Agent Instructions

You are editing the native SwiftUI app.

Important files:

- `SweepAlertSwift/ContentView.swift` - UI and sample street-cleaning rules.
- `SweepAlertSwift/SweepAlertSwiftApp.swift` - app entry point.
- `.revyl/config.yaml` - remote Xcode build command.

Rules:

1. Do not run local `xcodebuild`.
2. Use Revyl remote builds for every Swift source change.
3. Keep the context name `ios-native` unless the user gives another one.
4. Validate visible behavior on a Revyl simulator before finishing.

Commands:

```bash
revyl dev --context ios-native --remote --platform ios --build --no-open
revyl dev rebuild --context ios-native --wait --json
revyl dev use ios-native
revyl device screenshot --out /tmp/sweepalert-ios.png
revyl device instruction "Verify the SweepAlert screen shows a parked location and next street cleaning status."
```
