function Set-ClauverDefault {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    if ($PSCmdlet.ShouldProcess("default provider configuration", "Set default provider to $Name")) {
        $config = Read-ClauverConfig
        $config['default_provider'] = $Name
        Write-ClauverConfig -Config $config
        Write-ClauverSuccess "Default provider set to $Name"
    }
}
