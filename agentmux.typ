#import "./shim/html.typ": *

#set document(
  title: "agentmux: a tmux-backed desktop for coding agents",
  date: datetime(day: 20, month: 6, year: 2026),
  description: "Using tmux as the durable control plane for a desktop app that supervises Claude and Codex sessions.",
)

#show: html-shim

#nav-bar()

#title()
#byline()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

#let a(href, body) = html.elem("a", attrs: (href: href), body)

A desktop terminal for coding agents does not need to reinvent the session layer.

`tmux` already has most of the hard parts: durable sessions, splits, attach/detach, and a control interface that works well enough from scripts. `agentmux` leans into that instead of pretending the terminal app should be the source of truth.

The desktop UI is just a control plane around a dedicated tmux socket: workspaces, tabs, panes, and agent state on top of sessions that still exist even if the app goes away.

#a("https://github.com/littledivy/agentmux", [https://github.com/littledivy/agentmux])

#figure(
  image("./static/img/agentmux-architecture.svg", width: 100%),
)

= tmux as the durable backend

The app runs against `tmux -L agentmux`, not the user's default socket. That keeps the state scoped and makes the desktop app restartable without killing the sessions it manages.

This is the right trade.

If the UI crashes, the sessions are still there. If I want to inspect one from a normal shell, I can still run:

```sh
tmux -L agentmux attach -t <name>
```

That matters more than building a perfectly custom session engine. For coding agents, durability and inspectability beat novelty.

= Session structure

The model is straightforward:

- workspaces own tabs
- tabs map to tmux sessions or panes
- splits stay tmux-native
- the desktop app reflects and controls that graph

The interesting bit is not the layout. It is the decision to make the layout a view over tmux rather than a private in-memory state machine.

= Detecting agent state cheaply

`agentmux` does not integrate with Claude or Codex through a private protocol. It looks at what is already visible in the terminal and infers state from marker strings in the xterm buffer.

That sounds crude, but it is pragmatic and works across tools.

A few examples:

- a visible `esc to interrupt` marker usually means the agent is still working
- prompts like `do you want to proceed` or `(y/n)` mean the session needs input
- tab titles can fall back to the current directory if no better agent name is visible

The app also polls tmux for `pane_current_path` so tabs stay labeled by actual working directory.

This is exactly the sort of desktop integration that should stay lightweight. If the agent tools expose richer state later, great. Until then, the terminal is the API.

= Notifications

Once the app can tell the difference between working and waiting, notifications become useful instead of noisy.

That is the real supervision feature. A coding agent desktop is not mainly about pretty panes. It is about knowing which session needs attention and which ones can be ignored for another ten minutes.

= Why not build a session manager from scratch

Because tmux already solved the boring, durable, Unix-shaped part of the problem.

A custom backend would need to answer all the same questions again:

- how sessions survive app restarts
- how splits are represented
- how an external shell can attach
- how stdout and stdin multiplexing work
- how recovery behaves after crashes

Using tmux means the app can spend its complexity budget higher up, on workspace UX and agent supervision.

= Notes

There is a pattern here I keep coming back to in agent tooling: keep the execution substrate dumb and durable, then layer richer control on top.

`agentmux` works because it does not try to outsmart the terminal. It just turns tmux into something easier to watch.
