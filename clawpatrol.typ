#import "./shim/html.typ": *

#set document(
  title: "Clawpatrol rules for personal agents",
  date: datetime(day: 21, month: 5, year: 2026),
  description: "Using Clawpatrol rules to put a network policy boundary around personal coding agents.",
)

#show: html-shim

#nav-bar()

#title()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

I run coding agents in tmux on small VMs. They need real network access:
GitHub for PRs, Slack for notifications, Postgres for application state, Claude
for model calls.

Putting tokens on the gateway is useful, but it is not the whole problem. A
hidden Postgres password still does not help if the gateway forwards `DROP TABLE
users`.

The part of Clawpatrol I care about most is rules. It sits between an agent
process and the network, decodes protocol traffic, and evaluates policy before
the request reaches the upstream service.

#figure(
  image("/static/img/clawpatrol-agent-gateway.svg", width: 100%),
)

The screenshot above is the whole point: the agent tried a Postgres command,
the gateway decoded the SQL, matched a rule, and returned an error before the
operation reached the database.

= The boundary

`clawpatrol run` wraps one process tree. On Linux it starts the command in a new
network namespace and hands a TUN fd to a per-host daemon. The daemon sends that
traffic to the gateway over the transport chosen at `join` time. Other processes
on the host keep their normal network path.

```sh
clawpatrol run claude
```

My personal setup uses Tailscale mode. The gateway embeds a tsnet node and the
worker daemon joins the tailnet with a persisted auth key. WireGuard mode is the
other option, but the rule layer is the same once traffic reaches the gateway.

```hcl
gateway {
  dashboard_listen = "127.0.0.1:8080"
  public_url       = "https://clawpatrol.example.ts.net"
  state_dir        = "/var/lib/clawpatrol"

  tailscale {
    funnel = true

    oauth_client_id     = "{{secret:TS_OAUTH_CLIENT_ID}}"
    oauth_client_secret = "{{secret:TS_OAUTH_CLIENT_SECRET}}"
    tags                = ["tag:bot"]

    operators = ["you@example.com"]
  }
}
```

`funnel = true` exposes the public onboarding and OAuth callback routes. The
dashboard can still live on the tailnet. The OAuth values above are loaded from
the process environment through `{{secret:...}}`; they are not stored in the HCL
file.

= Endpoints

Endpoints describe the services the agent may talk to. I keep them small and
named by intent.

```hcl
endpoint "https" "anthropic" {
  hosts = ["api.anthropic.com"]
}

endpoint "https" "github-api" {
  hosts = ["api.github.com", "raw.githubusercontent.com", "github.com"]
}

endpoint "https" "slack-api" {
  hosts = ["slack.com", "api.slack.com", "wss-primary.slack.com"]
}

endpoint "postgres" "pg-dev" {
  host = "pg-dev.internal:5432"
}
```

= Credentials

Credentials are slots on the gateway side. They do not put the real token or
password on the worker.

```hcl
credential "anthropic_oauth_subscription" "claude" {
  endpoint = https.anthropic
}

credential "github_oauth" "github" {
  endpoint = https.github-api
}

credential "slack_tokens" "slack" {
  endpoint = https.slack-api
}

credential "postgres_credential" "pg-dev" {
  endpoint = postgres.pg-dev
  user     = "agent"
}
```

A profile binds a worker to a credential set:

```hcl
profile "personal" {
  credentials = [
    anthropic_oauth_subscription.claude,
    github_oauth.github,
    slack_tokens.slack,
    postgres_credential.pg-dev,
  ]
}
```

A `readonly` profile can omit the Postgres writer or Slack credential without
changing the worker VM:

```hcl
profile "readonly" {
  credentials = [
    anthropic_oauth_subscription.claude,
    github_oauth.github,
  ]
}
```

= SQL rules

Rules are the important part. A rule targets an endpoint, optionally narrows by
credential, evaluates a CEL condition over decoded request facets, and returns
`allow`, `deny`, or an approval flow.

For Postgres, the gateway reads the wire protocol and exposes `sql.verb`,
`sql.tables`, `sql.functions`, `sql.statement`, and `sql.database` to rules.
This is the rule that matches the screenshot:

```hcl
rule "pg-no-destructive-ddl" {
  endpoint  = postgres.pg-dev
  priority  = 100
  condition = <<-CEL
    sql.verb in ['drop', 'truncate', 'alter']
  CEL
  verdict = "deny"
  reason  = "destructive sql; drop users table not allowed"
}
```

Add a second deny for database-side filesystem/network escape hatches:

