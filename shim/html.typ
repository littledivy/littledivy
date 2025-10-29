// Taken from https://github.com/typst/typst/issues/7223#issuecomment-3446402111

/// Produce default document information needed for `default-head`. Requires
/// context.
#let get-document-info() = (
  title: document.title,
  author: document.author,
  description: document.description,
  keywords: document.keywords,
  locale: text.lang + if text.region != none { "-" + text.region },
)

/// Produces default head HTML tag based on document information.
///
/// ```typ
/// #show: doc => context html.html(default-head(get-document-info())() + doc)
/// ```
///
/// - info (dictionary): Document information that is passed to the head tag.
///     Use `get-document-info`.
#let default-head(info) = (..args) => {
  let head = if args.pos().len() > 0 { args.pos().first() } else { none }
  html.head(..args.named(), {
    html.meta(charset: "utf-8")
    html.meta(name: "viewport", content: "width=device-width, initial-scale=1")
    html.elem("link", attrs: (rel: "stylesheet", href: "main.css"))
    if info.title != none {
      html.title(info.title)
    }
    if info.description != none {
      html.meta(name: "description", content: info.description.text)
    }
    if info.author.len() != 0 {
      html.meta(name: "authors", content: info.author.join(", "))
    }
    if info.keywords.len() != 0 {
      html.meta(name: "keywords", content: info.keywords.join(", "))
    }
    head
  })
}

/// Produces default html HTML tag based on document information.
///
/// ```typ
/// #show: doc => context default-html(get-document-info())(doc)
/// ```
///
/// - info (dictionary): Document information that is passed to the html tag.
///     Use `get-document-info`.
#let default-html(info, head: auto) = (..args) => {
  let head = if head == auto { default-head(info) } else { head }
  let body = if args.pos().len() > 0 { args.pos().first() } else { none }
  html.html(head() + html.body(body), lang: info.locale, ..args.named())
}

#let html-shim(doc) = context {
  default-html(get-document-info())(doc)
}

