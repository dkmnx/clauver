function Read-ClauverInput {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    if ($Default) {
        $response = Read-Host "$Prompt [$Default]"
        if (-not $response) { $response = $Default }
        return $response
    }
    else {
        return Read-Host $Prompt
    }
}
