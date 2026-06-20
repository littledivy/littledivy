#import "./shim/html.typ": *

#set document(
  title: "Deno desktop without localhost",
  date: datetime(day: 20, month: 6, year: 2026),
  description: "Replacing loopback TCP with an in-process memory transport for desktop apps.",
)

#show: html-shim

#nav-bar()

#title()
#byline()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

#let a(href, body) = html.elem("a", attrs: (href: href), body)

Most desktop webview apps quietly start a localhost server and point the embedded browser at `http://127.0.0.1:PORT`.

That works, but it is an awkward fit for something running entirely inside one process. You pay for port allocation, loopback sockets, connection setup, and a whole class of "what is listening on localhost right now" questions even though the producer and consumer are already in the same address space.

#a("https://github.com/denoland/deno/pull/35272", [PR #35272]) replaces that path in `deno desktop` with a new `memory:` transport. `Deno.serve` binds an in-memory listener, the desktop runtime points the webview at `app://...`, and a scheme bridge forwards each request over an in-process duplex stream.

#figure(
  image("./static/img/desktop-memory-transport.svg", width: 100%),
)

= The old path

The old desktop flow looked roughly like this:

- pick a free localhost port
- start `Deno.serve` on `127.0.0.1`
- navigate the webview to that address
- proxy bytes through the kernel networking stack even though both endpoints are local

It is not disastrous. It is just more machinery than the problem needs.

= The new transport

The runtime now sets:

```sh
DENO_SERVE_ADDRESS=memory:deno-desktop
```

That goes through the same `Deno.serve` surface, but `ext/http` and `ext/net` now understand a `memory:<name>` address kind. Under the hood, `ext/net/memory.rs` keeps a process-global listener registry and connects client and server sides with `tokio::io::duplex(64 * 1024)`.

On the desktop side, the browser is navigated to `app://...` instead of localhost. The scheme bridge registers an `app` handler through Laufey, opens a `memory:deno-desktop` stream for each request, performs a `hyper` HTTP/1 handshake on top of that stream, forwards method, headers, and body, and streams the response back to the webview.

So the application is still speaking HTTP. It is just not speaking it over TCP anymore.

= Why this shape is nice

The good part of the design is that it does not invent a new app protocol.

User code still writes:

```ts
Deno.serve((_req) => new Response("ok"));
```

The desktop embedder still consumes request/response traffic. All the change is below that line, in the transport and the browser bridge.

That makes the feature more reusable. `memory:` is not only for desktop. It is a generic local transport that can be useful anywhere two components in the same process want stream semantics without sockets.

= The bridge point

The most interesting part is the scheme handler boundary.

Laufey recently added custom URL scheme handling, so the browser engine can hand `app://...` requests back to the host runtime directly. That becomes the exact place where desktop-specific behavior belongs:

- translate browser request into an internal client request
- connect to the in-process listener
- let the server side keep using the normal HTTP stack
- stream the response back without leaving the process

That split keeps `Deno.serve` clean and keeps the browser integration out of user application code.

= Operational details

The memory transport implementation includes the boring cases that usually get missed first:

- duplicate listener names are rejected
- connecting before a listener exists returns an error
- listener names can be reused after drop
- the stream still behaves like backpressured byte I/O, not a one-shot message bus

Those details matter more than the demo path. If a transport only works in the happy case, it is not really part of the runtime yet.

= Notes

A localhost port is convenient because everything already knows how to talk to it. That is also its weakness. Once a system starts leaning on localhost as the universal glue, a lot of design gets inherited by accident.

For an embedded desktop server, a named in-process byte channel is a better default. Same HTTP handler. Less scaffolding.
