#import "./shim/html.typ": *

#set document(
  title: "littledivy.com",
  description: "Research and engineering",
)

#show: html-shim

#nav-bar()

#title()

#let row(href, title, date: none) = html.elem(
  "li",
  attrs: if date != none { ("data-date": date) } else { (:) },
  html.elem("a", attrs: (href: href), title),
)

== Posts

#html.elem("ul", attrs: (class: "idx-list"), {
  row("/clawpatrol", [A security firewall for AI agents], date: "2026-05-21")
  row("/resym", [Remote stack-trace symbolication], date: "2025-02-16")
  row("/sh-deno", [Seatbelt sandboxing Deno's runtime], date: "2025-02-07")
  row("/sui", [Embedding data into prebuilt binaries], date: "2024-08-17")
  row("/turbocall", [Turbocall: a JIT for V8 FFI trampolines], date: "2024-03-25")
})

== Talks

#html.elem("ul", attrs: (class: "idx-list nodate"), {
  row("https://www.youtube.com/watch?v=vINOqgn_ik8", [Deno internals: the op2 driver])
  row("https://www.youtube.com/watch?v=gA152Hun8cI", [WebGPU windowing with surface APIs])
  row("https://www.youtube.com/watch?v=RKjVcl62J9w", [Building cross-platform games with Deno FFI])
  row("https://www.youtube.com/watch?v=5wlZDw942J8", [Injecting read-only data into binaries])
  row("https://youtu.be/qt3-3FkPqQ8?t=450", [Kernel to runtime: how JS calls become syscalls])
  row("https://www.youtube.com/watch?v=ssYN4rFWRIU", [A JIT compiler for dynamic FFI])
})

