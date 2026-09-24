<#
.SYNOPSIS
    Shared connection helper for Redgate Monitor config-as-code scripts.

.DESCRIPTION
    Imports the Redgate Monitor PowerShell module and the powershell-yaml
    module, then connects using credentials from environment variables
    (never hardcode server URL/token in the repo).

    Prerequisites:
      - Redgate Monitor PowerShell module downloaded from your Monitor
        instance: Configuration -> API -> Download PowerShell module.
      - An access token generated on the same Configuration -> API page.
      - powershell-yaml module (community, PSGallery):
            Install-Module powershell-yaml -Scope CurrentUser
      - Environment variables set (see config/monitor-config.yaml for the
        var names used): RGM_SERVER_URL, RGM_ACCESS_TOKEN
      - The PowerShell API is only available for on-prem Redgate Monitor,
        not Monitor SaaS.
#>

param(
    [string]$ModulePath = $env:RGM_MODULE_PATH
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    throw "powershell-yaml module not found. Install with: Install-Module powershell-yaml -Scope CurrentUser"
}
Import-Module powershell-yaml -ErrorAction Stop

if ($ModulePath) {
    Import-Module $ModulePath -ErrorAction Stop
} elseif (-not (Get-Module -ListAvailable -Name RedgateMonitor)) {
    throw "Redgate Monitor PowerShell module not found. Download it from your Monitor instance (Configuration > API) and either install it or set RGM_MODULE_PATH to the .psd1/.psm1 path."
} else {
    Import-Module RedgateMonitor -ErrorAction Stop
}

$serverUrl = $env:RGM_SERVER_URL
$accessToken = $env:RGM_ACCESS_TOKEN

if (-not $serverUrl -or -not $accessToken) {
    throw "Set RGM_SERVER_URL and RGM_ACCESS_TOKEN environment variables before running config-as-code scripts."
}

Connect-RedgateMonitor -ServerUrl $serverUrl -AccessToken $accessToken
