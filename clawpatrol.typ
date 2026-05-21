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

Agents become useful when they can use the same tools you use: GitHub, Slack,
Claude, maybe SSH. The awkward part is that those tools are made of credentials.

The common setup is to put `GH_TOKEN`, `SLACK_BOT_TOKEN`, and whatever Claude
auth state your CLI needs directly on the machine where the agent runs. That is
simple, but it is also a bad boundary. The agent, every subprocess it starts,
every shell snapshot, and every accidental log line can now touch those secrets.

Clawpatrol moves that boundary to a gateway.

#figure(
  image("/static/img/clawpatrol-agent-gateway.svg", width: 100%),
)

The agent still runs the normal CLI. The difference is that it gets placeholder
environment variables locally. The real tokens live at the gateway and are
injected into requests only when traffic matches a configured endpoint and
profile.

= Install the gateway

Start with one small VM that can run a Go binary and stay online. I like putting
the gateway on a private network reachable over Tailscale, but the shape is the
same if you expose it through a normal HTTPS reverse proxy.

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

The `tailscale` block lets the gateway own its tailnet identity in-process. It
also gives `clawpatrol join` clients a way to onboard without manually copying
WireGuard keys around. The OAuth secret values come from a systemd environment
file, not from the config itself.

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

Endpoints are network destinations. Credentials are the identities Clawpatrol
can inject for those destinations.

For a personal coding agent, the useful starter set is Claude, GitHub, and
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

This does not put any actual OAuth token in the HCL file. The blocks define
slots. You connect the real credentials from the dashboard.

I usually keep one profile per agent identity:

```hcl
profile "personal" {
  credentials = [
    anthropic_oauth_subscription.claude,
    github_oauth.github,
    slack_tokens.slack,
  ]
}
```

Profiles are the important part. When a machine joins with
`--profile personal`, it gets exactly the credentials named by that profile. If
you later make a `work` profile or a `bot` profile, those can have different
GitHub accounts, different Slack bots, or no Slack access at all.

= Add rules

Credentials answer "can this agent authenticate?". Rules answer "should this
request be allowed?".

A good first rule set is boring:

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

Now the agent can inspect GitHub issues and read Slack context, but it cannot
open a PR, edit an issue, or send a Slack message without you clicking approve.

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

The local agent machine still does not get those tokens. It only gets the
placeholder values Clawpatrol needs to make the upstream CLIs take the right
auth path.

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
clawpatrol run -- claude
```

Only that process tree goes through the gateway. Your normal browser, shell,
package manager, and random background processes do not.

For an automated worker, wrap the command directly. This is the shape I use for
agent workers:

```sh
clawpatrol run -- claude --dangerously-skip-permissions
```

The dangerous bit there is Claude's own local permission bypass. Clawpatrol is
the network and credential boundary around it.

= What this buys you

The practical win is not that the agent becomes powerless. It is the opposite:
you can give it useful access without making the agent box a secret warehouse.

With the config above:

- Claude can use its subscription without a Claude OAuth token sitting in
  `~/.claude` on the worker.
- GitHub API requests are authenticated at the gateway.
- GitHub writes can require approval.
- Slack message sends can require approval.
- The rules are in one HCL file instead of scattered through prompts.

This is especially nice for long-running personal agents. You can leave a VM
online, let agents work in tmux, and still keep the real credentials somewhere
central, auditable, and revocable.

= Test the policy

Clawpatrol configs are just files, so put them in git.

```sh
clawpatrol validate ./personal.hcl
```

For rules, add fixtures and run:

```sh
clawpatrol test ./personal.hcl ./tests
```

That part matters more than it sounds. Once an agent depends on a gateway, the
config is production code. A bad rule can either block the agent at the worst
time or accidentally allow a write you meant to gate.

= The mental model

Do not think of Clawpatrol as "a proxy that hides tokens". That is only the
mechanism.

The nicer mental model is:

```text
profile = who the agent is
endpoint = what service it is talking to
credential = how the gateway authenticates
rule = what the agent is allowed to do
approver = who can override a risky action
```

Once those are separate, personal agents get much easier to reason about. You
can rotate a GitHub credential without touching worker machines. You can move a
machine from `personal` to `readonly`. You can add approval to Slack writes
without changing your agent prompt.

The agent still feels like a normal CLI. The difference is that the dangerous
part lives at the gateway, where you can see it.
