#import "./shim/html.typ": *

#set document(
  title: "Orchid triage scouts and postmortem memory",
  date: datetime(day: 20, month: 6, year: 2026),
  description: "Using a cheap scout pass and shared lessons to stop a coding swarm from repeating itself.",
)

#show: html-shim

#nav-bar()

#title()
#byline()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

#let a(href, body) = html.elem("a", attrs: (href: href), body)

Once a coding swarm is big enough, two failure modes show up fast:

- workers duplicate work that was already done somewhere else
- the same PR mistakes get rediscovered issue after issue

Orchid now has a small answer to both. A cheap read-only triage agent runs before the real worker, and a one-line lesson is extracted after the PR finishes.

This landed in Orchid as part of the work around triage scouts, postmortem lessons, and draft-first PR flow #a("https://github.com/littledivy/orchid", [repo]).

#figure(
  image("./static/img/orchid-triage-loop.svg", width: 100%),
)

= Triage before execution

When a new issue lands in the inbox, Orchid can run a one-shot scout through an operator-configured `TriageCmd`. The scout is intentionally cheap and read-only. It is not there to solve the issue. It is there to reduce avoidable churn before a heavier worker session starts.

The scout uses `gh` and the repository state to answer a few specific questions:

- is there already an open PR doing this
- is there a duplicate issue in the inbox
- which files and tests are probably relevant
- does this look small, medium, or large

Then it posts the result back to the issue as a structured `## Triage` comment.

That comment becomes part of the worker's bootstrap context. The worker starts with a map instead of opening ten tabs to rediscover the same thing.

= Why the scout is separate

This is worth keeping separate from the main agent run.

A scout wants different behavior from a worker. It should be cheap, narrow, and hard to overthink. It should not start editing files. It should not spend an hour writing code nobody asked for. It should just gather enough information to make the real run less wasteful.

That split also makes the system easier to tune. If the triage pass is noisy, you fix the scout prompt or command. If implementation quality is weak, you tune the worker. They are different jobs.

= Postmortem memory

The second half happens after the PR reaches a terminal state.

Orchid distills a short lesson from the outcome and appends it to shared `lessons.md` in the memory repo. The point is not to write an essay. The point is to leave behind the sharp edge that mattered:

- maintainer wanted a smaller diff
- test expectation was in a different package
- issue looked valid but already had a fix in flight
- a specific subsystem always needs one extra build step

This is the sort of detail humans remember after the third review round. A swarm needs the same memory if it is going to stop re-deriving the same constraints.

= Draft-first PRs

The scout and the lesson loop fit well with draft-first PRs.

A worker can open a draft with the current state of the implementation, the operator can see what direction it took, and the postmortem path still captures what happened next. That is better than treating every PR as an all-or-nothing final answer. Swarms need visibility more than theatrics.

= What changes operationally

With the scout in front and memory behind, the middle of the loop gets cleaner:

- fewer duplicate workers on already-covered issues
- less time spent locating the likely files
- a better chance that the next worker avoids the last review mistake

None of this makes an agent smarter in the abstract. It just reduces the amount of stupid work the system willingly repeats.

= Notes

A lot of agent infrastructure work fixates on the executor: faster models, more sessions, better prompts, longer context.

That helps, but orchestration quality often depends more on what happens around execution. Preflight and memory are small pieces of code with a large effect on whether the swarm behaves like a system or just a pile of terminals.
