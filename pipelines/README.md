# Sample pipelines

Folder-per-CI/CD-platform, same pattern as
[Flyway-Sample-Pipelines](https://github.com/red-gate/Flyway-Sample-Pipelines):
the config in `config/` and the scripts in `scripts/` don't change between
platforms, only how you wire them into your automation does.

Each sample does the same three things:

1. Check out the repo.
2. Restore `powershell-yaml` and the Redgate Monitor PowerShell module.
3. Run `scripts/Apply-MonitorConfig.ps1` against `config/monitor-config.yaml`,
   with `RGM_SERVER_URL` / `RGM_ACCESS_TOKEN` (and `RGM_MODULE_PATH` if
   needed) supplied as pipeline secrets/variables, never committed.

## Before you copy one of these

The PowerShell API only works against **on-premises** Monitor
([SETUP.md](../SETUP.md)), which means the runner executing the pipeline
needs network line-of-sight to your base monitor — a hosted/cloud runner
(GitHub-hosted, Microsoft-hosted Azure DevOps agents, etc.) usually can't
reach an internal network. In practice that means a **self-hosted runner/agent**
on your own network, unless your Monitor instance is otherwise reachable
from the platform's hosted runners.

## Platforms

- `GitHub-Actions/` — workflow that runs on a self-hosted Windows runner.
- Azure DevOps, Jenkins, GitLab, etc. — not sketched out yet; copy the
  GitHub Actions sample's structure (checkout → restore modules → apply)
  and swap in that platform's syntax and secret-storage mechanism.
