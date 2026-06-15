# Revyl Dev Loop

SweepAlert uses Revyl for the iOS parts that do not fit naturally inside a Linux sandbox.

```text
Linux sandbox edits files
  -> Revyl remote Mac runner builds simulator app
  -> Revyl cloud simulator installs app
  -> agent inspects screenshots and interacts with the device
```

Start the loop:

```bash
cd apps/ios-sweep-alert
revyl dev --context ios-native --remote --platform ios --build --no-open
```

Rebuild after edits:

```bash
revyl dev rebuild --context ios-native --wait --json
```

Inspect the app:

```bash
revyl dev use ios-native
revyl device screenshot --out /tmp/sweepalert-ios.png
revyl device instruction "Check whether the settings screen opens and crew controls are readable."
```

