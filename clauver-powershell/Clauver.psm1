function Initialize-Clauver {
    param([string]$HomePath)

    $configDir = Join-Path $HomePath ".clauver"
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null

    $ageKeyPath = Join-Path $configDir "age.key"
    if (-not (Test-Path $ageKeyPath)) {
        age-keygen -o $ageKeyPath
    }
}

# Dot source the private and public function files
. (Join-Path $PSScriptRoot "Clauver/Private/Get-ClauverHome.ps1")
. (Join-Path $PSScriptRoot "Clauver/Private/Read-ClauverConfig.ps1")
. (Join-Path $PSScriptRoot "Clauver/Private/Read-ClauverInput.ps1")
. (Join-Path $PSScriptRoot "Clauver/Private/Read-ClauverSecureInput.ps1")
. (Join-Path $PSScriptRoot "Clauver/Private/Write-ClauverOutput.ps1")
. (Join-Path $PSScriptRoot "Clauver/Private/Invoke-AgeEncrypt.ps1")
. (Join-Path $PSScriptRoot "Clauver/Private/Invoke-AgeDecrypt.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Get-ClauverProviderList.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Set-ClauverConfig.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Get-ClauverStatus.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Test-ClauverProvider.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Get-ClauverVersion.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Set-ClauverDefault.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Get-ClauverDefault.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Invoke-ClauverProvider.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Invoke-ClauverMigrate.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Register-ClauverTabCompletion.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Update-Clauver.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Install-Clauver.ps1")
. (Join-Path $PSScriptRoot "Clauver/Public/Show-ClauverHelp.ps1")

Export-ModuleMember -Function Initialize-Clauver, Get-ClauverHome, Read-ClauverConfig, Read-ClauverInput, Read-ClauverSecureInput, Write-ClauverConfig, Write-ClauverLog, Write-ClauverSuccess, Write-ClauverWarn, Write-ClauverError, Get-ClauverProviderList, Set-ClauverConfig, Get-ProviderDefault, Invoke-AgeEncrypt, Invoke-AgeDecrypt, Get-ClauverAgeKey, Get-ClauverStatus, Test-ClauverProvider, Get-ClauverVersion, Set-ClauverDefault, Get-ClauverDefault, Invoke-ClauverProvider, Invoke-ClauverMigrate, Register-ClauverTabCompletion, Update-Clauver, Install-Clauver, Show-ClauverHelp
