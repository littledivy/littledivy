/* littledivy.com — Roam Research look (roam-css-system LessWrong theme).
 * Builds the three-pane Roam shell around the Typst-generated content. */

(function () {
  document.documentElement.setAttribute('data-theme', localStorage.getItem('theme') || 'light');
  // hide until the shell is built (avoids a flash of raw content)
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
  function slug(s) {
    return s.toLowerCase().trim().replace(/[^\w]+/g, '-').replace(/^-+|-+$/g, '');
  }
  function h(tag, cls, html) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  }

  // tiny line-icon set (Blueprint-ish)
  const ICON = {
    chevron: '<svg viewBox="0 0 16 16" width="12" height="12"><path d="M4 6l4 4 4-4" fill="none" stroke="currentColor" stroke-width="1.6"/></svg>',
    calendar: '<svg viewBox="0 0 16 16" width="15" height="15"><rect x="2" y="3" width="12" height="11" rx="1.5" fill="none" stroke="currentColor" stroke-width="1.3"/><path d="M2 6h12M5 2v3M11 2v3" stroke="currentColor" stroke-width="1.3"/></svg>',
    graph: '<svg viewBox="0 0 16 16" width="15" height="15"><circle cx="3.5" cy="12" r="1.8" fill="none" stroke="currentColor" stroke-width="1.2"/><circle cx="12.5" cy="11" r="1.6" fill="none" stroke="currentColor" stroke-width="1.2"/><circle cx="8" cy="3.5" r="1.8" fill="none" stroke="currentColor" stroke-width="1.2"/><path d="M5 11l2-6M9.5 4.5l2.3 5" stroke="currentColor" stroke-width="1.1"/></svg>',
    pages: '<svg viewBox="0 0 16 16" width="15" height="15"><path d="M3 3h10M3 7h10M3 11h7" stroke="currentColor" stroke-width="1.4"/></svg>',
    search: '<svg viewBox="0 0 16 16" width="15" height="15"><circle cx="7" cy="7" r="4.2" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M10.3 10.3L14 14" stroke="currentColor" stroke-width="1.4"/></svg>',
    arrowL: '<svg viewBox="0 0 16 16" width="16" height="16"><path d="M10 3L5 8l5 5" fill="none" stroke="currentColor" stroke-width="1.6"/></svg>',
    arrowR: '<svg viewBox="0 0 16 16" width="16" height="16"><path d="M6 3l5 5-5 5" fill="none" stroke="currentColor" stroke-width="1.6"/></svg>',
    filter: '<svg viewBox="0 0 16 16" width="15" height="15"><path d="M2 4h12L9.5 9v4l-3 1.5V9z" fill="none" stroke="currentColor" stroke-width="1.2"/></svg>',
    more: '<svg viewBox="0 0 16 16" width="15" height="15"><circle cx="3" cy="8" r="1.3"/><circle cx="8" cy="8" r="1.3"/><circle cx="13" cy="8" r="1.3"/></svg>',
    columns: '<svg viewBox="0 0 16 16" width="15" height="15"><rect x="2" y="3" width="12" height="10" rx="1" fill="none" stroke="currentColor" stroke-width="1.2"/><path d="M9 3v10" stroke="currentColor" stroke-width="1.2"/></svg>',
    help: '<svg viewBox="0 0 16 16" width="15" height="15"><circle cx="8" cy="8" r="6" fill="none" stroke="currentColor" stroke-width="1.2"/><path d="M6.3 6.2a1.8 1.8 0 113 1.3c-.8.6-1.3.9-1.3 1.8" fill="none" stroke="currentColor" stroke-width="1.2"/><circle cx="8" cy="11.4" r=".7"/></svg>',
    close: '<svg viewBox="0 0 16 16" width="13" height="13"><path d="M4 4l8 8M12 4l-8 8" stroke="currentColor" stroke-width="1.4"/></svg>',
    tri: '<svg viewBox="0 0 16 16" width="9" height="9"><path d="M5 3l6 5-6 5z" fill="currentColor"/></svg>',
    collapse: '<svg viewBox="0 0 16 16" width="14" height="14"><path d="M2 5h12M2 9h12M5 2l3 3 3-3M5 14l3-3 3 3" fill="none" stroke="currentColor" stroke-width="1.2"/></svg>',
    pin: '<svg viewBox="0 0 16 16" width="13" height="13"><path d="M6 2h4l-.7 4 2.2 2.2-3.2.3L8 14l-.5-5.2-3.2-.3L6.5 6z" fill="none" stroke="currentColor" stroke-width="1.1"/></svg>',
    sun: '☀',
    moon: '☾',
  };

  // Shortcuts shown in the left sidebar (mirrors a Roam "SHORTCUTS" list).
  const SHORTCUTS = [
    { t: 'Remote stack symbolication', href: '/resym' },
    { t: 'sh-deno', href: '/sh-deno' },
    { t: 'Turbocall', href: '/turbocall' },
    { t: 'Sui', href: '/sui' },
    { t: 'luv', href: '/luv' },
    { t: 'jpeg-encoder', href: '/jpeg-encoder' },
  ];

  function reveal() {
    requestAnimationFrame(() => {
      const b = document.getElementById('boot-hide');
      if (b) b.remove();
    });
  }

  function buildLeftSidebar() {
    const aside = h('aside', 'roam-left');
    aside.innerHTML = `
      <div class="rl-top">
        <span class="rl-ws">littledivy</span>
        <span class="rl-ws-chev">${ICON.chevron}</span>
      </div>
      <nav class="rl-nav">
        <a href="/"><span class="rl-ico">${ICON.calendar}</span>Home</a>
        <a href="https://github.com/littledivy?tab=repositories"><span class="rl-ico">${ICON.graph}</span>Projects</a>
        <a href="/#all"><span class="rl-ico">${ICON.pages}</span>All Pages</a>
      </nav>
      <div class="rl-shortcuts-h">★ &nbsp;SHORTCUTS</div>
      <ul class="rl-shortcuts">
        ${SHORTCUTS.map(s => `<li><a href="${s.href}">${s.t}</a></li>`).join('')}
      </ul>
      <div class="rl-logo">
        <span class="rl-logo-mark"></span><span class="rl-logo-text">littledivy</span>
      </div>`;
    return aside;
  }

  function buildTopbar(hasOutline) {
    const bar = h('div', 'roam-topbar');
    bar.innerHTML = `
      <div class="tb-left">
        <a class="tb-brand" href="/">littledivy</a>
        <button class="tb-ico" id="tb-back" aria-label="Back">${ICON.arrowL}</button>
        <button class="tb-ico" id="tb-fwd" aria-label="Forward">${ICON.arrowR}</button>
      </div>
      <button class="tb-search" id="tb-search">
        <span class="tb-dot"></span>
        <span class="tb-search-ico">${ICON.search}</span>
        <span class="tb-search-ph">Search&nbsp;&nbsp;<kbd>/</kbd></span>
      </button>
      <div class="tb-right">
        ${hasOutline ? `<button class="tb-ico" id="tb-cols" aria-label="Toggle outline">${ICON.columns}</button>` : ''}
        <button class="tb-ico tb-theme" id="tb-theme" aria-label="Toggle theme">${ICON.moon}</button>
      </div>`;
    bar.querySelector('#tb-back').onclick = () => history.back();
    bar.querySelector('#tb-fwd').onclick = () => history.forward();
    bar.querySelector('#tb-theme').onclick = toggleTheme;
    bar.querySelector('#tb-search').onclick = openSearch;
    const cols = bar.querySelector('#tb-cols');
    if (cols) cols.onclick = () => document.body.classList.toggle('hide-right');
    return bar;
  }

  /* real "Find or Create Page" search — fuzzy over shortcut pages + this page's headings */
  let searchEntries = [];
  function openSearch() {
    let ov = document.getElementById('roam-search');
    if (ov) { ov.classList.add('open'); ov.querySelector('input').focus(); return; }
    ov = h('div', 'roam-search', `
      <div class="rs-box">
        <input type="text" placeholder="Search posts & sections…" autocomplete="off">
        <ul class="rs-results"></ul>
      </div>`);
    ov.id = 'roam-search';
    document.body.appendChild(ov);
    const input = ov.querySelector('input');
    const results = ov.querySelector('.rs-results');
    let sel = 0;
    function render(q) {
      const ql = q.toLowerCase();
      const hits = searchEntries.filter(e => e.label.toLowerCase().includes(ql)).slice(0, 12);
      sel = 0;
      results.innerHTML = hits.map((e, i) =>
        `<li class="${i === 0 ? 'sel' : ''}" data-href="${e.href}"><span class="rs-kind">${e.kind}</span>${e.label}</li>`).join('')
        || '<li class="rs-empty">no matches</li>';
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

  function buildOutline(title, heads, meta) {
    meta = meta || {};
    const aside = h('aside', 'roam-right');
    const dateBit = meta.date ? `<span class="rr-meta-sep">·</span><span>${meta.date.trim()}</span>` : '';
    aside.innerHTML = `
      <div class="rr-window">
        <div class="rr-window-title">${title}</div>
        <div class="rr-meta">
          <span>${meta.minutes || 1} min read</span>
          <span class="rr-meta-sep">·</span>
          <span>${(meta.words || 0).toLocaleString()} words</span>
          ${dateBit}
        </div>
      </div>
      <div class="rr-head">
        <span class="rr-title">On this page</span>
        <span class="rr-count">${heads.length}</span>
        <button class="rr-ico rr-collapse" aria-label="Collapse all" title="Collapse all">${ICON.collapse}</button>
        <button class="rr-ico rr-close" aria-label="Hide outline" title="Hide outline">${ICON.close}</button>
      </div>
      <div class="rr-progress"><span></span></div>`;

    // nested tree by heading level (h2 > h3 > h4)
    const tree = h('ul', 'rr-tree');
    const stack = [{ level: 1, ul: tree }];
    heads.forEach(hd => {
      if (!hd.id) hd.id = slug(hd.textContent);
      const lvl = +hd.tagName[1];
      while (stack.length > 1 && stack[stack.length - 1].level >= lvl) stack.pop();
      const li = h('li', 'rr-node');
      li.dataset.anchor = hd.id;
      li.dataset.level = lvl;
      li.innerHTML = `
        <div class="rr-row">
          <button class="rr-tw" tabindex="-1">${ICON.tri}</button>
          <span class="rr-dot"></span>
          <a href="#${hd.id}">${hd.textContent}</a>
        </div>
        <ul class="rr-children"></ul>`;
      stack[stack.length - 1].ul.appendChild(li);
      stack.push({ level: lvl, ul: li.querySelector('.rr-children') });
    });
    aside.appendChild(tree);

    tree.querySelectorAll('.rr-node').forEach(li => {
      if (!li.querySelector('.rr-children').children.length) li.classList.add('rr-leaf');
      li.querySelector('.rr-tw').onclick = (e) => {
        e.preventDefault(); e.stopPropagation();
        li.classList.toggle('collapsed');
      };
    });
    aside.querySelector('.rr-close').onclick = () => document.body.classList.add('hide-right');
    aside.querySelector('.rr-collapse').onclick = () => {
      const expand = !tree.querySelector('.rr-node:not(.rr-leaf):not(.collapsed)');
      tree.querySelectorAll('.rr-node:not(.rr-leaf)').forEach(li => li.classList.toggle('collapsed', !expand));
    };

    // notes section (populated by renderStaticNotes)
    const notes = h('div', 'rr-notes-section');
    notes.innerHTML = `
      <div class="rr-head"><span class="rr-title">Notes</span><span class="rr-count rr-notes-count">0</span></div>
      <ul class="rr-notes"><li class="rr-notes-empty">Select text in the post to leave one.</li></ul>`;
    aside.appendChild(notes);
    return aside;
  }

  function bodyKids() {
    return Array.from(document.body.children)
      .filter(n => n.tagName !== 'SCRIPT' && !(n.classList && n.classList.contains('style-switch')));
  }

  function build() {
    buildRoamShell();
    reveal();
  }

  function buildRoamShell() {
    const body = document.body;
    const kids = bodyKids();
    const origNav = kids.find(n => n.tagName === 'NAV');
    const content = kids.filter(n => n !== origNav);
    if (origNav) origNav.remove();

    const titleEl = content.find(n => n.tagName === 'H1');
    const pageTitle = titleEl ? titleEl.textContent : document.title;
    const heads = content.flatMap(n =>
      /^H[234]$/.test(n.tagName) ? [n] :
      Array.from(n.querySelectorAll ? n.querySelectorAll('h2,h3,h4') : []));
    const hasOutline = heads.length >= 2;

    heads.forEach(hd => { if (!hd.id) hd.id = slug(hd.textContent); });
    searchEntries = SHORTCUTS.map(s => ({ label: s.t, href: s.href, kind: 'page' }))
      .concat(heads.map(hd => ({ label: hd.textContent, href: '#' + hd.id, kind: '§' })));

    const article = h('div', 'roam-article');
    content.forEach(c => article.appendChild(c));

    const main = h('main', 'roam-main' + (hasOutline ? '' : ' no-right'));
    main.appendChild(buildTopbar(hasOutline));
    main.appendChild(article);

    body.appendChild(main);
    const words = (article.textContent.trim().match(/\S+/g) || []).length;
    const meta = {
      words,
      minutes: Math.max(1, Math.round(words / 220)),
      date: (article.querySelector('.byline') || {}).textContent || '',
    };
    if (hasOutline) body.appendChild(buildOutline(pageTitle, heads, meta));

    // keyboard: "/" opens search
    document.addEventListener('keydown', e => {
      if (e.key === '/' && !/INPUT|TEXTAREA/.test(document.activeElement.tagName)) {
        e.preventDefault(); openSearch();
      }
    });

    enhanceBlocks(article);
    renderStaticNotes(article);
    body.classList.add('roam');
    if (hasOutline) setupScrollSpy(heads, body.querySelector('.roam-right'));
  }

  // add component variety: language badges on code, mark diagrams, lead para
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
    // first real paragraph (not the byline) becomes the lead
    const firstP = article.querySelector('h1 ~ p:not(.byline)');
    if (firstP) firstP.classList.add('lead');
  }

  /* ---- authored notes: number the inline cards + index them in the sidebar ---- */
  function renderStaticNotes(article) {
    const cards = Array.from(article.querySelectorAll('.note-card'));
    const list = document.querySelector('.rr-notes');
    const count = document.querySelector('.rr-notes-count');
    if (count) count.textContent = cards.length;
    cards.forEach((card, i) => {
      const n = i + 1;
      if (!card.id) card.id = 'note-' + n;
      card.dataset.n = n;
    });
    if (!list) return;
    list.innerHTML = '';
    if (!cards.length) {
      list.appendChild(h('li', 'rr-notes-empty', 'No notes in this post.'));
      return;
    }
    cards.forEach((card) => {
      const li = h('li', 'rr-note');
      const t = h('div', 'rr-note-text'); t.textContent = card.textContent.trim();
      li.appendChild(t);
      li.onclick = () => {
        card.scrollIntoView({ block: 'center', behavior: 'smooth' });
        card.classList.add('flash'); setTimeout(() => card.classList.remove('flash'), 1100);
      };
      list.appendChild(li);
    });
  }


  function setupScrollSpy(heads, rightEl) {
    const items = heads.map(hd => ({ hd, li: rightEl.querySelector(`.rr-node[data-anchor="${hd.id}"]`) })).filter(x => x.li);
    const prog = rightEl.querySelector('.rr-progress span');
    let raf = 0;
    function update() {
      raf = 0;
      const mark = window.innerHeight / 5;
      let cur = items[0];
      for (const it of items) {
        if (it.hd.getBoundingClientRect().top - mark < 0) cur = it; else break;
      }
      items.forEach(it => it.li.classList.toggle('active', it === cur));
      // mark the ancestor chain of the active node
      items.forEach(it => it.li.classList.remove('on-path'));
      if (cur) { let p = cur.li.parentElement.closest('.rr-node'); while (p) { p.classList.add('on-path'); p = p.parentElement.closest('.rr-node'); } }
      if (prog) {
        const max = document.documentElement.scrollHeight - window.innerHeight;
        prog.style.width = (max > 0 ? Math.min(1, window.scrollY / max) * 100 : 0) + '%';
      }
    }
    window.addEventListener('scroll', () => { if (!raf) raf = requestAnimationFrame(update); }, { passive: true });
    update();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', build);
  } else {
    build();
  }
})();

