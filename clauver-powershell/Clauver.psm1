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

Export-ModuleMember -Function Initialize-Clauver, Get-ClauverHome
