<#
.SYNOPSIS
    Applies every sharded base-monitor config under config/base-monitors/.

.DESCRIPTION
    For estates split across multiple base monitors (see
    config/base-monitors/example-base-monitor.template.yaml) - runs
    Apply-MonitorConfig.ps1 once per real *.yaml shard in that folder,
    skipping the *.template.yaml example. All shards share the same
    connection (one Monitor instance), so this just needs
    RGM_SERVER_URL/RGM_ACCESS_TOKEN set once, the same as
    Apply-MonitorConfig.ps1 on its own.

    Run with -WhatIf first on anything touching production.

.EXAMPLE
    $env:RGM_SERVER_URL = "https://sql-monitor.example.com:8080"
    $env:RGM_ACCESS_TOKEN = "..."
    ./Apply-AllMonitorConfigs.ps1 -WhatIf
#>

param(
    [string]$ShardDirectory = (Join-Path $PSScriptRoot '..\config\base-monitors'),
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$shards = Get-ChildItem -Path $ShardDirectory -Filter '*.yaml' |
    Where-Object { $_.Name -notlike '*.template.yaml' }

if (-not $shards) {
    Write-Warning "No shard files found in '$ShardDirectory' (excluding *.template.yaml)."
    return
}

foreach ($shard in $shards) {
    Write-Host "=== Applying $($shard.Name) ==="
    & (Join-Path $PSScriptRoot 'Apply-MonitorConfig.ps1') -ConfigFile $shard.FullName -WhatIf:$WhatIf
}