/* ---- KaTeX math (lazy-loaded, self-hosted) ---- */
(function () {
  function renderAll() {
    const els = document.querySelectorAll('.math-tex:not(.math-done)');
    els.forEach(el => {
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
    css.rel = 'stylesheet';
    css.href = '/katex/katex.min.css';
    document.head.appendChild(css);
    const js = document.createElement('script');
    js.src = '/katex/katex.min.js';
    js.onload = renderAll;
    document.head.appendChild(js);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();

/* ---- image lightbox ---- */
(function () {
  document.addEventListener('click', e => {
    const img = e.target.closest('.roam-article img, .page img');
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

/* ---- link hover previews (internal posts + external sites / YouTube) ---- */
// Self-hosted og scraper (workers/og-preview). Set to your deployed Worker URL,
// or '/og' if you route it on this domain. Until set, external previews
// gracefully fall back to favicon + domain.
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
      const paras = Array.from(doc.querySelectorAll('body > p, main > p'))
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
        kind: 'external',
        title: d.title || host(href),
        desc: clip(d.description, 40),
        image: d.image || '',
        logo: d.logo || fav,
        domain: d.domain || host(href),
      })).catch(() => ({
        kind: 'external', title: host(href), desc: '', logo: fav, domain: host(href),
      }));
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
      im.onerror = () => im.remove();
      c.appendChild(im);
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
      // instant skeleton (favicon + domain) so the card never feels stuck
      const hn = host(a.href);
      render(c, { kind: 'external', domain: hn, title: hn, desc: '',
        logo: 'https://www.google.com/s2/favicons?domain=' + hn + '&sz=64' });
      place(c, a); c.classList.add('visible');
    }
    load(a.href, kind).then(d => {
      if (!d || curLink !== a) return;
      render(c, d);
      place(c, a);
      c.classList.add('visible');
    });
  }
  function hide() { hideTimer = setTimeout(() => { if (card) card.classList.remove('visible'); curLink = null; }, 180); }
  document.addEventListener('mouseover', e => {
    const a = e.target.closest('a');
    if (!a || a.closest('.roam-left, .roam-right, .roam-topbar, .style-switch')) return;
    const kind = classify(a.getAttribute('href'));
    if (!kind) return;
    clearTimeout(hideTimer); curLink = a; clearTimeout(showTimer);
    showTimer = setTimeout(() => show(a, kind), kind === 'internal' ? 130 : 220);
  });
  document.addEventListener('mouseout', e => { if (e.target.closest('a')) { clearTimeout(showTimer); hide(); } });
})();
