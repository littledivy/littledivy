/**
 * og-preview — tiny link-preview scraper for littledivy.com.
 * GET /?url=<encoded URL> -> { title, description, image, logo, domain }
 * Replaces microlink. CORS-open, edge-cached.
 */

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, OPTIONS',
};

export default {
  async fetch(req, env, ctx) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });

    const url = new URL(req.url);
    const target = url.searchParams.get('url');
    if (!target) return json({ error: 'missing ?url' }, 400);

    let t;
    try { t = new URL(target); } catch { return json({ error: 'bad url' }, 400); }
    if (!/^https?:$/.test(t.protocol)) return json({ error: 'bad protocol' }, 400);

    const cache = caches.default;
    const cacheKey = new Request(url.toString());
    const hit = await cache.match(cacheKey);
    if (hit) return hit;

    let data;
    try {
      const res = await fetch(t.href, {
        headers: {
          'user-agent': 'Mozilla/5.0 (compatible; og-preview/1.0; +https://littledivy.com)',
          accept: 'text/html,application/xhtml+xml',
        },
        cf: { cacheTtl: 3600, cacheEverything: true },
        signal: AbortSignal.timeout(6000),
      });
      const html = (await res.text()).slice(0, 600_000); // cap parse work
      data = parse(html, t);
    } catch {
      data = { title: host(t), description: '', image: '', logo: favicon(t), domain: host(t) };
    }

    const out = json(data, 200, { 'cache-control': 'public, max-age=86400' });
    ctx.waitUntil(cache.put(cacheKey, out.clone()));
    return out;
  },
};

function json(obj, status = 200, extra = {}) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', ...CORS, ...extra },
  });
}

const host = t => t.hostname.replace(/^www\./, '');
const favicon = t => `https://www.google.com/s2/favicons?domain=${host(t)}&sz=64`;

function metaContent(html, keys) {
  for (const k of keys) {
    // match <meta property|name="key" ... content="...">  (either attr order)
    const re = new RegExp(
      `<meta[^>]+(?:property|name)=["']${k}["'][^>]*>|<meta[^>]+content=["'][^"']*["'][^>]*(?:property|name)=["']${k}["'][^>]*>`,
      'i'
    );
    const tag = html.match(re);
    if (tag) {
      const c = tag[0].match(/content=["']([^"']*)["']/i);
      if (c && c[1]) return decode(c[1].trim());
    }
  }
  return '';
}

function parse(html, t) {
  const title =
    metaContent(html, ['og:title', 'twitter:title']) ||
    (html.match(/<title[^>]*>([^<]*)<\/title>/i)?.[1] || '').trim() ||
    host(t);
  const description = metaContent(html, ['og:description', 'twitter:description', 'description']);
  let image = metaContent(html, ['og:image:secure_url', 'og:image', 'twitter:image']);
  if (image) { try { image = new URL(image, t).href; } catch { image = ''; } }
  const domain = metaContent(html, ['og:site_name']) || host(t);
  return { title: decode(title), description, image, logo: favicon(t), domain };
}

function decode(s) {
  return s
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#0?39;|&#x27;|&apos;/gi, "'")
    .replace(/&nbsp;/g, ' ');
}
