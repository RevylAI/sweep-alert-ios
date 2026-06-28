# Atlas App Exploration

SweepAlert is a native SwiftUI app whose primary UI lives in
`apps/ios-sweep-alert/SweepAlertSwift/ContentView.swift`. The app starts on a
San Francisco street-cleaning map and changes the bottom panel based on auth,
crew, car, and parking-session state.

## Primary App States

| State | How to reach it | Reliable markers |
|---|---|---|
| Signed-out home | Fresh install or after logout | `signed-out-login-button`, `settings-button`, "Never miss street cleaning again." |
| Settings unauthenticated | Tap the top-right gear while signed out | `settings-screen`, `login-button`, "Sign in to sync alerts", "Sign in to manage cars" |
| Empty crew | Log in with an account that has no cars | "Add your first car", crew management controls |
| Crew settings | Open Settings while authenticated | `settings-screen`, `logout-button`, invite button, notification toggles |
| Parked car rules | Select a car and set a parking pin | Rule rows with corridor, side, distance, and next sweep time |
| Repark flow | Start moving a currently parked car | Repark controls and map pin placement |
| Invite acceptance | Open an invite deep link | Invite alert or settings redirect if signed out |

## Settings Unauthenticated Cluster

The Atlas cluster named "Settings Unauthenticated" is the `SettingsScreen`
view rendered when `AuthenticationService.isAuthenticated == false`. It is not
a separate route or file.

### Entry Points

1. Start from a fresh or signed-out simulator session.
2. Tap the top-right gear (`settings-button`) on the map header.
3. Alternatively, tap the small gear next to the signed-out home panel login
   button.

Signed-out map taps and invite deep links also redirect users into Settings
after explaining that sign-in is required.

### Expected UI

The unauthenticated Settings screen should show:

- Top title: "Settings"
- Header copy: "Manage your crew, cars, shared alerts, and who can move them."
- Account section: "Sign in to sync alerts"
- Account detail: "Use Auth0 to join crews and receive shared car updates."
- Primary account action: "Log in" (`login-button`)
- Crew section: "Sign in to manage cars"
- Crew detail: "Crew names, invite links, cars, and push alerts are stored after login."

Authenticated-only controls such as `logout-button`, invite sharing,
notification toggles, car editing, and member lists should not be visible.

### Revyl Verification

```bash
cd apps/ios-sweep-alert
revyl dev use ios-native
revyl device instruction "Tap the top-right gear while signed out. Verify Settings opens with 'Sign in to sync alerts', a Log in button, and 'Sign in to manage cars'."
revyl device screenshot --out /tmp/settings-unauthenticated.png
```

If the simulator has persisted Auth0 credentials, open Settings and tap
"Log out" first, then reopen Settings to return to this cluster.
