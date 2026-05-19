#import "./shim/html.typ": *

#set document(
  title: "orchid: issue driven coding agents",
  date: datetime(day: 19, month: 5, year: 2026),
  description: "orchid turns GitHub issues into agent-owned pull requests.",
)

#show: html-shim

#nav-bar()

#title()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

#let chip(body) = html.elem("span", attrs: (class: "orchid-chip"), body)
#let arrow() = html.elem("span", attrs: (class: "orchid-arrow"), [→])

#html.elem("section", attrs: (class: "orchid-lede"), [
  #html.elem("p", [
    Orchid is what happens when the unit of work is not a prompt, but a pull
    request.
  ])
])

I wanted a bot farm that felt less like operating Kubernetes and more like
filing chores.

The interface is GitHub issues. Open an issue in an inbox repo, label it with the
target repo, and orchid starts a terminal session for an agent. The agent clones
the repo, implements the issue, pushes a branch, opens a PR, and then stops.
orchid keeps watching GitHub and feeds CI, review comments, and new thread
replies back into the same terminal until the PR merges or closes.

#html.elem("div", attrs: (class: "orchid-flow"), [
  #chip([issue])
  #arrow()
  #chip([label])
  #arrow()
  #chip([tmux pane])
  #arrow()
  #chip([branch])
  #arrow()
  #chip([pull request])
])

There are no webhooks. It is one Go binary, one HCL file, `gh`, ssh, tmux, and a
JSON state file. That sounds almost disappointingly boring, which is the point.

= The queue is GitHub

Most agent systems start by inventing a queue.

GitHub already has one. Issues have titles, bodies, comments, labels, authors,
timestamps, cross-links, notifications, and a permission model. PRs already have
review, CI, checks, comments, and merge buttons.

orchid uses an inbox repo as the scheduler. Labels route work to real repos:

```hcl
target "deno" {
  label = "deno"
  repo  = "denoland/deno"
}

target "clawpatrol" {
  label = "clawpatrol"
  repo  = "denoland/clawpatrol"
}
```

An issue labeled `deno` becomes a branch in `denoland/deno`. An issue labeled
`clawpatrol` becomes a branch in `denoland/clawpatrol`. The inbox is just the
dispatch board.

That separation matters. The work repo stays normal. Humans review PRs in the
place they already review PRs. The weird machinery lives off to the side.

= The terminal is the protocol

The only thing orchid sends to a worker is text pasted into a terminal.

```text
You are implementing GitHub issue #143:
"node compat: implement inspector Network domain enough for HTTP/fetch tests"

Work repo: denoland/deno
Clone: /home/orchid/orch-work/143
Branch: orch/divybot-143

--- issue body ---
...
--- end issue body ---

Commit, push, open a PR, then stop and wait.
```

That is the whole ABI.

No SDK. No sidecar daemon. No custom websocket protocol. If the agent can read
the terminal and type commands, it can be a worker.

The useful bit is that the terminal is stateful. Coding is not one model call.
It is a tiny process with a checkout, shell history, failed tests, half-written
patches, and review feedback. When CI fails, orchid pastes the failed check into
the same pane. When a human leaves a PR comment, orchid pastes that too. The
agent can inspect the repo, amend the patch, push again, and go idle.

= tmux is the worker runtime

Each worker is a tmux session.

That makes orchid feel more like a switchboard than a scheduler. The operator can
look through the glass:

```sh
tmux capture-pane -p -t claude-143 -S -80
tmux send-keys -t claude-143 "please address the latest review" Enter
```

The dashboard is intentionally thin: issue number, target repo, branch, PR,
latest checks, and a pane view. If the dashboard lies, tmux is still there. If
the orchestrator dies, tmux is still there. If the agent is doing something
strange, capture the pane.

I like systems where the emergency debugger is also the normal debugger.

= One poll loop

orchid polls GitHub every 30 seconds.

```text
for issue in open inbox issues:
  if issue has no job:
    spawn a pane on a VM with capacity

for job in state.jobs:
  discover PR by branch
  relay new review comments
  relay new CI transitions
  teardown when PR closes
```

Polling is not elegant, but it removes a lot of ceremony:

- no public webhook endpoint
- no webhook secret
- no delivery retry queue
- no local tunnel in development
- no special production topology

The tradeoff is latency. A review comment may take one tick to reach the pane.
For PR work, thirty seconds is fine.

= Capacity is enough scheduling

A VM has a capacity.

```hcl
vm "local" {
  host        = "localhost"
  capacity    = 6
  session_cmd = "clawpatrol run -- claude --dangerously-skip-permissions"
}
```

When all slots are full:

```text
issue #139: no free VM, skipping
```

That line is the entire queue backpressure story.

This works because the tasks are PR-sized. Not "make Node compatibility better",
but:

```text
node compat: allow --inspect host localhost for inspector port-zero test
node compat: implement KeyObject structured clone over MessagePort
node compat: emit enough inspector Network events for HTTP/fetch tests
```

The smaller the issue boundary, the more context the agent can spend on the
actual code.

= The state file is the memory

orchid keeps a small JSON state file:

```json
{
  "jobs": {
    "143": {
      "tmux": "claude-143",
      "target_repo": "denoland/deno",
      "branch": "orch/divybot-143",
      "pr": 34231,
      "last_head_oid": "...",
      "last_check_conclusions": {
        "lint title": "SUCCESS",
        "test node_compat": "FAILURE"
      }
    }
  }
}
```

It remembers what pane belongs to what issue, what branch became what PR, and
which reviews/checks have already been relayed.

This is not a distributed system. It is one process remembering what it has
already said out loud.

= The failure modes are refreshingly physical

The nice thing about boring machinery is that failures have shape.

If GitHub flakes, retry `gh`. If the agent wedges, look at the pane. If the pane
dies, respawn it. If orchid dies, systemd restarts it and the state file points
back to the existing panes.

The annoying bugs were the physical ones:

- do not kill tmux when restarting orchid
- do not respawn every dead pane in one tick and stampede the network relay
- do not paste the same failing CI result forever
- do not close the inbox issue just because the work PR moved
- do not let two agents and a human unknowingly edit the same area

Those are not model problems. They are operator problems.

= Where clawpatrol fits

The worker command can run under `clawpatrol`.

That matters because once agents can clone real repos, run tests, and talk to
GitHub, the question stops being "can it code?" and becomes "what can it reach?"

orchid schedules the work. clawpatrol narrows the network and approval boundary
around the worker while it is doing that work.

The two pieces are deliberately separate. orchid should not know how packets are
approved. clawpatrol should not know what a good PR looks like.

= The operator still matters

orchid is not a replacement for review. It is a way to keep many small agents
busy without inventing a new workplace for them.

The human still decides what is worth doing, how narrow the issue should be,
whether the patch is tasteful, and when to merge. orchid owns the boring loop:
allocate a worker, keep it fed with feedback, free the slot when the PR is done.

The part I like is how little new language it adds.

#html.elem("div", attrs: (class: "orchid-mantra"), [
  open issue → get PR → review PR → merge → repeat
])

That is enough.
