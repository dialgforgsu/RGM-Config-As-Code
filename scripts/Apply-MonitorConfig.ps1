<#
.SYNOPSIS
    Applies config/monitor-config.yaml to a Redgate Monitor instance.

.DESCRIPTION
    Reads the YAML config and pushes it to Monitor via the PowerShell API:
    creates groups, registers monitored objects (estate), and sets alert
    status/comments and notification settings. Existing objects are
    matched by alias/full name and updated rather than duplicated.

    Run with -WhatIf first on anything touching production.

.EXAMPLE
    $env:RGM_SERVER_URL = "https://sql-monitor.example.com:8080"
    $env:RGM_ACCESS_TOKEN = "..."
    ./Apply-MonitorConfig.ps1 -ConfigFile ../config/monitor-config.yaml -WhatIf
#>

param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot '..\config\monitor-config.yaml'),
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Connect-Monitor.ps1')

$config = ConvertFrom-Yaml (Get-Content $ConfigFile -Raw)

# --- Groups ---------------------------------------------------------------
foreach ($group in $config.groups) {
    $existing = Get-RedgateMonitorGroup | Where-Object { $_.Name -eq $group.name }
    if (-not $existing) {
        Write-Host "Creating group '$($group.name)'"
        if (-not $WhatIf) { New-RedgateMonitorGroup -Name $group.name }
    }
    foreach ($sub in $group.subGroups) {
        $existingSub = Get-RedgateMonitorSubGroup | Where-Object { $_.Name -eq $sub.name }
        if (-not $existingSub) {
            Write-Host "Creating sub-group '$($sub.name)' under '$($group.name)'"
            if (-not $WhatIf) { New-RedgateMonitorGroup -Name $sub.name -ParentGroup $group.name }
        }
    }
}

# --- Estate ----------------------------------------------------------------
# Each 'type' maps to a New-RedgateMonitor* cmdlet. Only SqlServer and
# WindowsHost are wired up below - add a case per host type you actually
# manage (New-RedgateMonitorLinuxHost, New-RedgateMonitorAzureSqlDatabase,
# etc.), checking that cmdlet's exact parameters in the Monitor docs first.
foreach ($node in $config.estate) {
    $existing = Get-RedgateMonitorMonitoredObject | Where-Object { $_.FullName -eq $node.fullName }
    if ($existing) {
        Write-Host "'$($node.fullName)' already monitored - skipping create (update path not implemented)"
        continue
    }

    $baseMonitor = Get-RedgateMonitorBaseMonitor | Where-Object { $_.Name -eq $node.baseMonitor } | Select-Object -First 1
    if (-not $baseMonitor) {
        Write-Warning "Base monitor '$($node.baseMonitor)' not found - skipping '$($node.fullName)'"
        continue
    }

    switch ($node.type) {
        'SqlServer' {
            $newObj = New-RedgateMonitorSqlServer `
                -FullName $node.fullName `
                -BaseMonitor $baseMonitor `
                -Alias $node.alias `
                -SqlServerAuthenticationMode $node.sqlServerAuthenticationMode `
                -Port $node.port `
                -EncryptConnection $node.encryptConnection `
                -TrustServerCertificate ([bool]$node.trustServerCertificate)
        }
        'WindowsHost' {
            $newObj = New-RedgateMonitorWindowsHost `
                -FullName $node.fullName `
                -BaseMonitor $baseMonitor
        }
        default {
            Write-Warning "Estate type '$($node.type)' not implemented in Apply-MonitorConfig.ps1 - add a case for it."
            continue
        }
    }

    Write-Host "Adding monitored object '$($node.fullName)' to group '$($node.group)'"
    if (-not $WhatIf) {
        Add-RedgateMonitorMonitoredObject -MonitoredObject $newObj -Group $node.group
    }
}

# --- Alerts ------------------------------------------------------------
foreach ($alert in $config.alerts) {
    $obj = Get-RedgateMonitorMonitoredObject | Where-Object { $_.Alias -eq $alert.target }
    if (-not $obj) {
        Write-Warning "Monitored object '$($alert.target)' not found - skipping alert '$($alert.alertType)'"
        continue
    }

    Write-Host "Setting alert '$($alert.alertType)' on '$($alert.target)' to '$($alert.status)'"
    if (-not $WhatIf) {
        Update-RedgateMonitorAlertSettingsStatus -MonitoredObject $obj -AlertType $alert.alertType -Status $alert.status
        if ($alert.comment) {
            Update-RedgateMonitorAlertSettingsComment -MonitoredObject $obj -AlertType $alert.alertType -Comment $alert.comment
        }
        if ($alert.specificSettings) {
            $specific = New-RedgateMonitorAlertSpecificSettings -AlertType $alert.alertType @($alert.specificSettings)
            Update-RedgateMonitorAlertSpecificSettings -MonitoredObject $obj -AlertType $alert.alertType -Settings $specific
        }
    }
}

# --- Notifications -------------------------------------------------------
foreach ($notification in $config.notifications) {
    $obj = Get-RedgateMonitorMonitoredObject | Where-Object { $_.Alias -eq $notification.target }
    if (-not $obj) {
        Write-Warning "Monitored object '$($notification.target)' not found - skipping notification for '$($notification.alertType)'"
        continue
    }

    Write-Host "Updating notification settings for '$($notification.alertType)' on '$($notification.target)'"
    if (-not $WhatIf) {
        Update-RedgateMonitorAlertNotificationSettings -MonitoredObject $obj -AlertType $notification.alertType -Channels $notification.channels
    }
}

Write-Host "Done."
