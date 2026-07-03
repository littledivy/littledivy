#import "./shim/html.typ": *
#import "@preview/lilaq:0.6.0" as lq

#set document(
  title: "Path geometry and arc-length math",
  date: datetime(day: 17, month: 6, year: 2026),
  description: "How the path stack flattens curves, trims arcs, transforms geometry, and approximates boolean ops",
)

#show: html-shim

#show math.equation.where(block: false): it => {
  if target() == "html" {
    html.elem("span", attrs: (class: "math"), html.frame(it))
  } else {
    it
  }
}

#show math.equation.where(block: true): it => {
  if target() == "html" {
    html.elem("figure", attrs: (class: "math"), html.frame(it))
  } else {
    it
  }
}

#nav-bar()

#title()
#byline()

= Path geometry and arc-length math

The `Path` implementation in `src/Sources/SwiftUI/Views/Path.swift` is one of
the clearest examples of geometry-first engineering in the repo. It is not just
an object that stores drawing commands. It is a small geometry kernel with
explicit choices for approximation, transform handling, and hit testing.

The interesting part is that almost every method has a tradeoff hiding behind it.
Once you make those tradeoffs visible, the implementation becomes much easier to
understand and much easier to justify.

#sidenote[The same file deals with representation, length, transforms, and containment. That is already enough geometry to write about.]

#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.plot(lq.linspace(0, 1, num: 240), x => 0.12 + 0.62 * calc.sin(calc.pi * x) * calc.exp(-0.2 * x) + 0.12 * x),
  lq.scatter((0.06, 0.15, 0.24, 0.35, 0.48, 0.61, 0.73, 0.85, 0.94), (0.15, 0.46, 0.74, 0.88, 0.79, 0.46, 0.23, 0.44, 0.81)),
  lq.line((0.30, 0.05), (0.30, 0.95)),
  lq.line((0.70, 0.05), (0.70, 0.95)),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (-1.6, 1.6),
  ylim: (-1.0, 1.0),
  lq.line((-1.2, -0.4), (-0.3, -0.4)),
  lq.line((-0.3, -0.4), (-0.3, 0.4)),
  lq.line((-0.3, 0.4), (-1.2, 0.4)),
  lq.line((-1.2, 0.4), (-1.2, -0.4)),
  lq.line((0.4, -0.6), (1.2, -0.3)),
  lq.line((1.2, -0.3), (0.9, 0.7)),
  lq.line((0.9, 0.7), (0.1, 0.4)),
  lq.line((0.1, 0.4), (0.4, -0.6)),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (-1.5, 1.5),
  ylim: (-1.1, 1.1),
  lq.plot(lq.linspace(-1.3, 1.3, num: 120), x => 0.7 * calc.sin(2.3 * x) * calc.exp(-0.25 * x * x)),
  lq.scatter((-1.1, -0.7, -0.3, 0.1, 0.5, 0.9, 1.2), (0.0, 0.42, 0.72, 0.92, 0.78, 0.44, 0.05)),
  lq.line((-1.25, 0.0), (1.25, 0.0)),
))

= A compact path model

The structure stores a sequence of elements:

```swift
case move(CGPoint), line(CGPoint), quad(CGPoint, CGPoint), curve(CGPoint, CGPoint, CGPoint), close
case rect(CGRect), ellipse(CGRect), roundedRect(CGRect, CGFloat)
case arc(CGPoint, CGFloat, CGFloat, CGFloat, Bool)
```

This is already a decision. Instead of canonicalizing everything into one huge
general-purpose vector format, the code keeps primitive verbs around for as long
as they remain useful. Rectangles stay rectangles. Arcs stay arcs. Curves stay
curves.

That preserves intent and makes the renderer simpler.

#note[Keeping primitives around avoids flattening work until a later operation actually needs it.]

= Flattening as a bridge

