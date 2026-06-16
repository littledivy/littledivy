# og-preview

Self-hosted link-preview scraper (replaces microlink). Fetches a URL, parses
OpenGraph/Twitter/`<title>` tags, returns `{ title, description, image, logo, domain }`
as JSON with CORS. Edge-cached 24h.

## Deploy

```sh
cd workers/og-preview
npx wrangler deploy
```

Gives you `https://og-preview.<your-subdomain>.workers.dev`.

Then set that URL in `theme.js` → `OG_ENDPOINT` (top of the file).

### Optional: serve on your own domain

Uncomment the `routes` block in `wrangler.jsonc` to serve it at
`littledivy.com/og`, then set `OG_ENDPOINT = '/og'` in theme.js (same-origin, no CORS needed).

## Test

```sh
curl 'https://og-preview.<sub>.workers.dev/?url=https://youtu.be/qt3-3FkPqQ8'
```
