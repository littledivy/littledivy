#import "./shim/html.typ": *

#set document(
  title: "me@littledivy.com",
  description: "Divy's personal page. Software writeups and more",
)

#show: html-shim

#title()

hello; welcome to my small patch of the internet.
i spend most of my time working on the #html.elem("a", attrs: (href: "https://deno.com"), [deno runtime]),
and my main in LoL is Caitlyn.

i like digging into runtimes, compilers, cryptography and my bestie's lore.

#html.elem("div", attrs: (class: "note"), [
  #html.elem("div", attrs: (class: "adm-title"), [recent talks])

  #html.elem("p", [
    #set list(marker: [--])
    - #html.elem("a", attrs: (href: "https://youtu.be/qt3-3FkPqQ8?t=450"), [kernel to runtime]) — iit kanpur OOSC 3, 2025.
      how javascript calls become syscalls: event loops, epoll, and async i/o.
    - #html.elem("a", attrs: (href: "https://www.youtube.com/watch?v=vINOqgn_ik8"), [deno internals: op2 driver]) — about deno_core internals, runtime call overhead, and js\<-\>rust translation layer.
    - #html.elem("a", attrs: (href: "https://www.youtube.com/watch?v=RKjVcl62J9w"), [building games with deno ffi]) — how to build a cross-platform game using SDL2 in JS.
    - #html.elem("a", attrs: (href: "https://www.youtube.com/watch?v=gA152Hun8cI"), [webgpu windowing]) — about rendering a gpu-accelarated window using webgpu and window surface APIs.
    - #html.elem("a", attrs: (href: "https://www.youtube.com/watch?v=5wlZDw942J8"), [injecting r/o data into binaries]) - cross-platform tool that powers deno's compiler.
    - #html.elem("a", attrs: (href: "https://www.youtube.com/watch?v=ssYN4rFWRIU"), [jit compiler for dynamic FFI]) - _blazing fast_ compiler for generating trampolines for ffi calls for V8.
  ])
])

== recent posts

#set list(marker: [--])
- #html.elem("a", attrs: (href: "/resym"), [remote stack trace symbolication]) — serializable stack trace collection for remote symbolication.
- #html.elem("a", attrs: (href: "/sh-deno"), [sh-deno]) — apple's seatbelt sandboxing combined with deno's permission system for hardened runtime security.
- #html.elem("a", attrs: (href: "/turbocall"), [turbocall]) — just-in-time compiler for generating trampoines for V8 \<-\> FFI bindings.
- #html.elem("a", attrs: (href: "/sui"), [sui]) — notes on cross-platform injection arbritrary data into prebuilt binaries.

#html.elem("div", attrs: (class: "note"), [
  #html.elem("div", attrs: (class: "adm-title"), [miscellany])

  #html.elem("p", [
    #set list(marker: [--])
    - you may find me rambling on #html.elem("a", attrs: (href: "https://x.com/undefined_void"), [x]).
    - email: #html.elem("a", attrs: (href: "mailto:me@littledivy.com"), [me\@littledivy.com])
    - github: #html.elem("a", attrs: (href: "https://github.com/littledivy"), [https://github.com/littledivy])
  ])
])

