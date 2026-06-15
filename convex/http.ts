import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";

const TEAM_ID = process.env.APPLE_TEAM_ID;
const BUNDLE_ID = process.env.APP_BUNDLE_ID ?? "ai.revyl.sweepalert.swift";
const APP_ID = TEAM_ID ? `${TEAM_ID}.${BUNDLE_ID}` : undefined;

const http = httpRouter();

http.route({
  path: "/.well-known/apple-app-site-association",
  method: "GET",
  handler: httpAction(async () => {
    return new Response(
      JSON.stringify({
        applinks: {
          apps: [],
          details: [
            {
              appIDs: APP_ID ? [APP_ID] : [],
              components: [
                {
                  "/": "/invite/*",
                  comment: "SweepAlert car crew invite links",
                },
              ],
            },
          ],
        },
      }),
      {
        headers: {
          "content-type": "application/json",
          "cache-control": "public, max-age=300",
        },
      },
    );
  }),
});

http.route({
  pathPrefix: "/invite/",
  method: "GET",
  handler: httpAction(async (_ctx, request) => {
    const token = new URL(request.url).pathname.split("/").filter(Boolean).at(-1) ?? "";
    const appURL = `${BUNDLE_ID}://invite/${encodeURIComponent(token)}`;

    return new Response(
      `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SweepAlert Invite</title>
  <style>
    body { margin: 0; font: 16px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #111827; background: #f6f7fb; }
    main { min-height: 100vh; display: grid; place-items: center; padding: 24px; }
    section { max-width: 440px; background: white; border-radius: 20px; padding: 28px; box-shadow: 0 18px 60px rgba(15, 23, 42, .12); }
    h1 { margin: 0 0 10px; font-size: 30px; line-height: 1.05; }
    p { margin: 0 0 22px; color: #667085; line-height: 1.45; }
    a { display: inline-flex; align-items: center; justify-content: center; min-height: 48px; padding: 0 18px; border-radius: 14px; background: #1463f3; color: white; text-decoration: none; font-weight: 700; }
  </style>
</head>
<body>
  <main>
    <section>
      <h1>Join this SweepAlert car crew</h1>
      <p>Open the invite in SweepAlert to get shared parking reminders and move updates.</p>
      <a href="${appURL}">Open SweepAlert</a>
    </section>
  </main>
</body>
</html>`,
      {
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "no-store",
        },
      },
    );
  }),
});

export default http;
