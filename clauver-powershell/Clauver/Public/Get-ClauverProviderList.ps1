function Get-ClauverProviderList {
    $config = Read-ClauverConfig
    $providers = @()

    $config.GetEnumerator() | ForEach-Object {
        if ($_.Key -match '^(.+)_type$') {
            $providers += $matches[1]
        }
    }

    return $providers
}