```hcl
rule "pg-banned-functions" {
  endpoint = postgres.pg-dev
  priority = 100
  condition = <<-CEL
    sets.intersects(sql.functions, [
      'pg_read_file', 'pg_read_binary_file', 'lo_get',
    ])
    || sql.functions.exists(f, f.startsWith('dblink_'))
  CEL
  verdict = "deny"
  reason  = "filesystem-reaching function"
}
```

Reads can be allowed explicitly:

```hcl
rule "pg-reads" {
  endpoint  = postgres.pg-dev
  condition = "sql.verb in ['select', 'show', 'explain', 'describe']"
  verdict   = "allow"
}
```

Mutations can go through a human:

```hcl
approver "human_approver" "me" {
  channel     = "#agent-approvals"
  credential  = slack_tokens.slack
  interactive = true
}

rule "pg-mutations" {
  endpoint  = postgres.pg-dev
  condition = "sql.verb in ['insert', 'update', 'delete', 'merge', 'notify']"
  approve   = [human_approver.me]
  reason    = "Postgres mutations require review"
}
```

Then make unknown SQL fail closed:

```hcl
rule "pg-default" {
  endpoint = postgres.pg-dev
  priority = -100
  verdict  = "deny"
  reason   = "unknown SQL verb"
}
```

That gives me a simple posture:

```text
SELECT        -> allow
INSERT        -> ask
DROP          -> deny
unknown verb  -> deny
```

= HTTP rules

The same rule shape works for HTTP. For GitHub, reads are cheap and writes are
visible:

```hcl
rule "github-read" {
  endpoint  = https.github-api
  condition = "http.method in ['GET', 'HEAD', 'OPTIONS']"
  verdict   = "allow"
}

rule "github-write" {
  endpoint  = https.github-api
  condition = "http.method in ['POST', 'PUT', 'PATCH', 'DELETE']"
  approve   = [human_approver.me]
  reason    = "GitHub writes need human approval"
}
```

The Slack rule is slightly narrower. Reads and websocket traffic can pass, but
posting messages should be reviewed:

```hcl
rule "slack-read" {
  endpoint = https.slack-api
  condition = <<-CEL
    http.method in ['GET', 'HEAD', 'OPTIONS']
    || http.host == 'wss-primary.slack.com'
  CEL
  verdict = "allow"
}

rule "slack-chat-write" {
  endpoint = https.slack-api
  condition = <<-CEL
    http.method == 'POST'
    && http.path.startsWith('/api/chat.')
  CEL
  approve = [human_approver.me]
  reason  = "Slack messages should be reviewed before sending"
}
```

Keep boring default denies for services where surprises matter:

```hcl
rule "github-default" {
  endpoint = https.github-api
  priority = -100
  verdict  = "deny"
}

rule "slack-default" {
  endpoint = https.slack-api
  priority = -100
  verdict  = "deny"
}
```

= Join

On the worker VM:

```sh
curl -fsSL https://clawpatrol.dev/install.sh | sh

clawpatrol join https://clawpatrol.example.ts.net \
  --hostname personal-agent \
  --profile personal
```

Approve the join in the browser. Then run the agent:

```sh
clawpatrol run claude
```

Only that process tree goes through the gateway. Your normal browser, shell,
package manager, and random background processes do not.

= What changes

With the config above, this is what changes at runtime:

- Claude can use its subscription without a Claude OAuth token sitting in
  `~/.claude` on the worker.
- Postgres auth happens at the gateway.
- Postgres `drop`, `truncate`, and `alter` statements are denied before they
  reach the database.
- GitHub writes and Slack message sends hit the approval rule.
- Unmatched requests for configured services are denied by the default rules.

This is not a filesystem sandbox. If the agent can read a file on disk,
Clawpatrol does not change that. It is a network and policy boundary for
processes run under `clawpatrol run`.

= Test the policy

Clawpatrol configs are just files, so put them in git and test them.

```sh
clawpatrol validate ./personal.hcl
```

I keep rule fixtures next to the config:

```text
tests/
  pg_drop_users.json
  pg_select_users.json
  github_post_issue.json
```

Then run:

```sh
clawpatrol test ./personal.hcl ./tests
```

This matters because the config is code in the path of every agent request. A
bad rule can block the agent at runtime or allow a write that was supposed to be
gated.

= Mental model

The useful model is:

```text
endpoint = what service it is talking to
rule = what the agent is allowed to do
credential = how the gateway authenticates upstream
profile = which credentials this device may use
approver = who can override a risky action
```

Once those are separate, the agent machine becomes easier to reason about. You
can tighten a SQL rule without touching the worker. You can rotate a GitHub
credential without touching workers. You can move a worker from `personal` to
`readonly` by changing its profile.

The CLI invocation stays boring:

```sh
clawpatrol run claude
```

The interesting part is all in the gateway config.
