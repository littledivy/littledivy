#import "./shim/html.typ": *

#set document(
  title: "Lazy-loading macOS frameworks with lzld",
  date: datetime(day: 20, month: 6, year: 2026),
  description: "Cutting Deno startup work on macOS by moving framework loads out of process launch.",
)

#show: html-shim

#nav-bar()

#title()
#byline()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

#let a(href, body) = html.elem("a", attrs: (href: href), body)

On macOS, some startup cost happens before `main()` even runs.

Deno's release builds for `aarch64-apple-darwin` link a handful of system frameworks: `CoreFoundation`, `Foundation`, `Security`, `CoreServices`, `Metal`, `QuartzCore`, `CoreGraphics`, and `MetalPerformanceShaders`. The runtime does need symbols from some of them, but not on every command and not at launch. Even so, dyld was loading and initializing them during process startup.

#a("https://github.com/denoland/deno/pull/35341", [PR #35341]) changes that path by linking through `lzld`, a small linker wrapper that strips `-framework` arguments from the final link and replaces them with a shim library that `dlopen`s the framework on first symbol use.

#figure(
  image("./static/img/lzld-flow.svg", width: 100%),
)

= Weak-linking was not enough

The obvious first thought is weak-linking. That helps with compatibility, but it does not stop launch-time loading in this case. If the binary records the framework as a dependency, dyld still has work to do before the process is ready.

For a command line runtime, those milliseconds matter. `deno --version` and `deno --help` should do almost nothing. If they pay for graphics or security frameworks during launch, that is wasted baseline cost.

= What lzld does

The linker setup is simple in concept.

- keep unresolved framework symbols in the binary
- route them through a static shim
- `dlopen` the framework when the symbol is first touched
- cache the loaded handle for later calls

This moves the cost from process launch to actual use.

The PR wires this in only for Darwin ARM64 release builds. The build script explicitly avoids checking in a fixed `.cargo/config.toml` because Apple clang wants an absolute `-fuse-ld` path, so CI patches the linker path at build time instead.

= Why this is a good runtime optimization

It does not change user-visible behavior. It changes *when* the platform dependency is paid for.

If a command never touches Metal or QuartzCore, those frameworks stay unloaded. If some desktop or graphics-adjacent path eventually needs them, the first call pays the cost there. That is a better distribution for a general runtime where many commands are short-lived and never exercise those subsystems.

The release test added in the PR makes this visible. On release aarch64 builds, startup dylibs were reduced to:

- `/usr/lib/libiconv.2.dylib`
- `/usr/lib/libSystem.B.dylib`
- `/usr/lib/libobjc.A.dylib`

The framework count at launch dropped from 8 to 0.

= Numbers

The measured deltas from the PR were:

- `deno --version`: `5.2 ms -> 4.8 ms` (`-7%`)
- `deno --help`: `6.2 ms -> 5.7 ms` (`-8%`)
- `deno task echo`: `7.1 ms -> 6.7 ms` (`-6%`)
- launch-time dylibs: `11 -> 3`
- launch-time frameworks: `8 -> 0`

This is the sort of optimization that looks small in absolute terms and still feels very worth doing. Startup is a sum of tiny decisions. The fact that this one happened at the linker and loader layer makes it more interesting, not less.

= Build mechanics

The patch adds `tools/lzld` as a submodule and builds the helper as part of the release path. That is a pragmatic choice. There is no value in pretending the system linker will do something it is not designed to do. If the runtime wants lazier launch behavior, it can ask for it explicitly.

This is also a good example of not overfitting the optimization. The change is narrowly scoped to the target where the measurements mattered, and the test asserts the final binary shape instead of trusting flags by inspection.

= Notes

A lot of runtime performance work lives above the OS: JavaScript bootstrap, snapshot size, allocator behavior, Rust hot paths.

Sometimes the cheapest startup win is lower down. The process can get faster before your code starts running at all.
