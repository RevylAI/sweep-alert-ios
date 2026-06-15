# SweepAlert Convex Backend

This backend is the shared-car notification contract for the native SweepAlert demos.

It uses:

- Auth0 for user identity.
- Convex for app state, invite links, group actions, and scheduled reminder jobs.
- APNs for iOS parking reminders.

## Configure

Set Auth0 values in the Convex dashboard for each deployment:

```bash
AUTH0_DOMAIN=your-domain.us.auth0.com
AUTH0_CLIENT_ID=yourclientid
```

For iOS push, set:

```bash
APNS_ENVIRONMENT=sandbox
APNS_KEY_ID=your_apns_key_id
APNS_TEAM_ID=your_apple_team_id
APNS_TOPIC=ai.revyl.sweepalert.swift
APNS_PRIVATE_KEY_BASE64=base64_encoded_p8_file
APPLE_TEAM_ID=your_apple_team_id
APP_BUNDLE_ID=ai.revyl.sweepalert.swift
```

Then run:

```bash
npm install
npm run convex:dev
```

The native clients should send Auth0-issued tokens to Convex, then call the functions in `cars.ts`.

## Production Deployment

Use `getsweepalert.com` for invite links and Universal Links. The Convex HTTP router serves:

- `/.well-known/apple-app-site-association`
- `/invite/*`

If Convex custom domains are not available, deploy `site/public` from this repo to Cloudflare Pages or Vercel
and point `getsweepalert.com` at that static site.

To create the cloud Convex project non-interactively, the CLI needs:

- Convex access token or service account token.
- Convex team slug, not just the numeric team id.
- Auth0 domain and native iOS client id.

After the project is created, set the Auth0 env vars on the deployment and run:

```bash
npm run convex:deploy
```

## Flow

1. `users.upsertCurrentUser` maps the Auth0 subject into a SweepAlert user.
2. `cars.createInvite` creates a tokenized invite for a car crew.
3. `cars.acceptInvite` joins the signed-in user to the car.
4. `cars.parkCar` stores the active parking session and schedules a reminder.
5. `cars.claimMove` records who is handling the move.
6. `cars.completeMove` requires the new parked location, closes the previous session, cancels its pending reminders, creates the replacement parking session, and schedules the next reminder.
