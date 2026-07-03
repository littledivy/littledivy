/* littledivy.com — modern shell.
 * Grotesk type, dark by default, tight column, a vivid contained gradient card.
 */

(function () {
  document.documentElement.setAttribute('data-theme', localStorage.getItem('theme') || 'dark');
  const st = document.createElement('style');
  st.id = 'boot-hide';
  st.textContent = 'body { visibility: hidden; }';
  (document.head || document.documentElement).appendChild(st);
})();

function toggleTheme() {
  const html = document.documentElement;
  const next = (html.getAttribute('data-theme') === 'dark') ? 'light' : 'dark';
  html.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
}

(function () {
  // homepage identity
  const HOME = {
    brand: 'littledivy',
    title: 'Divy Srivastava',
    headline: 'Divy',
    role: 'Compilers, runtimes & graphics at Deno.',
  };
  const SOCIALS = [
    { t: 'GitHub', href: 'https://github.com/littledivy' },
    { t: 'X', href: 'https://x.com/undefined_void' },
    { t: 'Email', href: 'mailto:me@littledivy.com' },
  ];
  // cross-page search targets
  const POSTS = [
    { t: 'clawpatrol for personal agents', href: '/clawpatrol' },
    { t: 'Remote stack symbolication', href: '/resym' },
    { t: 'sh-deno', href: '/sh-deno' },
    { t: 'Turbocall', href: '/turbocall' },
    { t: 'Sui', href: '/sui' },
    { t: 'Scroll physics as a fitted model', href: '/scroll-physics-math' },
    { t: 'Path geometry and arc-length math', href: '/path-geometry' },
    { t: 'Mesh gradient interpolation', href: '/mesh-gradient-interpolation' },
    { t: 'Control springs and press pulses', href: '/control-springs' },
    { t: 'Share sheet motion', href: '/share-sheet-motion' },
    { t: 'Liquid Glass morphing', href: '/liquid-glass' },
  ];

  const ICON = {
    search: '<svg viewBox="0 0 16 16" width="15" height="15"><circle cx="7" cy="7" r="4.2" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M10.3 10.3L14 14" stroke="currentColor" stroke-width="1.4"/></svg>',
    moon: '<svg viewBox="0 0 16 16" width="15" height="15"><path d="M13 9.5A5 5 0 016.5 3 5 5 0 1013 9.5z" fill="none" stroke="currentColor" stroke-width="1.3"/></svg>',
  };

  function slug(s) {
    return s.toLowerCase().trim().replace(/[^\w]+/g, '-').replace(/^-+|-+$/g, '');
  }
  function h(tag, cls, html) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  }
  function isHome() {
    return /^\/(index\.html)?$/.test(location.pathname);
  }
  function reveal() {
    requestAnimationFrame(() => {
      const b = document.getElementById('boot-hide');
      if (b) b.remove();
    });
  }

  /* ---------- shell ---------- */
  let searchEntries = [];

  function build() {
    const body = document.body;
    const kids = Array.from(body.children).filter(n => n.tagName !== 'SCRIPT');
    const nav = kids.find(n => n.tagName === 'NAV');
    const titleEl = kids.find(n => n.tagName === 'H1');
    const bylineEl = kids.find(n => n.classList && n.classList.contains('byline'));
    const home = isHome();

    const title = home ? HOME.title : (titleEl ? titleEl.textContent : document.title);
    const sub = home ? '' : (bylineEl ? bylineEl.textContent.trim() : '');

    const drop = new Set([nav, titleEl]);
    if (!home && bylineEl) drop.add(bylineEl);
    if (home) kids.forEach(n => { if (n.tagName === 'P') drop.add(n); });
    const content = kids.filter(n => n && !drop.has(n));

    const article = h('article', 'prose');
    content.forEach(c => article.appendChild(c));
    const words = (article.textContent.trim().match(/\S+/g) || []).length;
    const mins = Math.max(1, Math.round(words / 220));

    const header = home
      ? buildHomeHero()
      : buildPostHero(title, (sub ? sub + '  ·  ' : '') + mins + ' min read');
    const col = h('div', 'col'); col.appendChild(article);
    const sheet = h('div', 'sheet'); sheet.appendChild(col);
    const main = h('main', 'page'); main.append(header, sheet);

    const topnav = buildTopnav();
    const prog = h('div', 'progress', '<span></span>');
    const bg = h('div', 'bg-shader'); bg.id = 'bg';
    const grid = h('div', 'grid'); grid.id = 'grid';

    body.innerHTML = '';
    body.append(bg, grid, prog, topnav, main);
    body.classList.add('shell');
    if (home) body.classList.add('is-home');

    enhanceBlocks(article);
    if (home) enhanceHome(article);
    buildSearchIndex(article);
    setupProgress();
    mountShaders(bg, home ? document.getElementById('screen') : null);

    document.addEventListener('keydown', e => {
      const typing = /INPUT|TEXTAREA/.test(document.activeElement.tagName);
      if (e.key === '/' && !typing) { e.preventDefault(); openSearch(); }
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); openSearch(); }
    });
    reveal();
  }

  function buildHomeHero() {
    const head = h('header', 'hero');
    head.innerHTML =
      `<div class="hero-copy">
         <h1 class="headline">${HOME.headline}</h1>
         <p class="hero-sub">${HOME.role}</p>
         <div class="socials">${SOCIALS.map(s => `<a href="${s.href}">${s.t}</a>`).join('')}</div>
       </div>`;
    return head;
  }

  function buildPostHero(title, meta) {
    const head = h('header', 'hero hero-post');
    head.innerHTML =
      `<a class="back" href="/">← Writing</a>
       <h1 class="post-title">${title}</h1>
       <div class="post-meta">${meta}</div>`;
    return head;
  }

  function buildTopnav() {
    const nav = h('nav', 'topnav');
    nav.innerHTML = `
      <a class="tn-brand" href="/">${HOME.brand}</a>
      <div class="tn-right">
        <a href="/">Writing</a>
        <a href="https://github.com/littledivy?tab=repositories">Projects</a>
        <button class="tn-search" aria-label="Search">${ICON.search}<span>Search</span><kbd>⌘K</kbd></button>
        <button class="tn-ico tn-theme" aria-label="Toggle theme">${ICON.moon}</button>
      </div>`;
    nav.querySelector('.tn-theme').onclick = toggleTheme;
    nav.querySelector('.tn-search').onclick = openSearch;
    let ticking = false;
    const onScroll = () => {
      if (ticking) return; ticking = true;
      requestAnimationFrame(() => { nav.classList.toggle('solid', window.scrollY > 24); ticking = false; });
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
    return nav;
  }

  /* ---------- Paper Shaders: warp backdrop + mesh "screen" ---------- */
  function mountShaders(bgEl, screenEl) {
    import('https://esm.sh/@paper-design/shaders@0.0.77').then(async m => {
      // mesh "screen" needs no noise texture — mount it right away
      if (screenEl) {
        try {
          const C = ['#eef6ff', '#93b8ff', '#4f7bff', '#c7e6ff'];
          const u = {
            u_colors: C.map(m.getShaderColorFromString), u_colorsCount: C.length,
            u_distortion: 0.8, u_swirl: 0.3, u_grainMixer: 0, u_grainOverlay: 0.12,
            u_fit: 2, u_scale: 1, u_rotation: 0, u_offsetX: 0, u_offsetY: 0,
            u_originX: 0.5, u_originY: 0.5, u_worldWidth: 0, u_worldHeight: 0,
          };
          new m.ShaderMount(screenEl, m.meshGradientFragmentShader, u, undefined, 0.5, 0);
        } catch (e) { console.error('[screen mesh] failed:', e); }
      }
      // warp backdrop needs its noise texture fully loaded first
      if (bgEl) {
        try {
          const noise = m.getShaderNoiseTexture();
          await new Promise(res => {
            if (!noise || noise.complete) return res();
            noise.onload = res; noise.onerror = res;
          });
          const C = ['#3a4bd6', '#6d7ff5', '#a4b4ff', '#24276a'];
          const u = {
            u_colors: C.map(m.getShaderColorFromString), u_colorsCount: C.length,
            u_proportion: 0.5, u_softness: 1, u_distortion: 0.28, u_swirl: 0.85,
            u_swirlIterations: 10, u_shapeScale: 0.3, u_shape: 2,
            u_noiseTexture: noise,
            u_fit: 0, u_scale: 1.1, u_rotation: 0, u_offsetX: 0, u_offsetY: 0,
            u_originX: 0.5, u_originY: 0.5, u_worldWidth: 0, u_worldHeight: 0,
          };
          new m.ShaderMount(bgEl, m.warpFragmentShader, u, undefined, 1.6, 0, 1);
        } catch (e) { console.error('[bg warp] failed:', e); }
      }
    }).catch(e => console.error('[shaders import] failed:', e));
  }

  /* ---------- homepage: writing entries + talk thumbnails ---------- */
  function ytId(href) {
    const m = (href || '').match(/(?:youtu\.be\/|[?&]v=)([\w-]{11})/);
    return m ? m[1] : null;
  }
  function enhanceHome(article) {
    article.querySelectorAll('ul').forEach(ul => {
      const lis = Array.from(ul.children).filter(n => n.tagName === 'LI');
      if (!lis.length) return;
      const isTalks = lis.some(li => /youtu\.?be|youtube\.com/.test(li.querySelector('a') ? li.querySelector('a').getAttribute('href') : ''));
      ul.classList.add(isTalks ? 'talks-grid' : 'writing-list');
      lis.forEach(li => {
        const a = li.querySelector('a');
        if (!a) return;
        const href = a.getAttribute('href');
        const title = a.textContent.trim();
        const full = li.textContent.replace(/\s+/g, ' ').trim();
        let desc = full.startsWith(title) ? full.slice(title.length) : full;
        desc = desc.replace(/^\s*[\u2014\u2013-]\s*/, '').trim();
        if (isTalks) {
          const id = ytId(href);
          const thumb = id ? `https://i.ytimg.com/vi/${id}/hqdefault.jpg` : '';
          li.innerHTML =
            `<a class="talk" href="${href}" target="_blank" rel="noopener">
               <span class="talk-thumb">${thumb ? `<img src="${thumb}" loading="lazy" alt="">` : ''}<span class="talk-play"></span></span>
               <span class="talk-body"><span class="talk-title">${title}</span><span class="talk-desc">${desc}</span></span>
             </a>`;
        } else {
          li.innerHTML =
            `<a class="entry" href="${href}"><span class="entry-title">${title}</span>${desc ? `<span class="entry-desc">${desc}</span>` : ''}</a>`;
        }
      });
    });
  }

  /* ---------- content polish ---------- */
  function enhanceBlocks(article) {
    article.querySelectorAll('pre').forEach(pre => {
      const code = pre.querySelector('code[data-lang]');
      const lang = code && code.getAttribute('data-lang');
      if (lang) pre.setAttribute('data-lang', lang);
    });
    article.querySelectorAll('figure').forEach(f => {
      if (!f.classList.contains('math') && (f.querySelector('svg') || f.querySelector('img'))) {
        f.classList.add('diagram');
      }
    });
    article.querySelectorAll('h2,h3,h4').forEach(hd => { if (!hd.id) hd.id = slug(hd.textContent); });
    const firstP = article.querySelector('p');
    if (firstP && !firstP.classList.contains('byline')) firstP.classList.add('lead');
  }

  function setupProgress() {
    const span = document.querySelector('.progress span');
    if (!span) return;
    let raf = 0;
    function update() {
      raf = 0;
      const max = document.documentElement.scrollHeight - window.innerHeight;
      span.style.width = (max > 0 ? Math.min(1, window.scrollY / max) * 100 : 0) + '%';
    }
    window.addEventListener('scroll', () => { if (!raf) raf = requestAnimationFrame(update); }, { passive: true });
    update();
  }

  /* ---------- search ---------- */
  function buildSearchIndex(article) {
    searchEntries = POSTS.map(p => ({ label: p.t, href: p.href, kind: 'post' }))
      .concat(Array.from(article.querySelectorAll('h2,h3'))
        .map(hd => ({ label: hd.textContent, href: '#' + hd.id, kind: '§' })));
  }
  function openSearch() {
    let ov = document.getElementById('site-search');
    if (ov) { ov.classList.add('open'); ov.querySelector('input').focus(); return; }
    ov = h('div', 'search-overlay', `
      <div class="so-box">
        <input type="text" placeholder="Search posts & sections…" autocomplete="off">
        <ul class="so-results"></ul>
      </div>`);
    ov.id = 'site-search';
    document.body.appendChild(ov);
    const input = ov.querySelector('input');
    const results = ov.querySelector('.so-results');
    let sel = 0;
    function render(q) {
      const ql = q.toLowerCase();
      const hits = searchEntries.filter(e => e.label.toLowerCase().includes(ql)).slice(0, 12);
      sel = 0;
      results.innerHTML = hits.map((e, i) =>
        `<li class="${i === 0 ? 'sel' : ''}" data-href="${e.href}"><span class="so-kind">${e.kind}</span>${e.label}</li>`).join('')
        || '<li class="so-empty">no matches</li>';
      results.querySelectorAll('li[data-href]').forEach((li, i) => {
        li.onmousemove = () => { results.querySelectorAll('li').forEach(x => x.classList.remove('sel')); li.classList.add('sel'); sel = i; };
        li.onclick = () => go(li.dataset.href);
      });
    }
    function go(href) { close(); if (href[0] === '#') { location.hash = href; } else { location.href = href; } }
    function close() { ov.classList.remove('open'); }
    input.oninput = () => render(input.value);
    input.onkeydown = (e) => {
      const items = [...results.querySelectorAll('li[data-href]')];
      if (e.key === 'ArrowDown') { sel = Math.min(sel + 1, items.length - 1); e.preventDefault(); }
      else if (e.key === 'ArrowUp') { sel = Math.max(sel - 1, 0); e.preventDefault(); }
      else if (e.key === 'Enter') { if (items[sel]) go(items[sel].dataset.href); return; }
      else if (e.key === 'Escape') { close(); return; }
      items.forEach((x, i) => x.classList.toggle('sel', i === sel));
      if (items[sel]) items[sel].scrollIntoView({ block: 'nearest' });
    };
    ov.onclick = (e) => { if (e.target === ov) close(); };
    render('');
    ov.classList.add('open');
    input.focus();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build);
  else build();
})();

