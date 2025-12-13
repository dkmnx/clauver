function Test-ClauverProvider {
    param([string]$Name)

    Write-ClauverLog "Testing $Name provider..."

    # Minimal implementation - validate config exists
    $config = Read-ClauverConfig
    if ($config.ContainsKey("${Name}_type")) {
        Write-ClauverSuccess "$Name is configured correctly"
    }
    else {
        Write-ClauverError "$Name is not configured"
    }
}

Export-ModuleMember -Function Test-ClauverProvider
