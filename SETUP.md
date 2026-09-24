# Redgate Monitor: install and setup guide

## What this covers

A self-hosted Redgate Monitor trial for a personal setup, monitoring a small
SQL Server estate (fewer than 10 instances). This is the prerequisite for
`README.md` in this repo — the PowerShell config-as-code API only works
against a self-hosted instance, not Monitor SaaS, so self-hosted is the
right call for what you're doing here anyway.

## Before you start

At this scale, everything — web interface, base monitor, repository — can
run on one machine. That's a reasonable choice at this size, not a shortcut.

- **A Windows machine/VM** to install the base monitor, web interface and repository on.
- **A repository database.** Either SQL Server (needs its own license — Express edition works but hits its size limit fast for anything beyond a short trial) or PostgreSQL with TimescaleDB (open source, but the base monitor/web UI still need a place to run — TimescaleDB itself is Linux-only).
- **A service account** for the base monitor, and a monitoring account for the SQL Server instances you'll add. Administrative rights on those instances are the simple path but not required — least privilege is documented and supported. One exception: the integrity-check collector needs elevated rights and will sit in permanent error under a least-privilege account. If you hit that, disable that specific collector rather than escalating the account.
- **Network path**: browser → web interface, base monitor → repository, base monitor → each SQL Server instance. Port numbers can change between versions — check the current [installation documentation](https://documentation.red-gate.com/monitor) rather than hardcoding them here.
- **The trial itself**: start from [the trial page](https://www.red-gate.com/products/redgate-monitor/trial/) — it will walk you through downloading the installer.

If you'd rather look before installing anything, the [live public demo](https://monitor.red-gate.com/) needs no install and no form.

## Install and first connection

1. Run the installer, which sets up the base monitor, repository and web interface.
2. Open the web interface and add **one** SQL Server instance first. Stop there before adding more — a first connection is the cheapest point to catch an authentication or network problem, before it's multiplied across the rest of your estate.
3. Once that one instance is showing data, add the rest.

## Add the estate

For an estate this size, a simple tag by purpose (e.g. `dev`, `test`) is
enough — you don't need a formal grouping strategy at under 10 instances.
That said, since you're managing this as config-as-code, it's worth naming
your groups deliberately now: whatever you call them in the Monitor UI is
what ends up in `config/monitor-config.yaml`, and renaming groups later is
more annoying than naming them right the first time.

## Alerting: get to sensible defaults before automating them

Since the point of this repo is to manage alert settings as code, get
Monitor's defaults into a state you're happy with by hand first, then
export that as your YAML baseline (`./scripts/Export-MonitorConfig.ps1`)
rather than guessing at settings in YAML before you've seen real alerts:

1. Leave notifications off for a few days and let alerts accumulate.
2. Sort by count — the top few alert types are the ones worth tuning; leave the rest.
3. Tune structurally: thresholds at the group level, exclude a specific noisy disk/database by name rather than disabling an alert everywhere, use suppression windows for anything expected (e.g. a nightly backup job).
4. Turn notifications on once the noise is under control.

## Honest limits worth knowing before you rely on this

- **No repeated reminder while an alert stays active** — Monitor notifies once when an alert raises, it doesn't keep nagging. If "we missed one email" is a real risk for you, route into a paging tool via webhook instead of relying on email alone.
- **A suppression window silences its whole scope, not one alert type within it.** You can't say "mute only the expected maintenance alerts, keep everything else live" as a single window.

## Getting the PowerShell API access token (for this repo's config-as-code scripts)

Once Monitor is installed and at least one instance is added:

1. In the web interface, go to **Configuration → API**.
2. Download the Redgate Monitor PowerShell module from that page and install it (or note its path for the `RGM_MODULE_PATH` env var used by `scripts/Connect-Monitor.ps1`).
3. Generate an access token on the same page.
4. Set the environment variables described in this repo's `README.md`:
   ```powershell
   $env:RGM_SERVER_URL   = "https://<your-machine>:8080"
   $env:RGM_ACCESS_TOKEN = "<token from step 3>"
   ```
5. Run `Install-Module powershell-yaml -Scope CurrentUser` if you haven't already — the YAML conversion isn't part of Monitor's own module.

From here, `./scripts/Export-MonitorConfig.ps1` will pull your hand-tuned
config into `config/monitor-config.yaml` as your starting point.

## Where to go next

- [Introduction to Redgate Monitor](https://www.red-gate.com/hub/university/courses/redgate-monitor/) and *Overview of Redgate Monitor GUI* — free Redgate University courses, worth watching before your first working session.
- [Introduction to Configuring Metrics and Alerts](https://www.red-gate.com/hub/university/courses/redgate-monitor/) — watch before tuning alerting.
- [Documentation home](https://documentation.red-gate.com/monitor) for anything version-specific this guide didn't pin down on purpose.
- [Feature request forum](https://sqlmonitor.uservoice.com/forums/91743-suggestions) if you hit a gap during setup.
