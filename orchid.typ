#import "./shim/html.typ": *

#set document(
  title: "orchid: github issues as an agent scheduler",
  date: datetime(day: 19, month: 5, year: 2026),
  description: "Orchid turns GitHub issues into isolated coding-agent sessions that produce pull requests.",
)

#show: html-shim

#nav-bar()

#title()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

#let chip(body) = html.elem("span", attrs: (class: "orchid-chip"), body)
#let arrow() = html.elem("span", attrs: (class: "orchid-arrow"), [→])
#let a(href, body) = html.elem("a", attrs: (href: href), body)

#html.elem("section", attrs: (class: "orchid-lede"), [
  #html.elem("p", [
    Orchid is a small scheduler for coding agents. The input is a GitHub issue.
    The runtime is a tmux session. The output is a pull request.
  ])
])

I wanted a way to run a lot of coding agents without building a new product for
them to live in.

A coding agent needs more than a prompt. It needs a repository checkout, a
branch, credentials, a terminal, CI feedback, review comments, and some way to
remember which process is working on which task.

That can turn into a whole orchestration platform very quickly: a job queue, a
database, a worker protocol, a web UI, a log viewer, a webhook receiver, retry
logic, and an admin surface to debug all of it.

Orchid is the version that tries very hard to not become that.

#html.elem("div", attrs: (class: "orchid-flow"), [
  #chip([issue])
  #arrow()
  #chip([label])
  #arrow()
  #chip([tmux])
  #arrow()
  #chip([branch])
  #arrow()
  #chip([pull request])
])

Open an issue. Add a label. Orchid creates a worktree, starts an agent, lets it
push a branch, finds the PR, relays CI and review feedback back into the same
terminal, and frees the slot when the PR is closed.

It is a Go binary wrapped around `gh`, `git`, `ssh`, and `tmux`. The durable
state is a JSON file. The config is HCL. There are no webhooks.

= GitHub issues are the queue

If you are building a scheduler, the obvious first step is to add a queue.

For Orchid, GitHub issues already are the queue.

An issue has a title, body, author, labels, comments, timestamps, notification
rules, permissions, and links to pull requests. That is the shape of a coding
task. A separate queue would mostly duplicate that state and then need to stay
in sync with GitHub anyway.

So Orchid uses one repository as an inbox. Labels decide where work should run:

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

An issue in the inbox with the `deno` label becomes a branch in
`denoland/deno`. An issue with the `clawpatrol` label becomes a branch in
`denoland/clawpatrol`.

The important part is that the target repo stays normal. Humans still review
PRs in the repo they already use. CI still runs in GitHub Actions. Review
comments are still GitHub review comments. Orchid only connects the inbox issue
to a worker session.

The work item is not hidden in a scheduler database. It is a URL you can paste
to another person.

= A worker is a terminal

The smallest useful worker interface for a coding agent is a terminal.

That sounds too simple, but it is the right abstraction. Real coding work is not
a single request/response. The agent runs tests, reads files, edits patches,
waits for commands, hits rate limits, watches CI fail, amends commits, and
pushes again.

A terminal keeps all of that context in one place.

When Orchid assigns an issue, it creates a worktree and starts a tmux session:

```sh
tmux new-session -d \
  -s claude-151 \
  -c /home/orchid/orch-work/issue-151 \
  clawpatrol run -- claude --dangerously-skip-permissions
```

Then it pastes the bootstrap prompt:

```text
You are implementing GitHub issue #151:
"node compat: fix async_hooks promise lifecycle for absent tests"

Work repo: denoland/deno
Worktree: /home/orchid/orch-work/issue-151
Branch: orch/divybot-151

--- issue body ---
...
--- end issue body ---

Commit, push, open a PR, then stop and wait.
```

That prompt is the worker protocol.

There is no SDK. No custom RPC channel. No special agent plugin. If a model can
read a terminal and type commands, Orchid can run it.

This also makes debugging boring in a good way:

```sh
tmux capture-pane -p -t claude-151 -S -80
tmux send-keys -t claude-151 "retry the push; github ssh is fixed" Enter
tmux respawn-pane -k -t claude-151 -c /home/orchid/orch-work/issue-151 \
  "clawpatrol run -- claude --resume"
```

The dashboard is convenient, but tmux is the truth. If Orchid restarts, the
agent process keeps running. If the dashboard looks wrong, capture the pane. If
the agent is stuck at an interactive prompt, type into the pane.

= The scheduler loop

Orchid does not need to receive GitHub webhooks. It polls.

The loop is roughly:

```text
for issue in open inbox issues:
  if issue has a target label and no job:
    reserve a slot
    create a worktree
    start a tmux session
    paste the bootstrap prompt
    write state.json

for job in state.jobs:
  find the PR for its branch
  relay new issue comments
  relay new review comments
  relay new CI transitions
  tear down the job when the PR closes
```

