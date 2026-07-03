#import "./shim/html.typ": *
#import "@preview/lilaq:0.6.0" as lq

#set document(
  title: "Mesh gradient interpolation",
  date: datetime(day: 17, month: 6, year: 2026),
  description: "Approximating SwiftUI mesh gradients with bilinear interpolation, smoothstep easing, and gamma-space color mixing",
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

= Mesh gradient interpolation

The `MeshGradient` implementation in `src/Sources/SwiftUI/Views/ShapesCluster.swift`
is a good example of a renderer choosing topology over direct feature mapping.
SwiftUI exposes a mesh gradient as a grid of control points, but the code does
not try to invent a bespoke GPU mesh pipeline. It reconstructs the visual result
from a dense set of filled sub-rectangles.

#note[This is a portable reconstruction strategy, not a literal mesh solver.]

#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.colormesh(
    (0, 0.25, 0.5, 0.75, 1),
    (0, 0.25, 0.5, 0.75, 1),
    (x, y) => x * y + (1 - x) * (1 - y) * 0.35,
    map: color.map.magma,
  ),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.plot(lq.linspace(0, 1, num: 200), x => x),
  lq.plot(lq.linspace(0, 1, num: 200), x => x * x * (3 - 2 * x)),
  lq.scatter((0.15, 0.15, 0.5), (0.15, 0.061, 0.50)),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.colormesh(
    (0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1),
    (0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1),
    (x, y) => (0.25 + 0.75 * x) * (0.2 + 0.8 * y),
    map: color.map.viridis,
  ),
))

That choice is deliberate. It keeps the renderer portable, deterministic, and
easy to validate against goldens.

= The visual model

The implementation treats the mesh as a width by height grid of colors. Each
output sample is built from the four surrounding grid colors using bilinear
interpolation.

In plain form, the blend is:

#M(`\text{top} = \text{mix}(a, b, f_x)`)

#M(`\text{bot} = \text{mix}(c, d, f_x)`)

#M(`\text{color} = \text{mix}(\text{top}, \text{bot}, f_y)`)

where `fx` and `fy` are the local fractions inside the cell. This is the same
basic structure you would expect from a bilinear texture lookup.

The code also has a `smoothsColors` mode. When that is enabled, the fractional
coordinates are eased with the cubic smoothstep function:

#M(`s(t) = 3t^2 - 2t^3`)

That does not change the topology of the interpolation. It just changes the
derivative at the cell boundaries so the seams soften.

#sidenote[The seam is the failure mode people notice first, which is why the 1px overlap matters so much.]

= Why subdivision instead of one mesh primitive

The renderer subdivides each cell into many small rectangles. Each rectangle is
filled with a locally interpolated color.

#M(`C(u,v) = (1-u)(1-v)C_{00} + u(1-v)C_{10} + (1-u)vC_{01} + uvC_{11}`)

This is a good tradeoff for three reasons:

1. the rendering backend already knows how to draw filled rects well
2. the approximation can be tuned with step count
3. the result is deterministic across hosts and rasterizers

The code chooses roughly 24 steps per cell edge. That gives enough samples that
the visual blend reads as continuous, while still keeping the implementation
simple enough to reason about.

That is the core of the technique: we are not approximating the math of the
mesh. We are approximating the rendered surface in a way that the backend can
handle reliably.

= Gamma space matters

The comments call out that colors are mixed in gamma sRGB, not linear-light
sRGB. That distinction is important because many rendering bugs come from
assuming interpolation is neutral when it is not.

If you interpolate the wrong way, the gradient looks correct at first glance but
the midtones drift. For a mesh gradient, that shows up as subtle banding or a
different center brightness than the system renderer.

The code takes the practical route:

- preserve the backend's mixing behavior
- match the measured output
- keep the approximation in the same color space as the target

That is the right call when the goal is visual fidelity rather than a canonical
color-management textbook implementation.

#note[Changing the interpolation space changes the look, even if the source code still says "interpolate".]

= What gets ignored

The overload that accepts `BezierPoint` intentionally ignores tangent handles.
That is not an accident. The implementation is not trying to simulate a curved
warp field. It only uses the point positions.

This is one of the better examples in the repo of a narrow compatibility choice.
The API accepts the full shape of SwiftUI's type, but the actual renderer only
needs the positions to reproduce the visible result in the cases it targets.

That is a healthy boundary:

- preserve source compatibility
- implement the subset that affects pixels
- keep the approximation honest in the docs

= Seam control

The renderer overlaps adjacent cells by about one pixel so antialiasing gaps do
not show through between sub-rectangles.

This is a tiny implementation detail with an outsized effect. Without it, the
same gradient could look correct at the center and still show a grid of seams at
cell boundaries. The visual system notices those artifacts immediately.

There is also a hidden lesson here: many rendering bugs are not mathematical in
the abstract. They are boundary condition bugs. The math is fine. The join is
not.

= The fallback path

If the grid data is invalid or underspecified, the code falls back to a simple
solid fill with the first color. That keeps the system from failing hard on
invalid inputs while making the behavior predictable.

That fallback is not glamorous, but it is the difference between a renderer that
keeps moving and one that forces the whole view tree to fail because a single
gradient was malformed.

= What makes this post worth writing

This implementation is interesting because it is an example of rendering math
that stays close to product reality:

- use bilinear interpolation because the topology is a grid
- smooth seams with smoothstep instead of more machinery
- mix in the right color space
- use subdivision because it is portable and predictable
- ignore unsupported tangents explicitly instead of half-supporting them

That is how you ship a feature-shaped approximation that still feels like the
real thing.
