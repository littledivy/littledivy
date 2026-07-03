#import "./shim/html.typ": *

#set document(
  title: "littledivy.com",
  description: "Divy's personal page. Software writeups and more",
)

#show: html-shim

#nav-bar()

#title()

Hello; I'm Divy. I work at the #html.elem("a", attrs: (href: "https://deno.com"), [Deno]) company, building & optimizing the Deno runtime. I maintain various projects related to system tools, compilers, cryptography on #html.elem("a", attrs: (href: "https://github.com/littledivy"), [Github]).

You can reach me at #html.elem("a", attrs: (href: "mailto:me@littledivy.com"), [me\@littledivy.com])

== Posts

#set list(marker: [--])
- #html.elem("a", attrs: (href: "/clawpatrol"), [clawpatrol for personal agents]) — security firewall for AI agents.
- #html.elem("a", attrs: (href: "/resym"), [Remote stack trace symbolication]) — serializable stack trace collection for remote symbolication.
- #html.elem("a", attrs: (href: "/sh-deno"), [sh-deno]) — apple's seatbelt sandboxing combined with deno's permission system for hardened runtime security.
- #html.elem("a", attrs: (href: "/turbocall"), [Turbocall]) — just-in-time compiler for generating trampoines for V8 \<-\> FFI bindings.
- #html.elem("a", attrs: (href: "/sui"), [Sui]) — notes on cross-platform injection arbritrary data into prebuilt binaries.
- #html.elem("a", attrs: (href: "/scroll-physics-math"), [Scroll physics as a fitted model]) — calibrating iOS scroll feel from traces, not guesses.
- #html.elem("a", attrs: (href: "/path-geometry"), [Path geometry and arc-length math]) — flattening, trimming, winding, transforms, and boolean ops.
- #html.elem("a", attrs: (href: "/mesh-gradient-interpolation"), [Mesh gradient interpolation]) — bilinear grids, smoothstep seams, and gamma-space color mixing.
- #html.elem("a", attrs: (href: "/control-springs"), [Control springs and press pulses]) — spring responses for buttons, toggles, sliders, and focus rings.
- #html.elem("a", attrs: (href: "/share-sheet-motion"), [Share sheet motion]) — one-slot modal state and a damped spring that feels like iOS.
- #html.elem("a", attrs: (href: "/liquid-glass"), [Liquid Glass morphing]) — identity, union, and frame morphing for Apple's translucent material.

== Talks

#set list(marker: [--])
- #html.elem("a", attrs: (href: "https://youtu.be/qt3-3FkPqQ8?t=450"), [Kernel to runtime]) — IIT Kanpur OOSC 3, 2025. how javascript calls become syscalls: event loops, epoll, and async i/o.
- #html.elem("a", attrs: (href: "https://www.youtube.com/watch?v=vINOqgn_ik8"), [Deno internals: op2 driver]) — about deno_core internals, runtime call overhead, and js\<-\>rust translation layer.
- #html.elem("a", attrs: (href: "https://www.youtube.com/watch?v=RKjVcl62J9w"), [Building games with deno ffi]) — how to build a cross-platform game using SDL2 in JS.
- #html.elem("a", attrs: (href: "https://www.youtube.com/watch?v=gA152Hun8cI"), [WebGPU windowing]) — about rendering a gpu-accelarated window using webgpu and window surface APIs.
- #html.elem("a", attrs: (href: "https://www.youtube.com/watch?v=5wlZDw942J8"), [Injecting r/o data into binaries]) — cross-platform tool that powers deno's compiler.
- #html.elem("a", attrs: (href: "https://www.youtube.com/watch?v=ssYN4rFWRIU"), [JIT compiler for dynamic FFI]) — _blazing fast_ compiler for generating trampolines for ffi calls for V8.

#html.elem("footer", [
  #html.elem("p", [
    #html.elem("a", attrs: (href: "https://x.com/undefined_void"), [x]) · #html.elem("a", attrs: (href: "mailto:me@littledivy.com"), [email]) · #html.elem("a", attrs: (href: "https://github.com/littledivy"), [github])
  ])
])