Polling is usually treated like the less serious version of webhooks. For this
system it is better.

Webhooks require a public endpoint, a secret, delivery retries, local
development setup, and another path to debug. Orchid is not trying to react in
milliseconds. A coding agent waiting thirty seconds for a CI update is fine.

The system is easier to reason about when one process asks GitHub what changed
and then decides what to paste into each pane.

= Capacity is explicit

The machine has a fixed number of slots.

```hcl
vm "local" {
  host        = "localhost"
  capacity    = 30
  session_cmd = "clawpatrol run -- claude --dangerously-skip-permissions"
}
```

If all slots are full, Orchid does not invent more capacity:

```text
issue #139: no free VM, skipping
```

That is the backpressure story.

This only works because the tasks are supposed to be small. An issue like
"make node compat good" is not a good swarm task. It has no obvious stop point,
and every failed test can turn into another project.

Good Orchid issues look more like this:

```text
node compat: implement inspector Network domain enough for HTTP/fetch tests
node compat: don't queue Promise destroys in FinalizationRegistry
clawpatrol: bound response bodies read during OAuth device flow
```

The title should already imply the files, the behavior, and the acceptance
condition. Small issues make the agent useful. Large issues make it wander.

= The state file is not the source of truth

Orchid writes a JSON state file, but it is intentionally boring.

It remembers enough to keep talking to the right terminal and avoid repeating
itself:

```json
{
  "jobs": {
    "151": {
      "tmux": "claude-151",
      "target_repo": "denoland/deno",
      "branch": "orch/divybot-151",
      "pr": 34247,
      "last_head_oid": "f65ee970...",
      "last_check_conclusions": {
        "lint title": "SUCCESS",
        "test node_compat (3/3) release linux-x86_64": "FAILURE"
      }
    }
  }
}
```

GitHub is still the source of truth for issues, comments, PRs, branches, and CI.
tmux is the source of truth for the live process. The state file just answers:

- which issue owns this pane?
- which branch did it push?
- which PR did that branch become?
- which comments have already been relayed?
- which CI transitions have already been pasted?

That last bit matters. If a test fails once, the agent should hear about it. If
Orchid restarts, the agent should not get the same failure pasted forever.

= Clawpatrol is the boundary

Orchid decides what should run. It should not decide what the process is allowed
to reach.

Workers run under #a("/clawpatrol", [Clawpatrol]), which puts a network policy
boundary around the agent process.

That split is important. Once an agent can clone repos, run tests, push
branches, open PRs, and read comments, the interesting question is no longer
"can it code?". The question is "what can this process touch while it is
coding?"

Orchid handles scheduling:

```text
issue #165 -> denoland/clawpatrol -> orch/divybot-165 -> PR #568
```

Clawpatrol handles reachability:

```text
api.anthropic.com     allow with credential injection
github.com           allow with GitHub credential
postgres.internal    deny destructive SQL, approve mutations
slack.com            only if the profile has that credential
```

The credentials live at the gateway, not in the worker VM. The agent sees the
network path it needs for the job, but it does not get a pile of long-lived
tokens copied into its home directory.

That is the difference between "run a lot of agents" and "give a lot of agents
all of my credentials".

= The bugs were mostly process bugs

The first version of Orchid had the bugs you would expect from making a real
machine behave like a scheduler.

Do not kill tmux when restarting Orchid.

Do not close the inbox issue just because the work PR moved.

Do not paste the same failing CI result forever.

Do not respawn every stuck pane in one tick and stampede the network.

Do not let a worker sit at Claude's resume picker and call it "running".

Do not assume GitHub inside the agent sandbox resolves the same way as GitHub on
the host.

That last one was especially annoying. The workers were alive. Orchid was
alive. The model was not confused. But `github.com` inside the Clawpatrol
sandbox resolved to a synthetic address, so pushes timed out during SSH banner
exchange.

From the dashboard, it looked like a stuck agent. From tmux, it was just `ssh`
waiting on the wrong network path.

The fix was not prompt engineering. It was fixing the transport: pin GitHub to a
real address inside the sandbox, clean `known_hosts`, and retry the pushes.

Most "agent reliability" problems I have hit look like this. The model is the
weird new part, so it gets blamed first. Usually the bug is a stale process, a
missing credential, a bad remote, a flaky test, or a command still running in
the background.

= What Orchid actually buys

Orchid does not remove review. It removes babysitting.

The human still chooses which issues exist, how narrow they are, what good taste
looks like, and when a PR should merge.

Orchid owns the loop that is boring to do by hand:

#html.elem("div", attrs: (class: "orchid-mantra"), [
  open issue → spawn pane → get PR → relay feedback → free slot
])

That is enough machinery for a swarm.
