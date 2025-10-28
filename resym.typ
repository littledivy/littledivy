#import "./shim/html.typ": *

#set document(
  title: "resym: Remote stack symbolication",
  keywords: "symbolicate, debuginfo, dwarf",
  description: "Remote stack symboication technique",
  date: datetime(day: 16, month: 2, year: 2025),
)

#show: html-shim

#title()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

Debug information makes up a significant portion of the size of a binary.

For applications that are distributed to end-users, it is common to strip debug information to reduce the size of the binary. This makes it difficult to debug crashes because the stack trace is not symbolicated. One way to work around this is to collect crash reports from users and symbolicate them manually.

resym is a tool that collects and seralizes win64 stack traces into URF-safe strings without compromising user privacy. It can be used to symbolicate stack traces on a remote server.

#link(
  "https://github.com/littledivy/resym",
)[https://github.com/littledivy/resym]

= Design

== Stack walking

On x86_64 Windows, resym uses `RtlLookupFunctionEntry`-based stack unwinding to collect the instruction pointers, starting from the current %rip register.

We first capture the caller's context using `RtlCaptureContext` and then walk the stack using `RtlLookupFunctionEntry` and `RtlVirtualUnwind`. This requires thread to be suspended (except for the current thread) which is the case for panic handlers.

```rust
std::panic::set_hook(Box::new(|_| {
  resym::win64::trace();
});
```

Before encoding, each stack address is calculated by subtracting the base address of the module that contains the address.

== Representation

A "trace string" is a sequence of URL-safe Base64 VLQ-encoded strings. This string can be safely shared with the crash reporter and sent to a remote server for symbolication.

```rust
std::panic::set_hook(Box::new(|info| {
  // upvCsknB2z8xrB-w7xrB-0qxrBs15xrBonm5zBqsuB2sjC8gMiqiCylyvrB0niCy1uBwltmzBut0L4y_uB.
  let trace_str = resym::win64::trace();
}));
```

== Symbolication

resym's symbolicate API decodes the trace string and finds the function frame using pdb-addr2line, the function frames are then passed to a formatter.

```rust
use resym::{symbolicate, DefaultFormatter};
use std::fs::File;

let pdb = File::open("path/to/symbols.pdb")?;

symbolicate(
  pdb,
  trace_str,
  DefaultFormatter::new(&mut std::io::stdout()),
)?;
```

You can bring your own formatter too.

```rust
const CSS: &str = include_str!("style.css");

impl<'a> HtmlFormatter<'a> {
  fn new(writer: &'a mut Vec<u8>) -> Self {
    let _ = writeln!(writer, "<style>{}</style>", CSS);
    Self { writer }
  }
}

impl Formatter for HtmlFormatter<'_> {
  fn write_frames(
    &mut self,
    addr: u32,
    frame: &resym::pdb_addr2line::FunctionFrames,
  ) {
    for frame in &frame.frames {
      let source_str =
        maybe_link_source(frame.file.as_deref().unwrap_or("??"), frame.line);
      let _ = writeln!(
        self.writer,
        "     <li>0x{:x}: <code>{}</code> at {}</li>",
        addr,
        frame.function.as_deref().unwrap_or("<unknown>"),
        source_str,
      );
    }
  }
}
```

= References

https://docs.rs/pdb-addr2line/latest/pdb_addr2line/


