#!/usr/bin/env pwsh
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

# Import Clauver module
$scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$scriptDir = Split-Path -Parent $scriptPath
$modulePath = Join-Path $scriptDir "Clauver.psm1"
Import-Module $modulePath -Force -ErrorAction Stop

# Route command to appropriate function
$command = $RemainingArgs[0]

switch ($command) {
    "setup" {
        Initialize-Clauver -HomePath $env:USERPROFILE
    }
    "list" {
        Get-ClauverProviderList
    }
    "status" {
        Get-ClauverStatus
    }
    "test" {
        Test-ClauverProvider -Name $RemainingArgs[1]
    }
    "version" {
        Get-ClauverVersion
    }
    default {
        Write-Output "Unknown command: $command. Run 'clauver help' for usage information"
        exit 1
    }
}
