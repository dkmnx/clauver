function Invoke-AgeEncrypt {
    param([string]$Plaintext, [string]$OutputFile)

    $ageKey = Get-ClauverAgeKey
    if (-not $ageKey) {
        throw "Age key not found. Run 'clauver setup' first."
    }

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "age"
    $processInfo.Arguments = "-e", "-i", $ageKey, "-o", $OutputFile
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardInput = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    $process.StandardInput.Write($Plaintext)
    $process.StandardInput.Close()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "age encryption failed with exit code $($process.ExitCode)"
    }
}

function Get-ClauverAgeKey {
    $ageKeyPath = Join-Path (Get-ClauverHome) "age.key"
    if (Test-Path $ageKeyPath) {
        return $ageKeyPath
    }
    return $null
}