The key utility is `_flatten()`. It turns the path into a polyline so that
operations like trimming, winding, and approximate stroke construction can work
in a space where length and adjacency are easy to compute.

The method uses explicit tessellation counts:

- quadratic curves use `#m(24)` steps
- cubic curves use `#m(32)` steps
- ellipses use `#m(64)` steps
- arcs choose a step count from angular span

Those values are not magical. They are practical sampling densities that keep
the approximation stable enough for the rendering pipeline while avoiding a
full symbolic geometry engine.

This is the recurring pattern in the repo: use exact math when it is cheap and
stable, use sampling when exact geometry would explode in complexity.

#M(`B(t) = (1-t)^3 p_0 + 3(1-t)^2 t c_1 + 3(1-t) t^2 c_2 + t^3 p_3`)

= Trimming by arc length

`trimmedPath(from:to:)` is one of the nicer pieces of the file because it
turns a normalized fraction into actual geometry. The method:

1. flattens the path
2. measures cumulative segment lengths
3. maps the requested fraction interval onto total arc length
4. clips each polyline segment to the selected interval

That is the right way to think about trimming. You do not trim by vertex index.
You trim by length, because length is what the user perceives.

#sidenote[Arc-length trimming is usually the more useful abstraction because it survives resampling and tessellation changes.]

For a circular stroke, `trim(0, 0.5)` produces a half ring. The path itself is
not magical here. The arc-length bookkeeping is.

= Transforming geometry honestly

The `applying(_:)` method is the piece that prevents a lot of subtle bugs.
Affine transforms are applied directly to points, but primitive verbs are only
preserved when the transform is axis-aligned. Otherwise, the path is expanded to
a polyline and transformed point by point.

That is important because a rotated rectangle cannot be represented as a
rectangle verb anymore. If you keep the primitive shape after rotation, you are
lying to the rest of the system.

The code is explicit about this:

- axis-aligned rects, ellipses, and rounded rects can stay primitive
- rotated or skewed primitives are expanded to points

That honesty keeps downstream hit testing and drawing behavior coherent.

= Hit testing and winding

`contains(_:eoFill:)` operates over subpolygons and uses winding rules instead of
assuming the path is a single simple contour. That matters because paths in the
real world are often compound and self-intersecting.

There are two fill rules in play:

- even-odd toggles inside/outside each time a loop contains the point
- non-zero winding counts signed coverage

The implementation does not try to be clever beyond what the data structure can
support. It uses the flattened geometry and a consistent winding helper. That
gives good-enough semantics for hit testing without importing a full CGPath
engine.

#note[The goal is compatibility with the rest of the renderer, not exact symbolic path algebra.]

= Stroke outlines as a band

`strokedPath(_:)` is intentionally approximate. It does not reconstruct exact
join and cap geometry. Instead, it offsets the centerline polyline to the left
and right, then closes the band.

That is enough for the cases the code needs:

- hit testing
- overlap math
- visual approximation in a rasterized renderer

Again, the point is not geometric purity. It is matching the required behavior
with the simplest representation that stays stable.

= Boolean ops by raster sampling

The boolean operators are the most explicit approximation in the file. The code
admits that exact `CGPath` boolean geometry is not reconstructable from the
polyline form, so it samples a grid over the combined bounds and emits a
marching-squares-like boundary.

That sounds crude until you look at the target use case. These operations are
meant for small filled shapes like overlapping circles and rectangles. In that
domain, a raster-sampled boundary is enough to match the golden output while
keeping the implementation tractable.

The interesting engineering move is that the output is still a path. The
approximation happens once, but the result behaves like normal geometry after
that.

= What this post is really about

This file is a good candidate for a blog post because it shows a pattern that is
easy to miss in graphics work:

- exact geometry is valuable, but not always necessary
- approximate geometry is acceptable when the error budget is known
- every approximation should be local and explicit
- the data model should preserve primitive intent as long as possible

That is how you build a path kernel that is small enough to maintain and good
enough to render real UI.
