function Invoke-AgeDecrypt {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]$InputFile
    )

    $ageKey = Get-ClauverAgeKey
    if (-not $ageKey) {
        throw "Age key not found. Run 'clauver setup' first."
    }

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "age"
    $processInfo.Arguments = "-d", "-i", $ageKey, $InputFile
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null

    $output = $process.StandardOutput.ReadToEnd()
    $error = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "age decryption failed with exit code $($process.ExitCode): $error"
    }

    return $output
}
