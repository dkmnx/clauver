function Read-ClauverSecureInput {
    param([string]$Prompt)

    $secureString = Read-Host $Prompt -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($secureString)
    $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($ptr)
    return $result
}

Export-ModuleMember -Function Read-ClauverSecureInput
