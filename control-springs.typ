#import "./shim/html.typ": *
#import "@preview/lilaq:0.6.0" as lq

#set document(
  title: "Control springs and press pulses",
  date: datetime(day: 17, month: 6, year: 2026),
  description: "How buttons, toggles, sliders, and focus rings reuse the same spring math",
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

= Control springs and press pulses

The control runtime in `src/Sources/SwiftUI/Views/Controls.swift` is not a
single animation system. It is a collection of small interaction models that
share the same timing logic and the same spring language.

The common goal is to make a control feel like something a finger actually
touched. That means the motion should have a brief impact phase, a release
phase, and a clean settle.

#sidenote[The code is solving for the feel of a tap, not the idealized mechanics of a mass-spring system.]

#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0.94, 1.01),
  lq.plot(lq.linspace(0, 1, num: 240), x => 1 - 0.04 * calc.exp(-8 * x) * (1 + 0.35 * calc.sin(14 * x))),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.plot(lq.linspace(0, 1, num: 200), x => calc.exp(-3.7 * x)),
  lq.plot(lq.linspace(0, 1, num: 200), x => 1 - calc.exp(-3.7 * x)),
))
#figure(lq.diagram(
  width: 12cm,
  height: 12cm,
  xlim: (0, 1),
  ylim: (0, 1),
  lq.plot(lq.linspace(0, 1, num: 200), x => calc.exp(-3.7 * x)),
  lq.plot(lq.linspace(0, 1, num: 200), x => 1 - calc.exp(-3.7 * x)),
  lq.scatter((0.12, 0.28, 0.56, 0.80), (0.85, 0.56, 0.23, 0.08)),
))

= The press pulse

The most obvious piece is the button press pulse. The code models a fast tap as
two phases:

1. a short dip to the pressed scale
2. a spring back to rest

The key constants are:

#M(`\text{dipDuration} = 0.10`)

#M(`\text{releaseDuration} = 0.42`)

#M(`\text{pressedScale} = 0.96`)

The press amount is time-driven from the tap instant. That matters because the
live host collapses touch-down and touch-up into one click, so there is no
persistent press-down event stream to animate from. The runtime reconstructs the
interaction from the moment of the tap.

The spring response uses the standard underdamped step-response form:

#M(`x(t) = 1 - e^{-\zeta \omega t}\left(\cos(\omega_d t) + \frac{\zeta \omega}{\omega_d}\sin(\omega_d t)\right)`)

That is a compact way to express the return-to-rest curve without integrating a
state machine for every button.

#note[This formula gets reused because the UI wants a family resemblance between buttons, toggles, sliders, and sheet-like surfaces.]

= Why the identity slot matters

Press state is keyed by construction order. That sounds mundane, but it is what
makes the pulse survive rebuilds. The view tree can be re-evaluated while the
animation is in flight. If the slot moved around, the pulse would either reset
or jump to the wrong control.

The runtime avoids that by allocating a stable press slot per button node. The
slot stays attached to the logical control, not to an ephemeral render pass.

That same idea shows up repeatedly in the repo:

- store state outside the transient view struct
- key it by construction order or identity
- drive it from a frame hook until it settles

= Toggles and sliders reuse the same math

The toggle flip uses a `.spring(response: 0.42, dampingFraction: 0.85)` curve.
That means the knob, the track crossfade, and the rest state all share one
timing envelope.

#M(`\omega = \frac{2\pi}{0.42}`)

#M(`\zeta = 0.85`)

The slider uses a slightly different pattern. The thumb grows on press, then
springs back on release. The important detail is that the release spring is tied
to the actual drag lifecycle, not to a fixed pulse timer. That keeps the motion
anchored to the user's gesture instead of to an arbitrary animation window.

This is a good example of a UI rule that is easy to miss:

- tap feedback should be time-based
- drag feedback should be state-based

Those are different interaction problems, even if they both use springs.

= Frame hooks and convergence

The runtime installs a frame hook when an animation begins. The hook keeps the
host ticking while any control is still mid-flight. Once the pulse or spring is
close enough to rest, the slot is cleared and the hook stops driving renders.

That is an important performance detail. You do not want a control animation
system that redraws forever because the state machine has no notion of rest.

The settle tests are intentionally simple:

#M(`|x| < \varepsilon \ \wedge\ |v| < \varepsilon \Rightarrow \text{stop}`)

That is enough because the goal is visual convergence, not exact physical
simulation.

= Why the numbers are coherent

The values are not random:

- `0.96` matches the lightly compressed look of a tap
- `0.42s` is the standard snappy response used elsewhere in the repo
- `0.85` gives a crisp underdamped settle without excessive overshoot

This is a nice case of local consistency. Buttons, toggles, sliders, sheets, and
share targets all reuse roughly the same motion language. That keeps the UI from
feeling like a pile of unrelated special cases.

= Layout and motion are separated

Another useful detail is that the render nodes keep layout and animation apart.
The node computes the control's size once, then applies scale and opacity
transforms during render.

That separation matters because it means the animation does not destabilize the
layout tree. A pressed button gets smaller visually, but its measured slot stays
coherent enough for hit testing and surrounding layout.

= What this section is really about

The mathematics here is not complicated in isolation. What makes it worth
writing about is the composition:

- a time-driven pulse for taps
- a spring response for releases
- stable identity across rebuilds
- host ticking only while motion is alive
- shared parameters across controls

That is the difference between an animation and an interaction system.
