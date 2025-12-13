function Format-ClauverMaskedKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if ([string]::IsNullOrEmpty($Key)) {
        return ""
    }

    if ($Key.Length -le 8) {
        return "****"
    }

    return "$($Key.Substring(0, 4))****$($Key.Substring($Key.Length - 4))"
}

