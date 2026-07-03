#import "./shim/html.typ": *
#import "@preview/lilaq:0.6.0" as lq

#set document(
  title: "Liquid Glass morphing",
  date: datetime(day: 17, month: 6, year: 2026),
  description: "Identity, union, and frame morphing for Apple's translucent material",
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

= Liquid Glass morphing

`src/Sources/SwiftUI/Modifiers/LiquidGlass.swift` is less about raw math than
about turning a visual effect into a consistent object model. The code has to
make glass behave like a thing with identity, not just a static blur.

#sidenote[The interesting part is that the effect is visual, but the implementation still needs identity, merge, and settle semantics.]

#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.line((0.20, 0.62), (0.42, 0.82)),
  lq.line((0.42, 0.82), (0.78, 0.78)),
  lq.line((0.78, 0.78), (0.64, 0.44)),
  lq.line((0.64, 0.44), (0.20, 0.62)),
  lq.line((0.26, 0.52), (0.48, 0.72)),
  lq.line((0.48, 0.72), (0.82, 0.68)),
  lq.line((0.82, 0.68), (0.68, 0.36)),
  lq.line((0.68, 0.36), (0.26, 0.52)),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.scatter((0.28, 0.72), (0.52, 0.52)),
  lq.line((0.14, 0.52), (0.86, 0.52)),
  lq.line((0.50, 0.30), (0.50, 0.74)),
  lq.line((0.20, 0.32), (0.84, 0.70)),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.plot(lq.linspace(0, 1, num: 240), x => 0.17 + 0.03 * calc.sin(14 * x) + 0.01 * calc.sin(33 * x)),
  lq.line((0%, 20%), (100%, 20%)),
  lq.line((0%, 26%), (100%, 26%)),
))

That means it needs to answer three questions:

1. what is the shape of the glass
2. what is its motion when the frame moves
3. when do multiple glass objects merge into one

The implementation answers those with explicit identity keys, frame morphing,
and a union registry.

= The static material

The base `Glass` value is small:

- variant: regular or clear
- tint color
- interactive flag

It also encodes a compact style byte for the renderer. That byte carries the
variant and the dark-mode bit, which is enough for the draw op to reconstruct
the right material at render time.

#M(`\text{style} = \text{base} \;|\; (\text{dark} \ll 4)`)

This is a good example of pushing semantic state into a tiny wire format. The
runtime does not need a giant material object. It needs just enough information
to reproduce the effect.

= Morphing by identity

The `glassEffectID` modifier ties the visual element to a `(namespace, id)` key.
When the frame changes under animation, the panel morphs from the old rect to
the new rect rather than snapping.

The key point is that the identity is separate from layout. The glass effect is
purely visual, so its identity can survive layout changes without affecting the
measured size of the underlying view.

That lets the renderer do something important:

- keep the visual material stable
- move the frame smoothly when the layout changes
- preserve the resting appearance when nothing has moved

That is the same general trick matched geometry effects rely on, but applied to
a material instead of a plain rectangle.

= Union and merge

The more interesting part is the merge behavior. When two glass panels are in
the same container and close enough together, they can blend into a single
blob-like union instead of staying as separate pills.

That is a direct visual analogy to metaballs, even if the implementation is not
using a full implicit-surface solver. The important thing is the interaction
model, not the exact rendering primitive.

#note[The merge rule is intentionally separate from the morph rule. Those are different lifetimes and should not be collapsed into one key.]

The code uses a separate union key so the merge group is distinct from the
morphing identity. That separation is important:

- morph identity says which panel this is
- union identity says which cluster it belongs to

Those are different concepts, so they should not be conflated.

= Sub-pixel stability

There is a small helper that compares frames with a very tight epsilon. That is
there to prevent sub-pixel jitter from triggering unnecessary morphs.

#M(`|a - b| < 0.01`)

This kind of threshold is easy to underestimate. If you treat every tiny
floating-point difference as a real move, the effect will constantly retrigger
and never feel at rest.

The epsilon says something important about the desired semantics:

- below this threshold, the frame is effectively unchanged
- above it, the visual identity should migrate smoothly

That is a healthy place to be in UI code. You want the motion to respond to real
changes, not numerical noise.

= Interactive glass

The interactive branch adds a press state. When the panel is pressed, it grows a
little and the highlight responds to the pointer. The effect feels tactile
because it is driven by the same kind of spring logic used elsewhere in the UI.

This part of the file is mostly about composition:

- material rendering
- drag registry
- press spring
- per-slot state

The effect is not one giant shader trick. It is several smaller systems working
together.

#sidenote[That composition is what lets the effect stay byte-identical at rest while still animating when identity changes.]

= Why this matters

This file is a good post because it shows how a visual effect becomes an object
with lifecycle:

- static style bytes for rendering
- identity keys for stable morphs
- union keys for cluster merging
- sub-pixel thresholds for stability
- interaction state for the pressed response

That is the real lesson. A material becomes convincing when the effect knows
when it is the same object, when it moved, and when it should merge with its
neighbors.
