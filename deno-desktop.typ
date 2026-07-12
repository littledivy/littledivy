#import "./shim/html.typ": *

#set document(
  title: "What's next with Deno Desktop",
  date: datetime(day: 9, month: 7, year: 2026),
  description: "Native UI on mobile, and shrinking the runtime, in Deno Desktop.",
)

#show: html-shim

#nav-bar()

#title()
#byline()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

#let a(href, body) = html.elem("a", attrs: (href: href), body)

Deno Desktop runs a `deno` process that opens a window, loads HTML, and calls
native code. Today the UI is a webview. That works, and it's most of what ships,
but the UI is still web content and the runtime it ships is 66M. Two things are
next. The UI can render real OS widgets instead of HTML. And the runtime can get
smaller.#sidenote[The window, the engine, and the C ABI come from
#a("https://github.com/littledivy/laufey", [laufey]). Most of it was written by
Claude; I supplied direction and reviewed.]

= Native UI

The straightforward way to render a native button is to ask the OS for one. A real
`NSButton` only exists on macOS. A real UIKit button only exists on iOS. Neither is
available on Linux, where you'd want a preview. So you get real widgets and no
cross-platform story, or a cross-platform story and fake widgets. Deno Desktop does
both, behind one protocol. The approach follows
#a("https://github.com/vercel-labs/native", [vercel-labs/native]).

React emits a retained-mode description of the UI. It's a small protocol,
`intent-protocol-v1`, with four ops.

```
create {id, kind, props}
insert {parent, id, index}
remove {id}
props  {id, props}      // just the changed props; ids are stable
```

Ids are stable `Int32`, so `props` is a diff. An idle frame is an empty batch.
Nothing re-sends the whole tree sixty times a second to move one label. The ops
cross the C ABI as the existing `laufey_value_t`, so the React path skips JSON. One
op stream feeds two hosts.

```
   React reconciler ──► intent-protocol-v1 ops ─┬─► SIM host    (self-drawn, themed)
                                                └─► NATIVE host  (real OS widgets)
```

The SIM host draws every pixel itself, in Rust. It imitates each platform on
purpose. SF Pro and UIKit metrics for iOS, Roboto and Material for Android. It runs
anywhere, which is the point. It'll draw the iOS look on a Linux box that has never
met an iPhone, and it's deterministic, so a pixel-diff test can gate on it.

The NATIVE host maps the same ops to the real widget, AOT-compiled into the app.
AppKit works today. It builds and updates live `NSStackView`, `NSButton`,
`NSTextField`, `NSSwitch`, `NSSlider`, `NSPopUpButton`, `NSSegmentedControl`,
`NSScrollView`, and `NSTabView` through objc2. A `react-reconciler` turns ordinary
TSX into op batches. The loop stays in one process:

```
click → NSButton target-action → React setState → re-render
      → prop-diff op batch → NSView update
```

A calculator, a todo list, a tip calculator, and a settings panel run this way on
macOS. Real AppKit controls, React state, no webview.

Mobile is where the work is. laufey already has an iOS backend. iOS doesn't allow
`dlopen`-ing a runtime dylib, so the backend and runtime collapse into one
statically-linked, signed binary on UIKit and WKWebView. It builds, signs, and runs
on a real iPhone today. Still as a webview, though. The native host on mobile needs
a few more pieces: the in-process `ui_apply` call the ABI already sketches, the ops
mapped to UIKit instead of AppKit, iOS and Android themes for the SIM host, and
touch. `NSTableView` virtualization, `NSAlert`, nav bars, and grid are still owed on
the desktop host too.

= The engine

Deno Desktop is supposed to be smaller than Electron. On the webview backend it
isn't, yet. Here it is next to
#a("https://github.com/blackboardsh/electrobun", [electrobun]), which ships the same
idea with Bun. The number that matters is the LZMA download, since both ship a
compressed self-extracting artifact.

```
App                        runtime + engine    on disk   LZMA download
─────────────────────────  ──────────────────  ───────   ─────────────
electrobun (webview)       Bun + WKWebView       61M        14.2M
Deno Desktop (webview)     denort + WKWebView    66M        19.5M
Deno Desktop (CEF)         denort + Chromium    297M        92.8M
electrobun (CEF)           Bun + Chromium       357M        ~93M
```

On CEF, Deno Desktop is 60M smaller. That's mostly because Deno ships the CEF
minimal distribution and electrobun doesn't, so it isn't quite like-for-like. On
webview it's 5M larger. That gap is the runtime. The laufey webview backend is
~300K, small enough to ignore. `denort` is 66M to Bun's 58M, and most of that isn't
code.

Of the stripped 66M, about 43M is V8-and-Deno machine code. About 21M is the V8
snapshot plus a full ~10M of embedded ICU. ICU is locale data for full
internationalization, which a webview app usually doesn't need. Building `denort`
against the system or a small ICU takes that ~10M off raw, 3–4M off the compressed
download. That should bring the webview build roughly in line with electrobun,
before any other trimming.#sidenote[Bun uses JavaScriptCore, which is structurally
smaller than V8. Matching it looks realistic; beating it means also cutting ops and
node-compat a webview app never calls.]

= C ABI

All of this runs over one header, `laufey.h`. `laufey_backend_api_t` is a struct of
function pointers. An opaque `backend_data` is passed first to every call. It's a
hand-written vtable. It carries a version, so a runtime can refuse a backend it
doesn't understand (`LAUFEY_API_VERSION`, currently `31`).

```rust
use laufey::{Value, Window};

fn main() {
    Window::new(800, 600)
        .title("My App")
        .bind("greet", |call| {
            let name = call.args.first()
                .and_then(|v| v.as_string())
                .unwrap_or("World");
            call.resolve(Value::String(format!("Hello, {name}!")));
        })
        .load("index.html");
}

laufey::main!(main);
```

Native UI adds a `ui_apply(window, ops)` call and a `set_ui_event_handler` to the
struct. The engine work happens below the ABI, in how `denort` is built. The runtime
you write doesn't notice either one.

#a("https://github.com/littledivy/laufey", [github.com/littledivy/laufey]).
