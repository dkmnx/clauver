function Get-ClauverDefault {
    $config = Read-ClauverConfig
    return $config['default_provider']
}
