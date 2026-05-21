#import "./shim/html.typ": *

#set document(
  title: "Clawpatrol for personal agents",
  date: datetime(day: 21, month: 5, year: 2026),
  description: "Set up a Clawpatrol gateway that parses agent traffic, applies rules, and keeps credentials at the gateway.",
)

#show: html-shim

#nav-bar()

#title()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

I have been running coding agents in tmux on small VMs. The useful version of
that setup needs access to real services: GitHub, Slack, Postgres, Claude, SSH.

The risky part is not only where tokens live. It is also what the agent can do
with them. A token hidden behind a proxy is still not enough if the proxy will
forward `DROP TABLE users`.

Clawpatrol is a gateway that sits between the agent process and the network. It
parses protocol traffic, evaluates rules, and keeps upstream credentials on the
gateway side.

#figure(
  image("/static/img/clawpatrol-agent-gateway.svg", width: 100%),
)

The screenshot above is the main thing I care about: the agent tried a Postgres
command, the gateway decoded the SQL, matched a rule, and returned an error
before the operation reached the database.

= How the path works

`clawpatrol run` wraps one process tree. On Linux it starts the command in a new
network namespace and hands a TUN fd to a per-host daemon. The daemon sends that
traffic to the gateway over the transport chosen at `join` time. Other processes
on the host keep their normal network path.

There are two transport modes:

- `wireguard {}`: the gateway mints a WireGuard config. `clawpatrol run` uses it
  for per-process routing. `clawpatrol join --whole-machine` can also install a
  system `wg-quick` interface on Linux.
- `tailscale {}`: the gateway embeds a tsnet node. `clawpatrol run` uses a
  per-host daemon with a tsnet node that joins the tailnet with a persisted
  Tailscale auth key and sets the gateway as the exit node for process traffic.
  No WireGuard keys are copied around in this mode.

Both transports land in the same gateway dispatcher. The dispatcher chooses an
endpoint runtime, parses the request into facets like `http.method` or
`sql.verb`, and either denies, asks for approval, or forwards using the
gateway-held credential for that endpoint.

= Install the gateway

Start with one small VM that can run a Go binary and stay online. For my setup I
use the Tailscale transport, because the gateway can expose onboarding routes
through Funnel while keeping the dashboard on the tailnet.

Install the binary:

```sh
curl -fsSL https://clawpatrol.dev/install.sh | sh
```

Create a config at `/etc/clawpatrol/personal.hcl`:

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

The `tailscale` block makes the gateway create its own tsnet node. `funnel =
true` exposes the small set of public onboarding/OAuth callback routes; the
dashboard itself is still reached over the tailnet or an SSH tunnel. The OAuth
values are read through `{{secret:...}}` from the systemd environment, not stored
in the HCL file.

For example:

```sh
sudo install -d -m 0700 -o clawpatrol -g clawpatrol /var/lib/clawpatrol
sudo tee /var/lib/clawpatrol/secrets.env >/dev/null <<'EOF'
TS_OAUTH_CLIENT_ID=...
TS_OAUTH_CLIENT_SECRET=...
EOF
sudo chmod 0600 /var/lib/clawpatrol/secrets.env
```

A minimal systemd unit is enough:

```ini
[Unit]
Description=clawpatrol gateway
After=network-online.target
Wants=network-online.target

[Service]
User=clawpatrol
Group=clawpatrol
StateDirectory=clawpatrol
StateDirectoryMode=0700
EnvironmentFile=-/var/lib/clawpatrol/secrets.env
ExecStart=/usr/local/bin/clawpatrol gateway /etc/clawpatrol/personal.hcl
Restart=on-failure
RestartSec=2
LimitNOFILE=65536

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Then:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now clawpatrol-gateway
```

= Endpoints and credentials

Endpoints describe network targets. Credentials describe how the gateway should
authenticate to those targets after a rule allows a request.

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

These blocks do not contain the actual token or password. They define slots. The
dashboard is where the real credential material gets connected.

I keep one profile per agent identity:

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

Profiles are what the worker binds to. When a machine joins with
`--profile personal`, requests from that machine can only use credentials in
that profile. A different `readonly` profile can omit the Postgres writer or
Slack credential without changing the worker machine.

= Rules first

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

I usually add a second deny for database-side filesystem/network escape hatches:

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

Reads can be allowed explicitly, and mutations can go through a human:

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

rule "pg-reads" {
  endpoint  = postgres.pg-dev
  condition = "sql.verb in ['select', 'show', 'explain', 'describe']"
  verdict   = "allow"
}

rule "pg-default" {
  endpoint = postgres.pg-dev
  priority = -100
  verdict  = "deny"
  reason   = "unknown SQL verb"
}
```

The same rule shape works for HTTP endpoints. GitHub reads can pass, writes can
require approval:


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

Slack is similar. Reads and websocket traffic can pass, but posting messages
should be reviewed:

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

Then keep boring default denies for services where you care about surprises:

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

= Connect the credentials

Restart or wait for the gateway to reload the config:

```sh
sudo systemctl restart clawpatrol-gateway
```

Open the dashboard:

```text
http://127.0.0.1:8080/
```

or, if you run the dashboard through Tailscale:

```text
http://clawpatrol.example.ts.net:8080/
```

Connect the credential slots:

- `anthropic_oauth_subscription.claude`
- `github_oauth.github`
- `slack_tokens.slack`
- `postgres_credential.pg-dev`

The worker does not get the real token or password. It gets the local CA and
placeholder values needed by the wrapped CLI. The gateway uses the real
credential on its side of the connection, and rules decide which decoded
operations are forwarded.

= Join an agent machine

On the machine where you run Claude:

```sh
curl -fsSL https://clawpatrol.dev/install.sh | sh

clawpatrol join https://clawpatrol.example.ts.net \
  --hostname personal-agent \
  --profile personal
```

Approve the join in the browser. After that:

```sh
clawpatrol run claude
```

Only that process tree goes through the gateway. Your normal browser, shell,
package manager, and random background processes do not.

= Runtime behavior

With the config above, this is what changes at runtime:

- Claude can use its subscription without a Claude OAuth token sitting in
  `~/.claude` on the worker.
- Postgres auth happens at the gateway.
- Postgres `drop`, `truncate`, and `alter` statements are denied before they
  reach the database.
- GitHub writes and Slack message sends hit the approval rule.
- Unmatched requests for configured services are denied by the default rules.

This is not a sandbox for local filesystem access. If the agent can read a file
on disk, Clawpatrol does not change that. It is specifically the network and
policy boundary for processes run under `clawpatrol run`.

= Test the policy

Clawpatrol configs are just files, so put them in git.

```sh
clawpatrol validate ./personal.hcl
```

For rules, add fixtures and run:

```sh
clawpatrol test ./personal.hcl ./tests
```

This matters because the config is code in the path of every agent request. A
bad rule can block the agent at runtime or allow a write that was supposed to be
gated.

= The mental model

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
