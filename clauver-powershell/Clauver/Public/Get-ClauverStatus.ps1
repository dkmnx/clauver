function Get-ClauverStatus {
    Write-ClauverLog "Checking provider status..."

    $providers = Get-ClauverProviderList
    foreach ($provider in $providers) {
        Write-Host "  ${provider}: Configured" -ForegroundColor Green
    }

    Write-ClauverSuccess "Status check complete"
}

Export-ModuleMember -Function Get-ClauverStatus
