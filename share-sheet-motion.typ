#import "./shim/html.typ": *
#import "@preview/lilaq:0.6.0" as lq

#set document(
  title: "Share sheet motion",
  date: datetime(day: 17, month: 6, year: 2026),
  description: "A damped modal spring, viewport-aware geometry, and one active sheet at a time",
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

= Share sheet motion

`src/Sources/SwiftUI/Views/ShareTable.swift` is a narrower file than the scroll
stack, but it still has useful motion math in it. It models the share sheet as a
single modal object with its own spring state, its own geometry, and a
conservative dismissal path.

That is exactly the kind of thing you want from a modal interaction: one active
instance, clean ownership, and no ambiguity about when it is up or down.

#sidenote[This file is mostly about lifecycle discipline: the modal is either resting, moving, or dismissed. Nothing else should leak through.]

#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.plot(lq.linspace(0, 1, num: 220), x => 1 - 0.8 * x + 0.12 * calc.exp(-5 * x) * calc.cos(9 * x)),
  lq.plot(lq.linspace(0, 1, num: 220), x => 0.5 - 0.5 * calc.exp(-4 * x) * calc.cos(8 * x)),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.line((0.12, 0.08), (0.88, 0.08)),
  lq.line((0.12, 0.08), (0.12, 0.92)),
  lq.line((0.88, 0.08), (0.88, 0.92)),
  lq.line((0.12, 0.92), (0.88, 0.92)),
  lq.line((0.24, 0.36), (0.76, 0.36)),
  lq.line((0.24, 0.26), (0.76, 0.26)),
  lq.line((0.24, 0.16), (0.76, 0.16)),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.plot(lq.linspace(0, 1, num: 220), x => 0.8 * calc.exp(-5.5 * x)),
  lq.line((0%, 6%), (100%, 6%)),
))

= One active sheet

The sheet state lives in a shared singleton because iOS only lets one share
sheet dominate the screen at a time in the normal interaction model. The code
tracks:

- whether the sheet is logically presented
- whether motion is still in flight
- the current vertical offset
- the current velocity
- the last frame time

That keeps the modal's animation state separate from the rendering of the
button that spawned it.

#note[Modal ownership is the real invariant. The animation just makes that invariant visible.]

This is a small but important architectural choice. The button is not the sheet.
The sheet is a modal overlay with its own lifecycle.

= The spring model

The share sheet uses a damped spring with:

#M(`\omega = \frac{2\pi}{0.42}`)

#M(`\zeta = 0.85`)

The code then integrates the motion using a semi-implicit Euler step:

#M(`a = k(\text{target} - \text{off}) - c v`)

#M(`v_{n+1} = v_n + a \Delta t`)

#M(`x_{n+1} = x_n + v_{n+1} \Delta t`)

This is a practical choice. The motion is stable enough for variable frame
times, and the implementation is easy to inspect. The system does not need
closed-form exactness here because the animation is short-lived and the settle
thresholds are explicit.

= Why symplectic Euler is a good fit

The interesting thing about semi-implicit Euler is that it is more stable than
a naive explicit update for stiff-ish springs. That is useful when the motion
can be resumed after frame drops or when the host tick is not perfectly uniform.

#sidenote[The clamped `dt` is not a cosmetic detail. It keeps a stalled frame from becoming a numerical spike.]

The code clamps the frame delta into a safe range before stepping. That avoids
blowing up the integrator on a long stall and keeps the animation from
teleporting when the renderer catches up.

This is the right kind of engineering compromise:

- the system is physically inspired
- the update rule is stable enough for UI use
- the stop condition is based on visible convergence

= Geometry of the overlay

The modal is not just an animation. It is geometry on a viewport:

- the scrim covers the full device bounds
- the card is inset from the edges
- the bottom inset respects the safe area
- the sheet occupies a fixed fraction of the screen height

That geometry matters because the spring only controls the vertical offset. The
actual card size and hit region still have to be computed from the viewport.

The implementation keeps the sheet visually anchored to the bottom, with the
remaining travel determined by the current offset fraction.

= Dismissal rules

The backdrop only becomes tappable when the sheet is at rest. That is a subtle
but important detail. It prevents a mid-slide tap from triggering a dismissal
before the sheet is fully in the interactive state.

Likewise, the share targets dismiss the sheet when tapped, but only once the
sheet is settled. That keeps the interaction predictable and avoids duplicate
events during motion.

= What this post is really about

The share sheet is a nice example of a modal animation that stays disciplined:

- one active object
- a single spring state
- stable viewport-aware geometry
- explicit settle thresholds
- conservative interaction gating

It is not the most mathematically exotic part of the codebase. It is, however,
the kind of small interaction model that becomes annoying very quickly if the
state machine is not clean.
