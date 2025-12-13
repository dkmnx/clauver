function Initialize-Clauver {
    param([string]$HomePath)

    $configDir = Join-Path $HomePath ".clauver"
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null

    $ageKeyPath = Join-Path $configDir "age.key"
    if (-not (Test-Path $ageKeyPath)) {
        age-keygen -o $ageKeyPath
    }
}

Import-Module (Join-Path $PSScriptRoot "Clauver/Private/Get-ClauverHome.ps1")
Import-Module (Join-Path $PSScriptRoot "Clauver/Private/Read-ClauverConfig.ps1")
Import-Module (Join-Path $PSScriptRoot "Clauver/Private/Write-ClauverOutput.ps1")
Import-Module (Join-Path $PSScriptRoot "Clauver/Public/Get-ClauverProviderList.ps1")

Export-ModuleMember -Function Initialize-Clauver, Get-ClauverHome, Read-ClauverConfig, Write-ClauverConfig, Write-ClauverLog, Write-ClauverSuccess, Write-ClauverWarn, Write-ClauverError, Get-ClauverProviderList
