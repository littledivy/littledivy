#import "./shim/html.typ": *

#set document(
  title: "orchid: github issues as an agent scheduler",
  date: datetime(day: 19, month: 5, year: 2026),
  description: "orchid turns GitHub issues into agent-owned pull requests.",
)

#show: html-shim

#nav-bar()

#title()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

orchid is a small issue-to-PR scheduler for coding agents.

The interface is GitHub issues. Open an issue in an inbox repo, add a label for
the target repo, and orchid starts a coding session in a tmux pane. The agent
clones the work repo, implements the issue, pushes a branch, opens a PR, then
waits. orchid keeps polling GitHub and feeds review comments, CI state, and PR
updates back into the same pane until the PR merges or closes.

There are no webhooks. It is one Go binary, one HCL file, tmux, ssh, `gh`, and a
JSON state file.

```
issue in denoland/orchid
  label: deno
      |
      v
orch polls inbox
      |
      v
select free VM/session slot
      |
      v
tmux new -s claude-143
      |
      v
paste bootstrap prompt
      |
      v
agent opens denoland/deno PR
      |
      v
orch relays CI/reviews/comments
```

= Why GitHub issues

GitHub issues are a good queue format because they are already the unit of work
most maintainers use.

An issue has a title, body, comments, labels, timestamps, actors, and cross-links.
That is enough to describe most coding tasks. More importantly, the resulting PR
has the same review and CI machinery humans already trust.

The important trick is that the issue is not in the work repo. orchid uses an
inbox repo as the scheduler queue:

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

An issue labeled `deno` becomes a branch and PR in `denoland/deno`. An issue
labeled `clawpatrol` becomes a branch and PR in `denoland/clawpatrol`.

This gives the operator one place to queue work without spreading agent-control
state across every repo.

= The loop

orchid runs one poll loop. On each tick it does roughly this:

```
for issue in open inbox issues:
  if issue already has a job:
    continue
  target = target_from_labels(issue.labels)
  vm = find_vm_with_free_capacity()
  spawn_tmux_session(vm, issue, target)

for job in state.jobs:
  if job has no PR yet:
    discover_pr(job.branch)
  else:
    relay_new_reviews(job)
    relay_new_issue_comments(job)
    relay_check_changes(job)
    teardown_if_pr_closed_or_merged(job)
```

The state file is the source of truth for in-flight jobs:

```json
{
  "jobs": {
    "143": {
      "vm": "local",
      "tmux": "claude-143",
      "target_repo": "denoland/deno",
      "branch": "orch/divybot-143",
      "pr": 34231,
      "last_head_oid": "..."
    }
  }
}
```

That makes restarts boring. If the process dies, restart it. Existing tmux panes
keep running, and orchid reloads the state file to reconnect jobs to PRs.

= Bootstrap prompt as ABI

The only interface between orchid and the agent is text pasted into a terminal.

That sounds crude, but it is useful. The agent does not need an SDK, a daemon,
or a custom protocol. The bootstrap prompt is the ABI:

```
You are implementing GitHub issue #{{issue.number}}:
"{{issue.title}}"

Work repo: {{target.repo}}
Clone: {{workdir}}
Branch: {{branch}}

--- issue body ---
{{issue.body}}
--- end issue body ---

Commit, push, open a PR, then stop and wait.
```

The session is stateful because the terminal is stateful. If CI fails, orchid
pastes the failed checks into the same pane. If a human leaves a review comment,
orchid pastes that too. The agent can inspect its own worktree, amend commits,
push again, and stop.

This avoids the common "agent as stateless function call" problem. Coding work is
not one request. It is a little process with memory, filesystem state, logs,
review feedback, and retries.

= tmux is the worker runtime

Each worker is just a tmux session. That gives orchid a cheap process supervisor
and an inspection surface:

```sh
tmux capture-pane -p -t claude-143 -S -80
tmux send-keys -t claude-143 "..." Enter
```

