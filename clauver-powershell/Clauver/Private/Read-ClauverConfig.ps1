function Read-ClauverConfig {
    $configPath = Join-Path (Get-ClauverHome) "config"

    if (-not (Test-Path $configPath)) {
        return @{}
    }

    $config = @{}
    Get-Content $configPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line -split '=', 2
            if ($parts.Count -eq 2) {
                $config[$parts[0].Trim()] = $parts[1].Trim()
            }
        }
    }
    return $config
}