/* ---- KaTeX math (lazy, self-hosted) ---- */
(function () {
  const scriptUrl = (() => {
    const cur = document.currentScript;
    if (cur && cur.src) return cur.src;
    const fallback = [...document.getElementsByTagName('script')].find(s => (s.src || '').includes('theme.js'));
    return fallback && fallback.src ? fallback.src : location.href;
  })();
  const asset = rel => new URL(rel, scriptUrl).href;
  function renderAll() {
    document.querySelectorAll('.math-tex:not(.math-done)').forEach(el => {
      try {
        window.katex.render(el.textContent, el, {
          displayMode: el.classList.contains('math-display'),
          throwOnError: false,
        });
        el.classList.add('math-done');
      } catch (e) {}
    });
  }
  function init() {
    if (!document.querySelector('.math-tex')) return;
    if (window.katex) return renderAll();
    const css = document.createElement('link');
    css.rel = 'stylesheet'; css.href = asset('katex/katex.min.css');
    document.head.appendChild(css);
    const js = document.createElement('script');
    js.src = asset('katex/katex.min.js'); js.onload = renderAll;
    document.head.appendChild(js);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();

/* ---- image lightbox ---- */
(function () {
  document.addEventListener('click', e => {
    const img = e.target.closest('.prose img, .page img');
    if (!img) return;
    const ov = document.createElement('div');
    ov.className = 'lightbox';
    const big = document.createElement('img');
    big.src = img.currentSrc || img.src;
    ov.appendChild(big);
    ov.onclick = () => ov.remove();
    document.addEventListener('keydown', function esc(ev) {
      if (ev.key === 'Escape') { ov.remove(); document.removeEventListener('keydown', esc); }
    });
    document.body.appendChild(ov);
    requestAnimationFrame(() => ov.classList.add('open'));
  });
})();

/* ---- link hover previews (internal posts + external) ---- */
const OG_ENDPOINT = 'https://og-preview.littledivy.workers.dev';
(function () {
  const cache = new Map();
  let card, showTimer = 0, hideTimer = 0, curLink = null;
  function classify(href) {
    if (!href || href[0] === '#' || href.startsWith('mailto:') || href.startsWith('javascript:')) return null;
    let u; try { u = new URL(href, location.href); } catch (e) { return null; }
    if (!/^https?:$/.test(u.protocol)) return null;
    if (u.origin === location.origin) return u.pathname === location.pathname ? null : 'internal';
    return 'external';
  }
  const host = u => { try { return new URL(u).hostname.replace(/^www\./, ''); } catch (e) { return u; } };
  const clip = (s, n) => { const w = (s || '').split(/\s+/); return w.length > n ? w.slice(0, n).join(' ') + '…' : (s || ''); };
  async function fetchHtml(href) {
    let r = await fetch(href);
    if (!r.ok && !/\.html?$/.test(href)) r = await fetch(href.replace(/\/+$/, '') + '.html');
    if (!r.ok) throw new Error('404');
    return r.text();
  }
  function loadInternal(href) {
    return fetchHtml(href).then(html => {
      const doc = new DOMParser().parseFromString(html, 'text/html');
      const title = (doc.querySelector('h1') || doc.querySelector('title') || {}).textContent || href;
      const date = (doc.querySelector('.byline') || {}).textContent || '';
      const paras = Array.from(doc.querySelectorAll('body > p, main > p, .prose > p'))
        .filter(p => !p.classList.contains('byline'))
        .map(p => p.textContent.trim()).filter(Boolean);
      let ex = paras.join(' ');
      if (!ex) ex = (doc.querySelector('meta[name="description"]') || {}).content || '';
      return { kind: 'internal', title: title.trim(), date: date.trim(), desc: clip(ex, 55), domain: 'littledivy.com' };
    });
  }
  function loadExternal(href) {
    const fav = 'https://www.google.com/s2/favicons?domain=' + host(href) + '&sz=64';
    return fetch(OG_ENDPOINT + '/?url=' + encodeURIComponent(href))
      .then(r => r.json()).then(d => ({
        kind: 'external', title: d.title || host(href), desc: clip(d.description, 40),
        image: d.image || '', logo: d.logo || fav, domain: d.domain || host(href),
      })).catch(() => ({ kind: 'external', title: host(href), desc: '', logo: fav, domain: host(href) }));
  }
  function load(href, kind) {
    if (cache.has(href)) return cache.get(href);
    const pr = (kind === 'internal' ? loadInternal(href) : loadExternal(href)).catch(() => null);
    cache.set(href, pr);
    return pr;
  }
  function ensureCard() {
    if (card) return card;
    card = document.createElement('div');
    card.className = 'link-preview';
    card.addEventListener('mouseenter', () => clearTimeout(hideTimer));
    card.addEventListener('mouseleave', hide);
    document.body.appendChild(card);
    return card;
  }
  function render(c, d) {
    c.innerHTML = '';
    c.classList.toggle('has-image', !!d.image);
    if (d.image) {
      const im = document.createElement('img'); im.className = 'lp-image'; im.src = d.image; im.loading = 'lazy';
      im.onerror = () => im.remove(); c.appendChild(im);
    }
    const body = document.createElement('div'); body.className = 'lp-body';
    const dom = document.createElement('div'); dom.className = 'lp-domain';
    if (d.logo) { const f = document.createElement('img'); f.src = d.logo; f.onerror = () => f.remove(); dom.appendChild(f); }
    const ds = document.createElement('span'); ds.textContent = d.domain || ''; dom.appendChild(ds);
    body.appendChild(dom);
    const t = document.createElement('div'); t.className = 'lp-title'; t.textContent = d.title; body.appendChild(t);
    if (d.date) { const m = document.createElement('div'); m.className = 'lp-meta'; m.textContent = d.date; body.appendChild(m); }
    if (d.desc) { const x = document.createElement('div'); x.className = 'lp-desc'; x.textContent = d.desc; body.appendChild(x); }
    c.appendChild(body);
  }
  function place(c, a) {
    const r = a.getBoundingClientRect(), w = 340;
    c.style.left = Math.max(8, Math.min(r.left, window.innerWidth - w - 8)) + 'px';
    if (r.bottom + 220 > window.innerHeight) { c.style.top = 'auto'; c.style.bottom = (window.innerHeight - r.top + 8) + 'px'; }
    else { c.style.bottom = 'auto'; c.style.top = (r.bottom + 8) + 'px'; }
  }
  function show(a, kind) {
    const c = ensureCard();
    if (kind === 'external') {
      const hn = host(a.href);
      render(c, { kind: 'external', domain: hn, title: hn, desc: '', logo: 'https://www.google.com/s2/favicons?domain=' + hn + '&sz=64' });
      place(c, a); c.classList.add('visible');
    }
    load(a.href, kind).then(d => { if (!d || curLink !== a) return; render(c, d); place(c, a); c.classList.add('visible'); });
  }
  function hide() { hideTimer = setTimeout(() => { if (card) card.classList.remove('visible'); curLink = null; }, 180); }
  document.addEventListener('mouseover', e => {
    const a = e.target.closest('a');
    if (!a || a.closest('.topnav, .search-overlay')) return;
    const kind = classify(a.getAttribute('href'));
    if (!kind) return;
    clearTimeout(hideTimer); curLink = a; clearTimeout(showTimer);
    showTimer = setTimeout(() => show(a, kind), kind === 'internal' ? 130 : 220);
  });
  document.addEventListener('mouseout', e => { if (e.target.closest('a')) { clearTimeout(showTimer); hide(); } });
})();
