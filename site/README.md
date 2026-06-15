# SweepAlert Invite Site

Static HTTPS fallback for `getsweepalert.com`.

It serves:

- `/.well-known/apple-app-site-association`
- `/invite/:token`

Deploy `public/` to Cloudflare Pages, Vercel, Netlify, or any HTTPS static host.

## Cloudflare Pages

```bash
CLOUDFLARE_ACCOUNT_ID=757147f111e5759398d43144ec20da7f wrangler pages deploy public --project-name sweepalert --branch main
```

The direct-upload project is `sweepalert` in the Revyl Cloudflare account.

Temporary Pages URL:

- `https://sweepalert.pages.dev`

Custom domain:

- `getsweepalert.com`

If the custom domain is pending, add this DNS record in the `getsweepalert.com` Cloudflare zone:

| Type | Name | Content | Proxy |
| --- | --- | --- | --- |
| CNAME | `@` | `sweepalert.pages.dev` | Proxied |

Then verify:

```bash
curl -I https://getsweepalert.com/.well-known/apple-app-site-association
curl -I https://getsweepalert.com/invite/test-token
```

## Vercel

```bash
vercel deploy public
```

Then add `getsweepalert.com` as a project domain. `vercel.json` rewrites `/invite/*` to the invite page.
