#import "./shim/html.typ": *

#set document(
  title: "Clawpatrol for personal agents",
  date: datetime(day: 21, month: 5, year: 2026),
  description: "Set up a Clawpatrol gateway for Claude, GitHub, and Slack without putting long-lived tokens on agent machines.",
)

#show: html-shim

#nav-bar()

#title()

#show heading.where(level: 1): it => {
  html.elem("h2", attrs: (class: "!text-foreground"), it.body)
}

I have been running coding agents in tmux on small VMs. The useful version of
that setup needs access to GitHub, Slack, Claude, and sometimes SSH.

The simple way to do this is to copy `GH_TOKEN`, `SLACK_BOT_TOKEN`, and Claude's
local auth state onto the worker. That works, but it makes the worker the
security boundary. Any subprocess the agent starts can read the same environment
or config files.

Clawpatrol is a gateway for moving those credentials out of the worker process.

#figure(
  image("/static/img/clawpatrol-agent-gateway.svg", width: 100%),
)

The agent still runs the normal CLI. Locally it sees placeholder environment
variables and a proxy CA. The gateway terminates the connection, matches the
request against an endpoint/profile/rule set, and injects the real credential
only for that upstream request.

= Install the gateway

Start with one small VM that can run a Go binary and stay online. I usually put
the gateway on Tailscale so the dashboard is not on the public internet. The
same config works behind a normal HTTPS reverse proxy.

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

The `tailscale` block makes the gateway create its own tsnet node. It is also
used by `clawpatrol join` so worker machines can be added without copying
WireGuard keys manually. The OAuth values are read through `{{secret:...}}` from
the systemd environment, not stored in the HCL file.

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

= Define what the agent can reach

Endpoints are network destinations. Credentials describe which auth mechanism
can be attached to traffic for that destination.

For my personal agent setup, the first three endpoints are Claude, GitHub, and
Slack:

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

credential "anthropic_oauth_subscription" "claude" {
  endpoint = https.anthropic
}

credential "github_oauth" "github" {
  endpoint = https.github-api
}

credential "slack_tokens" "slack" {
  endpoint = https.slack-api
}
```

These blocks do not contain the actual OAuth tokens. They define credential
slots. The dashboard is where the real credentials get connected.

I keep one profile per agent identity:

```hcl
profile "personal" {
  credentials = [
    anthropic_oauth_subscription.claude,
    github_oauth.github,
    slack_tokens.slack,
  ]
}
```

Profiles are what the worker binds to. When a machine joins with
`--profile personal`, the gateway only pushes the placeholder env vars needed
for the credentials in that profile. A different `work` or `bot` profile can use
another GitHub account, another Slack bot, or no Slack credential at all.

= Add rules

Credentials answer "how would this request authenticate?". Rules answer "is
this request allowed to use that credential?".

A useful first policy is:

- allow reads
- require approval for writes
- deny everything else by default

For GitHub:

```hcl
approver "human_approver" "me" {
  channel     = "#agent-approvals"
  credential  = slack_tokens.slack
  interactive = true
}

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

For Slack, reads and websocket traffic can pass, but posting messages should be
reviewed:

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

And then a default deny:

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

With those rules, the agent can inspect GitHub and read Slack context. Writes go
through the Slack approver before the gateway forwards the request.

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

The worker still does not get the tokens. It gets placeholder values that make
the upstream CLIs choose the auth path Clawpatrol expects.

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

For an automated worker, wrap the command directly:

```sh
clawpatrol run claude --dangerously-skip-permissions
```

The dangerous bit there is Claude's local permission bypass. Clawpatrol only
controls network access and credential injection.

= Runtime behavior

With the config above, this is what changes at runtime:

- Claude can use its subscription without a Claude OAuth token sitting in
  `~/.claude` on the worker.
- GitHub API requests are authenticated at the gateway.
- GitHub writes hit the approval rule.
- Slack message sends hit the approval rule.
- Unmatched GitHub and Slack requests are denied by the default rules.

This is not a sandbox for local filesystem access. If the agent can read a file
on disk, Clawpatrol does not change that. It is specifically the network and
credential boundary for processes run under `clawpatrol run`.

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
profile = who the agent is
endpoint = what service it is talking to
credential = how the gateway authenticates
rule = what the agent is allowed to do
approver = who can override a risky action
```

Once those are separate, the agent machine becomes easier to reason about. You
can rotate a GitHub credential without touching workers. You can move a worker
from `personal` to `readonly`. You can add approval to Slack writes without
changing the agent prompt.

The CLI invocation stays boring:

```sh
clawpatrol run claude
```

The interesting part is all in the gateway config.
