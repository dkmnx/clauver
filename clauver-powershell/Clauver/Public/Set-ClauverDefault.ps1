function Set-ClauverDefault {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    $config = Read-ClauverConfig
    $config['default_provider'] = $Name
    Write-ClauverConfig -Config $config
    Write-ClauverSuccess "Default provider set to $Name"
}