The dashboard is mostly a thin view over this. It shows the jobs, linked PRs,
last known check conclusions, and a pane view so the operator can look at what an
agent is actually doing.

This is intentionally low tech. tmux is easier to debug than a custom worker
protocol. If something is weird, capture the pane. If a session is wedged, kill
that pane. If orchid dies, panes survive.

= Polling instead of webhooks

Webhooks are tempting until the first time you need to run the whole system from a
laptop, a VM behind a VPN, or a tailnet-only service.

orchid polls GitHub every 30 seconds using `gh`. That is not elegant, but it has
nice properties:

- no public callback URL
- no webhook secrets
- no replay logic
- no separate delivery queue
- local development is the same as production

The price is latency. A review comment may take one tick to reach the pane. That
is fine for PR work.

= Capacity is the scheduler

A VM block declares how many concurrent sessions it can run:

```hcl
vm "local" {
  host        = "localhost"
  capacity    = 6
  session_cmd = "clawpatrol run -- claude --dangerously-skip-permissions"
}
```

When all slots are full, new issues simply stay queued:

```
issue #139: no free VM, skipping
```

This is enough scheduling for the current shape of work. Most tasks are bounded
PR-sized chunks: fix a node compat edge case, add a test, address a review, mark
a test as expected-failure instead of ignored.

The unit of parallelism is the GitHub issue. The unit of completion is the PR.

= Failure modes

The nice part of building the scheduler out of boring pieces is that failures are
usually legible.

If GitHub is flaky, `gh` fails and orchid retries transient network errors. If a
session dies, orchid can respawn it. If the orchestrator dies, systemd restarts
it and state reloads from disk. If an agent opens a PR but forgets to reference
the inbox issue, orchid can still discover the PR by branch name.

There are also less obvious failure modes:

- killing the orchestrator process must not kill all tmux panes
- killing all panes at once can stampede the network relay on restart
- PR close/merge in the work repo is not the same as closing the inbox issue
- CI result changes need deduping, otherwise the same failure gets pasted forever
- a human may already be working on the same code path

The current implementation handles these with small pieces of state:

```
seen_review_ids
seen_issue_comment_ids
last_head_oid
last_check_conclusions
```

It is not a distributed system. It is a single process remembering what it has
already told each pane.

= Where clawpatrol fits

The worker command can run under `clawpatrol`.

That lets each agent session get network access through a controlled path instead
of sharing the host's ambient network. In practice this matters more than the
scheduler. Once agents can run real commands, clone repos, talk to GitHub, and
execute tests, the interesting question is not "can they code?" It is "what can
they reach?"

orchid only decides when to start work and where to send feedback. clawpatrol is
the boundary around what the worker can do while it is working.

= The shape that works

orchid works best when the operator feeds it issues that are real but narrow.

Bad:

```
make node compatibility better
```

Good:

```
node compat: allow --inspect host localhost for inspector port-zero test
node compat: implement KeyObject structured clone over MessagePort
node compat: emit enough inspector Network events for HTTP/fetch tests
```

Agents are much more useful when they can spend their context on the codebase
instead of guessing the task boundary.

The human still owns taste, priority, and merge decisions. orchid owns the
mechanical loop: allocate a worker, keep the worker fed with review/CI state, and
free the slot when the PR is done.

= What I like about it

The whole system is deliberately unmagical.

GitHub is the queue. Labels are routing. tmux is the worker runtime. The terminal
is the agent protocol. A JSON file is durable state. The dashboard is an
inspection layer, not the source of truth.

That makes it easy to operate while half asleep:

```sh
systemctl is-active orchid
tmux ls
tail -20 orch.log
```

There is a lot more to do: better overlap detection, better PR review routing,
more worker types, cron-style jobs, stronger sandbox defaults. But the useful
core is already small:

open issue, get PR, review PR, merge, repeat.
