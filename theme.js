/* littledivy.com — modern shell.
 * Grotesk type, dark by default, tight column, a vivid contained gradient card.
 */

(function () {
  document.documentElement.setAttribute('data-theme', 'dark');
  const st = document.createElement('style');
  st.id = 'boot-hide';
  st.textContent = 'body { visibility: hidden; }';
  (document.head || document.documentElement).appendChild(st);
})();

(function () {
  // homepage identity
  const HOME = {
    brand: 'littledivy',
    title: 'Divy Srivastava',
    headline: 'Divy',
    role: 'Research and Engineering',
    story: [
      'I work at Deno, building and optimizing the runtime. Most of what I do sits close to the metal: performance engineering, compilers, cryptography, and the odd detour into AI research and graphics.',
      'These days the work runs more like a small lab than a personal blog — a lot of experiments, a fleet of agents, and notes from both.',
    ],
  };
  // Talks nav links straight to a YouTube playlist. Replace with your real playlist URL.
  const TALKS_URL = 'https://www.youtube.com/playlist?list=REPLACE_WITH_PLAYLIST_ID';
  const SOCIALS = [
    { t: 'GitHub', href: 'https://github.com/littledivy' },
    { t: 'X', href: 'https://x.com/undefined_void' },
    { t: 'Email', href: 'mailto:me@littledivy.com' },
  ];
  // cross-page search targets
  // full site index — every page the search can jump to
  const SITE = [
    { t: 'clawpatrol for personal agents', d: 'security firewall for AI agents', href: '/clawpatrol', kind: 'post', tag: 'security' },
    { t: 'Remote stack trace symbolication', d: 'serializable stack trace collection for remote symbolication', href: '/resym', kind: 'post', tag: 'debug' },
    { t: 'sh-deno', d: 'apple’s seatbelt sandboxing + deno’s permission system for hardened runtime security', href: '/sh-deno', kind: 'post', tag: 'security' },
    { t: 'Turbocall', d: 'JIT compiler generating trampolines for V8 ↔ FFI bindings', href: '/turbocall', kind: 'post', tag: 'compiler' },
    { t: 'Sui', d: 'cross-platform injection of arbitrary data into prebuilt binaries', href: '/sui', kind: 'post', tag: 'systems' },
    { t: 'Scroll physics as a fitted model', d: 'calibrating iOS scroll feel from traces, not guesses', href: '/scroll-physics-math', kind: 'post', tag: 'motion' },
    { t: 'Path geometry and arc-length math', d: 'flattening, trimming, winding, transforms, and boolean ops', href: '/path-geometry', kind: 'post', tag: 'graphics' },
    { t: 'Mesh gradient interpolation', d: 'bilinear grids, smoothstep seams, and gamma-space color mixing', href: '/mesh-gradient-interpolation', kind: 'post', tag: 'graphics' },
    { t: 'Control springs and press pulses', d: 'spring responses for buttons, toggles, sliders, and focus rings', href: '/control-springs', kind: 'post', tag: 'motion' },
    { t: 'Share sheet motion', d: 'one-slot modal state and a damped spring that feels like iOS', href: '/share-sheet-motion', kind: 'post', tag: 'motion' },
    { t: 'Liquid Glass morphing', d: 'identity, union, and frame morphing for Apple’s translucent material', href: '/liquid-glass', kind: 'post', tag: 'graphics' },
    { t: 'Kernel to runtime', d: 'how javascript calls become syscalls: event loops, epoll, async i/o — IIT Kanpur OOSC 3', href: 'https://youtu.be/qt3-3FkPqQ8?t=450', kind: 'talk' },
    { t: 'Deno internals: op2 driver', d: 'deno_core internals, runtime call overhead, js↔rust translation layer', href: 'https://www.youtube.com/watch?v=vINOqgn_ik8', kind: 'talk' },
    { t: 'Building games with deno ffi', d: 'cross-platform game using SDL2 in JS', href: 'https://www.youtube.com/watch?v=RKjVcl62J9w', kind: 'talk' },
    { t: 'WebGPU windowing', d: 'rendering a gpu-accelerated window using webgpu and window surface APIs', href: 'https://www.youtube.com/watch?v=gA152Hun8cI', kind: 'talk' },
    { t: 'Injecting r/o data into binaries', d: 'cross-platform tool that powers deno’s compiler', href: 'https://www.youtube.com/watch?v=5wlZDw942J8', kind: 'talk' },
    { t: 'JIT compiler for dynamic FFI', d: 'blazing-fast compiler generating trampolines for ffi calls for V8', href: 'https://www.youtube.com/watch?v=ssYN4rFWRIU', kind: 'talk' },
    { t: 'Projects', d: 'open-source repositories on GitHub', href: 'https://github.com/littledivy?tab=repositories', kind: 'page' },
    { t: 'Home', d: 'littledivy — systems research on compilers, runtimes & graphics', href: '/', kind: 'page' },
  ];

  const ICON = {
    search: '<svg viewBox="0 0 16 16" width="15" height="15"><circle cx="7" cy="7" r="4.2" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M10.3 10.3L14 14" stroke="currentColor" stroke-width="1.4"/></svg>',
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
  const contentIndex = {};      // href -> full plain text of the post
  let contentLoading = false;

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
    if (home) mountPostShaders(document);

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
         <div class="hero-story">${HOME.story.map(p => `<p>${p}</p>`).join('')}</div>
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
        <a href="/#posts">Writing</a>
        <a href="/#talks">Talks</a>
        <a href="https://github.com/littledivy?tab=repositories">Projects</a>
        <button class="tn-search" aria-label="Search">${ICON.search}<span>Search</span><kbd>⌘K</kbd></button>
      </div>`;
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
      // grain-gradient backdrop (needs its noise texture loaded first)
      if (bgEl) {
        try {
          const noise = m.getShaderNoiseTexture();
          await new Promise(res => { if (!noise || noise.complete) return res(); noise.onload = res; noise.onerror = res; });
          const C = ['#20265f', '#4a5ce0', '#9fb0ff'];
          const u = {
            u_colorBack: m.getShaderColorFromString('#0a0c18'),
            u_colors: C.map(m.getShaderColorFromString), u_colorsCount: C.length,
            u_softness: 0.6, u_intensity: 0.45, u_noise: 0.55, u_shape: 6 /* blob */,
            u_noiseTexture: noise,
            u_fit: 2, u_scale: 1, u_rotation: 0, u_offsetX: 0, u_offsetY: 0,
            u_originX: 0.5, u_originY: 0.5, u_worldWidth: 0, u_worldHeight: 0,
          };
          // (parent, frag, uniforms, ctxAttrs, speed, frame, minPixelRatio)
          new m.ShaderMount(bgEl, m.grainGradientFragmentShader, u, undefined, 0.6, 0, 1);
        } catch (e) { console.error('[bg grain] failed:', e); }
      }
    }).catch(e => console.error('[shaders import] failed:', e));
  }

  /* ---------- homepage: writing entries + talk thumbnails ---------- */
  function ytId(href) {
    const m = (href || '').match(/(?:youtu\.be\/|[?&]v=)([\w-]{11})/);
    return m ? m[1] : null;
  }
  function injectSvg2(el, url) {
    if (!el) return;
    fetch(url).then(r => r.ok ? r.text() : Promise.reject()).then(svg => {
      const tmp = document.createElement('div'); tmp.innerHTML = svg;
      const s = tmp.querySelector('svg');
      if (s) { s.classList.add('map-svg'); el.insertBefore(s, el.firstChild); }
    }).catch(() => {});
  }
  function enhanceHome(article) {
    article.querySelectorAll('ul').forEach(ul => {
      const lis = Array.from(ul.children).filter(n => n.tagName === 'LI');
      if (!lis.length) return;
      // newest first — sort by data-date (ISO), then reflect the order in the DOM
      lis.sort((a, b) => (b.getAttribute('data-date') || '').localeCompare(a.getAttribute('data-date') || ''));
      lis.forEach(li => ul.appendChild(li));
      ul.classList.add('writing-grid');
      lis.forEach((li, i) => {
        const a = li.querySelector('a');
        if (!a) return;
        const href = a.getAttribute('href');
        const title = a.textContent.trim();
        const tag = (li.getAttribute('data-tag') || '').trim();
        const full = li.textContent.replace(/\s+/g, ' ').trim();
        let desc = full.startsWith(title) ? full.slice(title.length) : full;
        desc = desc.replace(/^\s*[\u2014\u2013-]\s*/, '').trim();
        const yt = ytId(href);
        const media = yt
          ? `<span class="post-media is-talk">
               <img class="post-thumb" loading="lazy" alt="" src="https://i.ytimg.com/vi/${yt}/maxresdefault.jpg"
                    onerror="this.onerror=null;this.src='https://i.ytimg.com/vi/${yt}/hqdefault.jpg'">
             </span>`
          : `<span class="post-media"><span class="post-shader" data-idx="${i}"></span><span class="post-figs"></span></span>`;
        li.innerHTML =
          `<a class="post entry" href="${href}">
             ${media}
             <span class="post-body">
               <span class="post-meta"></span>
               <span class="post-title">${title}</span>
               ${desc ? `<span class="post-desc">${desc}</span>` : ''}
             </span>
           </a>`;
        if (!yt) fillCard(li.querySelector('.entry'), href, tag);
      });
    });
  }

  // collect a post's figures (collage if >1) + byline date/topic into meta
  function fillCard(card, href, tag) {
    if (!card) return;
    const figBox = card.querySelector('.post-figs');
    const meta = card.querySelector('.post-meta');
    const clean = f => f && !/favicon/.test(f.getAttribute('src') || '');
    const urls = /\.html?$/.test(href) ? [href] : [href, href.replace(/\/+$/, '') + '.html'];
    (function go(i) {
      if (i >= urls.length) return;
      fetch(urls[i]).then(r => r.ok ? r.text() : Promise.reject()).then(html => {
        const doc = new DOMParser().parseFromString(html, 'text/html');
        let figs = [...doc.querySelectorAll('figure svg, figure img')].filter(clean);
        if (!figs.length) { const a2 = doc.querySelector('svg, img'); if (clean(a2)) figs = [a2]; }
        figs = figs.slice(0, 2);
        if (figBox && figs.length) {
          figBox.classList.add('has', 'n' + figs.length);
          figs.forEach(f => {
            const fr = document.createElement('span'); fr.className = 'post-fig';
            fr.appendChild(document.importNode(f, true));
            figBox.appendChild(fr);
          });
        }
        const by = doc.querySelector('.byline');
        const words = (doc.body.textContent.trim().match(/\S+/g) || []).length;
        const mins = Math.max(1, Math.round(words / 220));
        const date = by ? by.textContent.trim().split(/\s*[·—]\s*/)[0].trim() : '';
        if (meta) meta.textContent = [date, mins + ' min'].filter(Boolean).join('  ·  ');
      }).catch(() => go(i + 1));
    })(0);
  }

  // a unique grain-gradient shader per writing post, mounted once when it scrolls in
  function mountPostShaders(root) {
    const cells = [...root.querySelectorAll('.post-shader')];
    if (!cells.length) return;
    import('https://esm.sh/@paper-design/shaders@0.0.77').then(async m => {
      const noise = m.getShaderNoiseTexture();
      await new Promise(res => { if (!noise || noise.complete) return res(); noise.onload = res; noise.onerror = res; });
      // dark jewel palettes — visibly colored but never bright enough to hide light figures
      const PAL = [
        ['#101c52', '#243a86', '#3a54c0'], ['#0a2e3a', '#125a68', '#1e8a9a'],
        ['#1e1250', '#3e2482', '#5e40b0'], ['#301226', '#722448', '#a83e68'],
        ['#0e2e1c', '#246040', '#369658'], ['#2e2010', '#7a5424', '#b07e34'],
      ];
      const mkU = idx => {
        const C = PAL[idx % PAL.length];
        return {
          u_colorBack: m.getShaderColorFromString('#0a0c18'),
          u_colors: C.map(m.getShaderColorFromString), u_colorsCount: C.length,
          u_softness: 0.74, u_intensity: 0.52, u_noise: 0.48, u_shape: idx % 7,
          u_noiseTexture: noise, u_fit: 2, u_scale: 1, u_rotation: (idx * 37) % 360,
          u_offsetX: 0, u_offsetY: 0, u_originX: 0.5, u_originY: 0.5, u_worldWidth: 0, u_worldHeight: 0,
        };
      };
      const io = new IntersectionObserver((ents, obs) => {
        ents.forEach(e => {
          if (!e.isIntersecting || e.target._m) return;
          const el = e.target, idx = +el.dataset.idx || 0;
          try { el._m = new m.ShaderMount(el, m.grainGradientFragmentShader, mkU(idx), undefined, 0.32, idx * 90, 1); } catch (err) {}
          obs.unobserve(el);
        });
      }, { rootMargin: '300px 0px' });
      cells.forEach(c => io.observe(c));
    }).catch(e => console.error('[post shaders] failed:', e));
  }

  /* ---------- homepage: specimen plate + section glyphs (Fable art) ---------- */
  function injectSvg(el, file) {
    return fetch('art/' + file + '.svg')
      .then(r => r.ok ? r.text() : '')
      .then(svg => { if (svg) el.innerHTML = svg; })
      .catch(() => {});
  }
  function decorateHome(article, col) {
    // small nature glyphs beside the section headers
    const glyphMap = { writing: 'glyph-writing', talks: 'glyph-talks' };
    article.querySelectorAll('h3').forEach(hd => {
      const file = glyphMap[hd.textContent.trim().toLowerCase()];
      if (!file) return;
      const g = h('span', 'sec-glyph');
      hd.insertBefore(g, hd.firstChild);
      injectSvg(g, file);
    });
    // engraved specimen plate leading the reading surface
    const fig = h('figure', 'plate');
    fig.innerHTML =
      `<div class="plate-frame"></div>
       <figcaption class="plate-cap">Plate I &mdash; morphologies of growth: phyllotaxis, frond, germination</figcaption>`;
    col.insertBefore(fig, col.firstChild);
    injectSvg(fig.querySelector('.plate-frame'), 'hero-plate');
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
  const KIND_LABEL = { post: 'Post', talk: 'Talk', page: 'Page', section: '§' };
  function buildSearchIndex(article) {
    searchEntries = SITE.map(p => ({ label: p.t, desc: p.d || '', href: p.href, kind: p.kind, tag: p.tag || '' }))
      .concat(Array.from(article.querySelectorAll('h2, h3'))
        .filter(hd => hd.id && hd.textContent.trim())
        .map(hd => ({ label: hd.textContent.trim(), desc: 'on this page', href: '#' + hd.id, kind: 'section', tag: '' })));
  }
  function esc(s) { return String(s).replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c])); }
  function isExternal(href) { return /^https?:\/\//.test(href) && !href.includes(location.host); }
  // fetch every post's body text once so search can look inside them
  function loadPostContent(onEach) {
    if (contentLoading) return;
    contentLoading = true;
    SITE.filter(e => e.kind === 'post').forEach(p => {
      const urls = /\.html?$/.test(p.href) ? [p.href] : [p.href, p.href.replace(/\/+$/, '') + '.html'];
      (function go(i) {
        if (i >= urls.length) return;
        fetch(urls[i]).then(r => r.ok ? r.text() : Promise.reject()).then(html => {
          const doc = new DOMParser().parseFromString(html, 'text/html');
          contentIndex[p.href] = (doc.body.textContent || '').replace(/\s+/g, ' ').trim();
          onEach && onEach();
        }).catch(() => go(i + 1));
      })(0);
    });
  }
  function reEsc(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
  function hl(text, q) {
    q = q.trim();
    if (!q) return esc(text);
    return text.split(new RegExp('(' + reEsc(q) + ')', 'gi'))
      .map((part, i) => i % 2 ? '<mark>' + esc(part) + '</mark>' : esc(part)).join('');
  }
  function snippet(text, q) {
    const i = text.toLowerCase().indexOf(q.trim().toLowerCase());
    if (i < 0) return text.slice(0, 140);
    const a = Math.max(0, i - 48), b = Math.min(text.length, i + q.length + 90);
    return (a > 0 ? '… ' : '') + text.slice(a, b).trim() + (b < text.length ? ' …' : '');
  }

  function openSearch() {
    let ov = document.getElementById('site-search');
    if (ov) { ov.classList.add('open'); document.documentElement.classList.add('search-open'); ov.querySelector('input').focus(); return; }
    ov = h('div', 'search-overlay', `
      <div class="so-box">
        <div class="so-head">${ICON.search}<input type="text" placeholder="Search everything — inside posts, talks, pages…" autocomplete="off" spellcheck="false"></div>
        <ul class="so-results"></ul>
        <div class="so-foot"><span><kbd>↑</kbd><kbd>↓</kbd> navigate</span><span><kbd>↵</kbd> open</span><span><kbd>esc</kbd> close</span></div>
      </div>`);
    ov.id = 'site-search';
    document.body.appendChild(ov);
    const input = ov.querySelector('input');
    const results = ov.querySelector('.so-results');
    let sel = 0;

    function rank(q) {
      const ql = q.trim().toLowerCase();
      if (!ql) return searchEntries.filter(e => e.kind === 'post' || e.kind === 'talk').map(e => ({ ...e }));
      const out = [], seen = new Set();
      for (const e of searchEntries) {
        const t = e.label.toLowerCase(), d = e.desc.toLowerCase(), tag = e.tag.toLowerCase();
        let s = -1;
        if (t.startsWith(ql)) s = 0;
        else if (t.includes(ql)) s = 1;
        else if (tag && tag.includes(ql)) s = 2;
        else if (d.includes(ql)) s = 3;
        if (s >= 0) { out.push({ s, e: { ...e } }); if (e.href) seen.add(e.href); }
      }
      // full-text: posts whose body contains the query (and weren't already matched)
      for (const p of SITE) {
        if (p.kind !== 'post' || seen.has(p.href)) continue;
        const txt = contentIndex[p.href];
        if (txt && txt.toLowerCase().includes(ql)) {
          out.push({ s: 4, e: { label: p.t, desc: '', href: p.href, kind: 'post', tag: p.tag || '', snip: snippet(txt, q) } });
          seen.add(p.href);
        }
      }
      return out.sort((a, b) => a.s - b.s).map(x => x.e);
    }
    function render(q) {
      const hits = rank(q).slice(0, 18);
      sel = 0;
      results.innerHTML = hits.map((e, i) => {
        const href = e.snip ? e.href + '#:~:text=' + encodeURIComponent(q.trim()) : e.href;
        const line = e.snip ? hl(e.snip, q) : (e.desc ? hl(e.desc, q) : '');
        return `
        <li class="${i === 0 ? 'sel' : ''}" data-href="${esc(href)}">
          <span class="so-kind so-k-${e.kind}">${KIND_LABEL[e.kind] || e.kind}</span>
          <span class="so-text"><span class="so-title">${hl(e.label, q)}</span>${line ? `<span class="so-desc${e.snip ? ' so-snip' : ''}">${line}</span>` : ''}</span>
          <span class="so-go">${isExternal(e.href) ? '↗' : '↵'}</span>
        </li>`;
      }).join('') || (contentLoading && q.trim() ? '<li class="so-empty">Searching inside posts…</li>' : '<li class="so-empty">No matches — try a topic, title, or keyword.</li>');
      results.querySelectorAll('li[data-href]').forEach((li, i) => {
        li.onmousemove = () => { if (sel === i) return; results.querySelectorAll('li').forEach(x => x.classList.remove('sel')); li.classList.add('sel'); sel = i; };
        li.onclick = () => go(li.dataset.href);
      });
    }
    function go(href) {
      if (href[0] === '#') { close(); location.hash = href; }
      else if (isExternal(href)) { window.open(href, '_blank', 'noopener'); close(); }
      else { location.href = href; }
    }
    function close() { ov.classList.remove('open'); document.documentElement.classList.remove('search-open'); }
    input.oninput = () => render(input.value);
    input.onkeydown = (e) => {
      const items = [...results.querySelectorAll('li[data-href]')];
      if (e.key === 'ArrowDown') { sel = Math.min(sel + 1, items.length - 1); e.preventDefault(); }
      else if (e.key === 'ArrowUp') { sel = Math.max(sel - 1, 0); e.preventDefault(); }
      else if (e.key === 'Enter') { if (items[sel]) go(items[sel].dataset.href); return; }
      else if (e.key === 'Escape') { close(); return; }
      else return;
      items.forEach((x, i) => x.classList.toggle('sel', i === sel));
      if (items[sel]) items[sel].scrollIntoView({ block: 'nearest' });
    };
    ov.onclick = (e) => { if (e.target === ov) close(); };
    render('');
    ov.classList.add('open');
    document.documentElement.classList.add('search-open');
    input.focus();
    // pull in post bodies, then refresh results so in-post matches appear
    loadPostContent(() => { if (ov.classList.contains('open')) render(input.value); });
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
    if (!a || a.closest('.topnav, .search-overlay, .entry')) return;
    const kind = classify(a.getAttribute('href'));
    if (!kind) return;
    clearTimeout(hideTimer); curLink = a; clearTimeout(showTimer);
    showTimer = setTimeout(() => show(a, kind), kind === 'internal' ? 130 : 220);
  });
  document.addEventListener('mouseout', e => { if (e.target.closest('a')) { clearTimeout(showTimer); hide(); } });
})();
