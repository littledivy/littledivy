#import "./shim/html.typ": *
#import "@preview/lilaq:0.6.0" as lq

#set document(
  title: "Scroll physics as a fitted model",
  date: datetime(day: 17, month: 6, year: 2026),
  description: "How the scroll stack turns recorded iOS traces into a calibrated motion model",
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

= Scroll physics as a fitted model

This is the most direct example in the codebase of a mathematical model that was
not invented first and validated later, but measured first and encoded after.
The scroll stack in `src/Sources/SwiftUI/Render/ScrollPhysics.swift` is built
from simulator traces, then fitted, then replay-gated.

The core claim is simple: if you want a scroll interaction to feel like UIKit,
you do not get there by picking a spring constant that seems nice. You measure
the real system, keep the equations small, and fit the constants to the trace.

#note[The point is not to make the equations pretty. It is to keep them small enough that they can be fitted, checked, and re-run when the device behavior changes.]

#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1.6),
  ylim: (0, 1.1),
  lq.plot(lq.linspace(0, 1.6, num: 200), x => x),
  lq.plot(lq.linspace(0, 1.6, num: 200), x => (0.68 * x) / (1 + 0.68 * x)),
  lq.plot(lq.linspace(0, 1.6, num: 200), x => (0.42 * x) / (1 + 0.42 * x)),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1.0),
  ylim: (0, 1.05),
  lq.plot(lq.linspace(0, 1.0, num: 200), x => calc.exp(-3.1 * x)),
  lq.scatter((0.08, 0.22, 0.37, 0.55, 0.74, 0.93), (0.76, 0.49, 0.31, 0.17, 0.09, 0.04)),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1.2),
  ylim: (-0.75, 0.2),
  lq.plot(lq.linspace(0, 1.2, num: 200), x => -(1 + 4.5 * x) * calc.exp(-5 * x)),
  lq.line((0%, 50%), (100%, 50%)),
))

= The model

The runtime uses four separate regimes:

- rubber-band overscroll while the finger is still down
- normal deceleration while the scroll view is in free motion
- spring bounce when momentum hits an edge
- a slower snap-back curve when the user lets go from rest while overscrolled

The fitted formulas are documented in the source comments:

#M(`\text{rubber}(x) = \frac{xcd}{d + cx}`)

#M(`v(t) = v_0 \, \text{rate}^{1000 t}`)

#M(`x_{\text{vel}}(t) = (x_0 + (v_0 + \omega x_0)t)e^{-\omega t}`)

#M(`x_{\text{rest}}(t) = x_0\left(c_1 e^{-l_1 t} + (1 - c_1)e^{-l_2 t}\right)`)

Here `x` is finger excess past the edge, `d` is viewport length, `v0` is the
release velocity, and `x0` is the current overshoot or offset at the start of a
spring phase.

The useful thing about splitting the behavior into regimes is that each one is
small enough to reason about independently. The scroll view does not need a
single universal animation function. It needs the right function for the phase
it is in.

= Why the rubber band matters

The rubber-band formula is not arbitrary. It encodes two constraints that are
visible on device:

1. the response should be linear near zero, so small overscroll feels direct
2. the response should saturate, so pulling harder gives diminishing returns

The fraction

```text
(x * c * d) / (d + c * x)
```

does exactly that. The constant `c` controls the curvature and `d` scales the
effect with viewport size. When `x` is small, the denominator is close to `d`,
so the behavior is almost linear. When `x` gets large, the output grows slowly
enough that the edge feels elastic rather than broken.

The important detail is that the runtime also exposes the inverse transform.
That lets the release velocity be converted back into display-space velocity
when the finger lets go while the content is still rubber-damped.

#sidenote[That inverse is what lets the release feel continuous instead of snapping from finger-space back to display-space at the edge.]

= The deceleration fit

UIKit deceleration is modeled as exponential decay:

#M(`v(t) = v_0 \, \text{rate}^{1000 t}`)

The `1000` is there because the traces and the host tick are expressed in
milliseconds. This is a good example of a small implementation detail that
matters: a mathematically correct formula can still be awkward to use if the
units are inconsistent.

The fitter in `tests/scroll/fit.py` does not guess the rate. It searches the
parameter space against real traces, then solves for the linear terms with least
squares once the rate is fixed. That matters because the velocity curve is not
just visually similar; it is numerically checked against recorded motion.

#sidenote[The search is coarse enough to be practical and constrained enough to keep the fitted rate stable across runs.]

The comments in the fitter also call out a stale first frame at the phase
boundary. That is the sort of detail that separates a fitting pipeline from a
toy plot. Real instrumentation has noise. The pipeline has to know what to drop.

= The bounce at the edge

When deceleration hits a bound, the model switches to a critically damped spring

#M(`x(t) = (x_0 + (v_0 + \omega x_0)t)e^{-\omega t}`)

The reason this matters is that edge hits are not the same as an overscrolled
release from rest. The content already has momentum, so the bounce needs to
preserve that velocity and then dissipate it cleanly.

The source handles this by reading the current animated offset at the crossing
time, then starting a new spring phase with the current velocity. That is a good
pattern for any motion system: do not reset state unless the physical event
really implies a reset.

= The snap-back from rest

The rest-release curve is a two-exponential fit:

#M(`x(t) = x_0\left(c_1 e^{-l_1 t} + (1 - c_1)e^{-l_2 t}\right)`)

This is a practical fit, not a canonical physics derivation. The code is
admitting that the measured behavior is more complex than a single damped spring
but still simple enough to approximate well with two decay rates.

That is the right engineering tradeoff here. A fancy model is not an advantage
if it is impossible to keep stable across revisions. A compact empirical model
is better because it can be re-fit when the device behavior shifts.

= Why the fitter matters

The fitting script in `tests/scroll/fit.py` is part of the article, not a test
appendix. It does the work that makes the constants trustworthy:

- `fit_rubber()` searches `c` and the effective slop offset
- `fit_spring_rest()` fits a shared two-exponential curve
- `fit_spring_velocity()` fits the post-impact bounce omega
- `fit_decel()` sweeps deceleration rate and solves the linear terms with LSQ

The result is a constants file derived from trace data, not a hand-tuned
impression of what should feel right.

#note[The source comments, raw traces, fitter, constants file, and replay gate all have to agree or the scroll feel is not actually under control.]

= Runtime structure

The runtime keeps a per-scroll-view state machine alive across rebuilds. That is
important because the view tree can be reconstructed while the gesture is in
flight. The state object stores the current phase, drag samples, animation
starting point, and the fitted parameters needed to evaluate the closed forms.

Two implementation details deserve attention:

1. release velocity is computed over a trailing window, not from the final
   instantaneous delta
2. the animator returns `true` while anything is in flight, so the host keeps
   ticking until the curve has settled

That is the core loop: capture, evaluate, settle, and stop only when the motion
is numerically close enough to rest.

= The larger lesson

The useful pattern here is not specific to scrolling. It is a general way to
build motion systems:

- measure the real behavior
- reduce it to a small number of stable regimes
- fit the constants, do not guess them
- keep the runtime side closed-form when possible
- gate the result against replayed traces

That is how you get motion that feels native without pretending the math is
hand-authored art.
