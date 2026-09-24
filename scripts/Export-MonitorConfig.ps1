<#
.SYNOPSIS
    Exports the current Redgate Monitor configuration to YAML.

.DESCRIPTION
    Reads groups, monitored objects, alert settings and notification
    settings from a live Monitor instance and writes them to
    config/monitor-config.yaml in the same shape Apply-MonitorConfig.ps1
    expects. Use this to seed the file for the first time, or to see a
    diff against what's checked into git ("did someone change this by
    hand in the UI?").

.EXAMPLE
    $env:RGM_SERVER_URL = "https://sql-monitor.example.com:8080"
    $env:RGM_ACCESS_TOKEN = "..."
    ./Export-MonitorConfig.ps1 -OutFile ../config/monitor-config.yaml
#>

param(
    [string]$OutFile = (Join-Path $PSScriptRoot '..\config\monitor-config.yaml')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Connect-Monitor.ps1')

$groups = Get-RedgateMonitorGroup | ForEach-Object {
    [ordered]@{
        name       = $_.Name
        subGroups  = @(Get-RedgateMonitorSubGroup -Group $_ | ForEach-Object { [ordered]@{ name = $_.Name } })
    }
}

$monitoredObjects = Get-RedgateMonitorMonitoredObject
$estate = $monitoredObjects | ForEach-Object {
    [ordered]@{
        type    = $_.Type
        fullName = $_.FullName
        alias    = $_.Alias
        group    = $_.Group
    }
}

$alerts = @()
foreach ($obj in $monitoredObjects) {
    $settings = Get-RedgateMonitorAlertSettings -MonitoredObject $obj
    foreach ($s in $settings) {
        $alerts += [ordered]@{
            target    = $obj.Alias
            alertType = $s.AlertType
            status    = $s.Status
            comment   = $s.Comment
        }
    }
}

$config = [ordered]@{
    connection = [ordered]@{
        serverUrlEnvVar   = 'RGM_SERVER_URL'
        accessTokenEnvVar = 'RGM_ACCESS_TOKEN'
    }
    groups          = $groups
    estate          = $estate
    alerts          = $alerts
    notifications   = @()   # TODO: populate from Update-RedgateMonitorAlertNotificationSettings once
                             #       the read-side cmdlet/parameters are confirmed against your version
    globalSettings  = [ordered]@{
        accessRights = @()  # TODO: populate from your access-rights cmdlets if you manage these as code
        principals   = @()
    }
}

$yaml = ConvertTo-Yaml $config
Set-Content -Path $OutFile -Value $yaml -Encoding utf8
Write-Host "Exported Monitor configuration to $OutFile"
