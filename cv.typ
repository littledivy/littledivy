#set document(
  title: "Divy Srivastava: CV",
  author: "Divy Srivastava",
)

#set page(
  paper: "us-letter",
  margin: (top: 1.7in, bottom: 0.55in, left: 0.75in, right: 1.5in),
  numbering: "1",
  number-align: center + bottom,
)

#set text(
  font: "Linux Libertine",
  size: 10pt,
  fill: black,
)
#set par(leading: 0.55em, justify: false)
#show link: set text(fill: rgb("0068a8"))

#let section(title) = {
  v(1.05em)
  grid(
    columns: (0.96in, 1fr),
    column-gutter: 0.04in,
    [],
    text(size: 14.4pt, title),
  )
  v(0.65em)
}

#let dated(date, body) = grid(
  columns: (0.92in, 1fr),
  column-gutter: 0.04in,
  align: (left + top, left + top),
  text(font: "New Computer Modern", size: 7pt, date),
  body,
)

#let inset(body) = grid(
  columns: (0.96in, 1fr),
  [],
  body,
)

#let item(body) = {
  inset([#sym.bullet #h(0.35em)#body])
  v(-0.2em)
}

#inset[#text(size: 17.3pt)[Divy Srivastava]]

#v(2.2em)
#inset[
  Software engineer\
  Deno
]

#v(0.6em)
#inset[
  email: #link("mailto:me@littledivy.com")[me\@littledivy.com]\
  url: #link("https://littledivy.com")[https://littledivy.com]\
  github: #link("https://github.com/littledivy")[https://github.com/littledivy]
]

#section[Positions]

#dated[2021-present][Software Engineer, Deno]
#v(0.3em)
#dated[2020-2021][
  Consultant, th8ta\
  Co-founded Verto, a decentralized exchange platform on Arweave.
]

#section[Selected work]

#dated[2026][
  *Deno Desktop.* Author of a desktop application runtime for Deno with native windows, webview and Chromium backends, and React-driven OS widgets.
]
#v(0.3em)
#dated[2026][
  *v8x.* Author of a drop-in V8 ABI compatibility layer that runs `deno_core` unchanged on JavaScriptCore and QuickJS.
]
#v(0.3em)
#dated[2026][
  *Clawpatrol.* A gateway firewall that inspects agent tool traffic and enforces policy before execution.
]
#v(0.3em)
#dated[2024][
  *Sui.* Injects immutable payloads into ELF, PE, and Mach-O executables and powers `deno compile`.
]
#v(0.3em)
#dated[2024][
  *Turbocall.* Generates V8 FFI call stubs at runtime without general-purpose libffi dispatch.
]
#v(0.3em)
#dated[2023][
  *op2.* Author of Deno's Rust-to-JavaScript binding generator, including generated type conversions and V8 fast-call paths.
]

#section[Talks]

#item[#link("https://www.youtube.com/watch?v=vINOqgn_ik8")[Deno internals: the op2 driver].]
#item[#link("https://www.youtube.com/watch?v=gA152Hun8cI")[WebGPU windowing with surface APIs].]
#item[#link("https://www.youtube.com/watch?v=RKjVcl62J9w")[Building cross-platform games with Deno FFI].]
#item[#link("https://www.youtube.com/watch?v=5wlZDw942J8")[Injecting read-only data into binaries].]
#item[#link("https://youtu.be/qt3-3FkPqQ8?t=450")[Kernel to runtime: how JavaScript calls become syscalls].]
#item[#link("https://www.youtube.com/watch?v=ssYN4rFWRIU")[A JIT compiler for dynamic FFI].]
