# vpsguard-action

Audit your Linux VPS fleet's security posture from CI/CD, using
[vpsguard](https://github.com/salamancacm/vpsguard).

```yaml
name: VPS security audit
on:
  schedule:
    - cron: "0 6 * * *" # daily at 06:00 UTC
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: salamancacm/vpsguard-action@v1
        with:
          hosts: web-1.example.com,db-1.example.com
          ssh-user: root
          ssh-key: ${{ secrets.VPS_SSH_KEY }}
          ssh-known-hosts: ${{ secrets.VPS_KNOWN_HOSTS }}
          fail-on: CRIT
```

This installs vpsguard on the runner, connects to each host over SSH
(your key, never vpsguard's), runs `vpsguard audit` on each one, and:

- Writes a summary table to the workflow's job summary
- Fails the job if any finding at or above `fail-on`'s severity exists
  (default `CRIT`)
- Exposes `crit-count`, `warn-count`, and `unreachable-count` as outputs

vpsguard must already be installed on every target host — this action
doesn't bootstrap it remotely, same as `vpsguard fleet` itself. See
[vpsguard's install docs](https://github.com/salamancacm/vpsguard#installation).

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `ssh-key` | yes | | SSH private key used to connect to the hosts |
| `hosts` | one of `hosts`/`config` | | Comma-separated host addresses |
| `ssh-user` | no | `root` | SSH user for all `hosts` |
| `ssh-port` | no | `22` | SSH port for all `hosts` |
| `ssh-known-hosts` | no (strongly recommended) | | Contents for `~/.ssh/known_hosts`, e.g. from `ssh-keyscan`. Without it, host keys are trusted on first connection. |
| `config` | one of `hosts`/`config` | | Path to a full vpsguard `config.yaml` in your repo instead of `hosts`/`ssh-user`/`ssh-port` — use this for `disabled_checks`, `thresholds`, or per-host ports |
| `vpsguard-version` | no | `latest` | Pin a specific vpsguard release, e.g. `v0.4.1` |
| `fail-on` | no | `CRIT` | `CRIT`, `WARN`, or `NONE` |

## Outputs

| Output | Description |
|---|---|
| `crit-count` | Total CRIT findings across all hosts |
| `warn-count` | Total WARN findings across all hosts |
| `unreachable-count` | Hosts that could not be reached |

## Getting `ssh-known-hosts`

```bash
ssh-keyscan web-1.example.com db-1.example.com
```

Paste the output into a repo/org secret and reference it as
`ssh-known-hosts`. Skipping this trusts each host's key on first
connection (`StrictHostKeyChecking=accept-new`) — acceptable for a quick
demo, not for anything that matters.

## Requirements

- `jq`, preinstalled on GitHub-hosted runners. Self-hosted runners need
  it installed separately.
- vpsguard already installed on every target host.

## License

MIT
