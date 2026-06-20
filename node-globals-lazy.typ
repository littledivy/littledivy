#import "./shim/html.typ": *

#set document(
  title: "Keeping node globals out of Deno's startup snapshot",
  date: datetime(day: 20, month: 6, year: 2026),
  description: "How a couple of eager node imports dragged thousands of objects into every Deno startup.",
)

#show: html-shim

#nav-bar()

#title()
#byline()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

#let a(href, body) = html.elem("a", attrs: (href: href), body)

A bootstrap import can quietly become a startup tax.

In Deno, `runtime/js/98_global_scope_shared.js` used to import `node:buffer` and `node:timers` eagerly so `Buffer`, `setTimeout`, `setInterval`, and friends were ready on the global object from the start. That looked harmless. It was not. Those imports pulled their transitive closure into the startup snapshot, including around 22 Node-internal modules and about 700 shared function infos.

The fix was to keep the globals but stop paying for them on every process start. The bootstrap now installs lazy properties backed by `core.createLazyLoader("node:buffer")` and `core.createLazyLoader("node:timers")`, so the module graph stays out of the eager snapshot until something actually touches it.

#a("https://github.com/denoland/deno/pull/35373", [PR #35373]) has the patch.

#figure(
  image("./static/img/node-globals-lazy.svg", width: 100%),
)

= Where the leak came from

The expensive part was not `Buffer` itself. It was where the import lived.

`98_global_scope_shared.js` is evaluated during bootstrap. Any static `import` there gets resolved while building the snapshot. Once `node:buffer` and `node:timers` came in, their dependencies came with them. That meant `deno run empty.js` was paying to deserialize objects for Node compatibility even when the program never touched Node APIs.

This is the sort of thing that slips in easily. The code still looks tidy. The runtime still behaves correctly. The cost only shows up when you inspect the snapshot or profile startup.

= The fix

The patch removes the eager imports and replaces them with lazy loaders:

```js
const lazyBufferMod = core.createLazyLoader("node:buffer");
const lazyTimersMod = core.createLazyLoader("node:timers");
```

Then the globals are installed with lazy property accessors instead of concrete values at bootstrap time:

```js
Buffer: core.propWritableLazyLoaded(
  "Buffer",
  () => lazyBufferMod().Buffer,
),
setTimeout: core.propWritableLazyLoaded(
  "setTimeout",
  () => lazyTimersMod().setTimeout,
),
```

So the API surface stays the same from user code. What changes is when the module graph is paid for.

This is a better place to spend complexity. User programs still get `Buffer` and timers from the global object. Startup just stops front-loading modules that may never be used.

= The one eager exception

There was one thing that could not move out with the rest.

WebCrypto and Node key interop still needed `ext:deno_node/internal/crypto/constants.ts` during eager bootstrap to preserve `internals.kKeyObject` branding. The patch explicitly loads that script with `core.loadExtScript(...)` and leaves the rest of the Node timer and buffer stack lazy.

That split is worth calling out because it kept the change honest. This was not "make everything lazy". It was "make the unnecessary part lazy and keep the part that preserves semantics eager."

= Numbers

The PR measured three useful changes:

- `JsRuntime::new_inner` snapshot deserialization: `4.657 ms -> 3.987 ms` (`-14.4%`)
- `deno run empty.js`: `15.03 ms -> 14.35 ms` (`-4.5%`)
- startup snapshot object count: `26,427 -> 20,425` (`-23%`)
- context snapshot object count: `18,098 -> 12,995` (`-28%`)

The wall-clock delta is not dramatic in isolation, but this is exactly the kind of startup work that compounds. A few accidental imports in bootstrap code and the baseline creeps up for every command.

= Guardrails

The follow-up work matters as much as the patch itself.

#a("https://github.com/denoland/deno/pull/35332", [PR #35332]) adds a build-time guard around consumed lazy modules so the eager snapshot cannot quietly absorb them again. If a `node:*` module leaks back into bootstrap, CI now fails with a message pointing at the snapshot boundary.

That is the real lesson here. Startup improvements need a contract, not just a one-time cleanup.

= Notes

If a runtime has an eager snapshot, bootstrap code is part of your startup ABI. Treat it that way. Static imports there are not just code organization. They decide what every process pays for before user code runs.
