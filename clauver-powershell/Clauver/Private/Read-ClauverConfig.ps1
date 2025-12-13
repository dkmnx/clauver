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

function Write-ClauverConfig {
    param([hashtable]$Config)

    $clauverHome = Get-ClauverHome
    $configPath = Join-Path $clauverHome "config"
    $tempFile = [System.IO.Path]::GetTempFileName()

    try {
        # Ensure the clauver home directory exists
        if (-not (Test-Path $clauverHome)) {
            New-Item -ItemType Directory -Path $clauverHome -Force | Out-Null
        }

        $Config.GetEnumerator() | ForEach-Object {
            "$($_.Key)=$($_.Value)" | Out-File -FilePath $tempFile -Encoding utf8 -Append
        }

        Move-Item $tempFile $configPath -Force
    }
    catch {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        throw
    }
}

