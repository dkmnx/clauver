function Sanitize-ClauverPath {
    param([string]$Path)

    # Show only filename and directory, hide full path for security
    if ($env:HOME -and $Path.StartsWith($env:HOME)) {
        return "~$($Path.Substring($env:HOME.Length))"
    }
    elseif ($Path -match '/') {
        return ".../$(Split-Path -Leaf $Path)"
    }
    else {
        return $Path
    }
}

# Alias for bash compatibility
New-Alias -Name sanitize_path -Value Sanitize-ClauverPath