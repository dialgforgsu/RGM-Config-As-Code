# RGM Config-As-Code

Manage Redgate Monitor's alert configuration, monitored estate, notification
settings and access rights as a YAML file in git, using Monitor's PowerShell
API.

## Layout

- `config/monitor-config.template.yaml` — a generic, placeholder-only template safe to share/publish. Committed to git.
- `config/monitor-config.yaml` — your real, org-specific config. **Gitignored** — copy the template here and fill it in.
- `scripts/Connect-Monitor.ps1` — shared connection helper (imported by the other two scripts).
- `scripts/Export-MonitorConfig.ps1` — pulls current state from Monitor and writes it to YAML.
- `scripts/Apply-MonitorConfig.ps1` — reads the YAML and pushes it to Monitor.
- `config/base-monitors/example-base-monitor.template.yaml` — template for splitting config into one file per base monitor at scale (see [Scaling to multiple base monitors](#scaling-to-multiple-base-monitors)).
- `scripts/Apply-AllMonitorConfigs.ps1` — applies every real shard under `config/base-monitors/`.
- `pipelines/` — sample CI/CD pipelines that run `Apply-MonitorConfig.ps1` automatically, one folder per platform (see [pipelines/README.md](pipelines/README.md)).

## One-time setup

1. In Redgate Monitor: **Configuration → API**.
   - Download the Redgate Monitor PowerShell module and install it, or note its path for `RGM_MODULE_PATH`.
   - Generate an access token.
   - Note: the PowerShell API is only available for **on-premises** Monitor, not Monitor SaaS.
2. Install the YAML conversion module (Monitor's own module only round-trips JSON in the official examples, so this repo uses the community `powershell-yaml` module for YAML):
   ```powershell
   Install-Module powershell-yaml -Scope CurrentUser
   ```
3. Set environment variables (don't commit these):
   ```powershell
   $env:RGM_SERVER_URL   = "https://your-monitor-server:8080"
   $env:RGM_ACCESS_TOKEN = "<token from step 1>"
   # only needed if the module isn't installed into a default PSModulePath location
   $env:RGM_MODULE_PATH  = "C:\path\to\RedgateMonitor\RedgateMonitor.psd1"
   ```

## Workflow

**First time:** create your real config from the template.
```powershell
Copy-Item config/monitor-config.template.yaml config/monitor-config.yaml
```

**Seed it from an existing instance** (overwrites `config/monitor-config.yaml` with live settings):
```powershell
./scripts/Export-MonitorConfig.ps1
```

**Review/edit `config/monitor-config.yaml`, commit, PR as normal.**

**Apply to Monitor** (dry-run first):
```powershell
./scripts/Apply-MonitorConfig.ps1 -WhatIf
./scripts/Apply-MonitorConfig.ps1
```

## Scaling to multiple base monitors

One Monitor instance (one web interface/repository) can run several base
monitors - typically one per region, data centre, or environment, to spread
collection load or cross network boundaries. The PowerShell API always
connects to the web interface, not to an individual base monitor, so this
doesn't need a separate connection per base monitor - `estate` entries
already name which `baseMonitor` they belong to (see the template).

The thing that actually breaks down at scale is a single
`monitor-config.yaml` growing to cover every base monitor's estate at once:
big diffs, one team's PR touching everyone's alerts, awkward code review.
Once that's a real problem (multiple base monitors, and/or different teams
owning different parts of the estate), split the file instead:

1. Copy `config/base-monitors/example-base-monitor.template.yaml` to
   `config/base-monitors/<base-monitor-name>.yaml` once per base monitor
   (real files are gitignored, same as `config/monitor-config.yaml`).
2. Each shard only lists the groups/estate/alerts/notifications for that
   base monitor's slice of the estate, and can scope `globalSettings.accessRights`
   to that team's own group rather than repeating instance-wide rights
   everywhere.
3. Apply every shard in one pass with `./scripts/Apply-AllMonitorConfigs.ps1
   -WhatIf`, or a single shard with `./scripts/Apply-MonitorConfig.ps1
   -ConfigFile config/base-monitors/<name>.yaml -WhatIf`.

If you genuinely run fully separate Monitor instances (isolated networks,
not just multiple base monitors on one instance), give each shard its own
`serverUrlEnvVar`/`accessTokenEnvVar` pair (e.g. `RGM_SERVER_URL_EU`) instead
of reusing the same one across shards - the template calls this out inline.

## Known gaps to fill in before relying on this in production

- `Apply-MonitorConfig.ps1` only implements the `SqlServer` and `WindowsHost`
  estate types. Each other host type (`LinuxHost`, `AmazonRdsHost`,
  `AzureSqlDatabase`, `PostgreSql`, …) maps to its own `New-RedgateMonitor*`
  cmdlet with different parameters — add a `switch` case per type you use,
  checking the exact parameters against the cmdlet reference for your
  Monitor version.
- `Export-MonitorConfig.ps1` leaves `notifications` and `globalSettings`
  empty — the write-side cmdlets (`Update-RedgateMonitorAlertNotificationSettings`,
  access-rights cmdlets) are wired up in `Apply-MonitorConfig.ps1`, but the
  matching read-back wasn't confirmed against your Monitor version's exact
  output shape. Check **Configuration → API → Example scripts** inside your
  own Monitor instance — it has version-matched example scripts that are the
  most reliable parameter reference.
- No update path for estate objects that already exist — re-running apply
  skips objects it finds, it doesn't reconcile drift on them yet.

## Reference

- [PowerShell cmdlet reference](https://documentation.red-gate.com/monitor/powershell-cmdlet-reference-240977753.html)
- [PowerShell API overview](https://documentation.red-gate.com/monitor14/powershell-api-239668741.html)
- [Connect-RedgateMonitor](https://documentation.red-gate.com/monitor/connect-redgatemonitor-242483289.html)
