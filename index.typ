#import "./shim/html.typ": *

#set document(
  title: "Divy Srivastava",
  description: "divy srivastava. software engineer at deno.",
)

#show: html-shim

#nav-bar()

#title()

i work at #link("https://deno.com")[Deno]. most of my work is around systems engineering and AI research.

these days the work runs more like a small lab than a personal blog. there are a lot of experiments, a fleet of agents, and notes from both.

i get nerd-sniped easily. If something here caught you, or you just want to talk. email me at #link("mailto:me@littledivy.com")[me\@littledivy.com] or #link("https://x.com/littledivy")[x]

#let picture(src, alt, caption, width) = html.elem("figure", {
  html.elem("img", attrs: (src: src, alt: alt, loading: "lazy", width: width))
  html.elem("figcaption", caption)
})

#html.elem("div", attrs: (class: "image-row"), {
  picture("/static/img/newpfpf.png", "shin-chan in a crowd", [me], "256")
  picture("/static/img/elevator.png", "deno team in an elevator", [deno team], "256")
  picture("/static/img/cube.jpg", "cube houses in rotterdam", [rotterdam], "256")
})

#let row(href, title, date: none) = html.elem(
  "li",
  attrs: if date != none { ("data-date": date) } else { (:) },
  html.elem("a", attrs: (href: href), title),
)

== notable work:

#let project(href, title, description) = html.elem("li", [
  #html.elem("a", attrs: (href: href), title). #description
])

#html.elem("ol", attrs: (class: "idx-list"), {
  project("https://github.com/denoland/deno", [Deno], [Runtime work across FFI, compilation, permissions, and native tooling.])
  project("https://github.com/littledivy/laufey", [laufey], [A cross-platform desktop application framework with native windows, webview and Chromium backends. Powers Deno Desktop.])
  project("https://github.com/littledivy/v8x", [v8x], [Author of a drop-in V8 ABI compatibility layer that runs deno_core unchanged on JavaScriptCore and QuickJS.])
  project("https://github.com/denoland/clawpatrol", [Clawpatrol], [A gateway firewall that inspects agent tool traffic and enforces policy before execution.])
  project("https://github.com/denoland/sui", [Sui], [Injects immutable payloads into ELF, PE, and Mach-O executables and powers deno compile.])
  project("/turbocall", [Turbocall], [Generates V8 FFI call stubs at runtime without general-purpose libffi dispatch.])
  project("https://www.youtube.com/watch?v=vINOqgn_ik8", [op2], [Author of Deno's Rust-to-JavaScript binding generator, including generated type conversions and V8 fast-call paths.])
})

== posts:

#html.elem("ol", attrs: (class: "idx-list"), {
  row("/clawpatrol", [A security firewall for AI agents], date: "21.05.2026")
  row("/resym", [Remote stack-trace symbolication], date: "16.02.2025")
  row("/sh-deno", [Seatbelt sandboxing Deno's runtime], date: "07.02.2025")
  row("/sui", [Embedding data into prebuilt binaries], date: "17.08.2024")
  row("/turbocall", [Turbocall: a JIT for V8 FFI trampolines], date: "25.03.2024")
})

== talks:

#html.elem("ol", attrs: (class: "idx-list"), {
  row("https://www.youtube.com/watch?v=vINOqgn_ik8", [Deno internals: the op2 driver], date: "Dublin")
  row("https://www.youtube.com/watch?v=gA152Hun8cI", [WebGPU windowing with surface APIs], date: "Warsaw")
  row("https://www.youtube.com/watch?v=RKjVcl62J9w", [Building cross-platform games with Deno FFI], date: "-")
  row("https://www.youtube.com/watch?v=5wlZDw942J8", [Injecting read-only data into binaries], date: "Warsaw")
  row("https://youtu.be/qt3-3FkPqQ8?t=450", [Kernel to runtime: how JS calls become syscalls], date: "IITK")
  row("https://www.youtube.com/watch?v=ssYN4rFWRIU", [A JIT compiler for dynamic FFI], date: "Tokyo")
})
