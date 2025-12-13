# Validation constants - matching bash script values
$script:MinApiKeyLength = 10
$script:MatchShellPatterns = @('rm', '&&', '||', ';', '|', '`', '$(', '}', '&')
$script:ReservedProviderNames = @('anthropic', 'zai', 'minimax', 'kimi', 'deepseek', 'custom')

function Test-ApiKeyFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiKey,

        [Parameter(Mandatory = $true)]
        [ValidateSet('zai', 'minimax', 'kimi', 'deepseek', 'custom')]
        [string]$Provider
    )

    try {
        # Basic validation - non-empty and reasonable length
        if ([string]::IsNullOrEmpty($ApiKey)) {
            Write-ClauverError "API key cannot be empty"
            return $false
        }

        # Check minimum length (most API keys are at least 10 chars, bash uses 10 as minimum)
        if ($ApiKey.Length -lt $script:MinApiKeyLength) {
            Write-ClauverError "API key too short (minimum $script:MinApiKeyLength characters)"
            return $false
        }

        # Enhanced security validation - prevent ALL shell metacharacters
        # Allow only alphanumeric, dot, underscore, hyphen, and common API key chars
        if ($ApiKey -notmatch '^[a-zA-Z0-9._-]+$') {
            Write-ClauverError "API key contains invalid characters"
            return $false
        }

        # Additional security checks - Reject any shell command patterns
        foreach ($pattern in $script:MatchShellPatterns) {
            if ($ApiKey.Contains($pattern)) {
                Write-ClauverError "API key contains prohibited shell pattern: $pattern"
                return $false
            }
        }

        # Provider-specific validation
        switch ($Provider) {
            'zai' {
                if ($ApiKey -notmatch '^sk-test-[a-zA-Z0-9]+$') {
                    Write-ClauverError "Z.AI API key must start with 'sk-test-' and contain only alphanumeric characters"
                    return $false
                }
            }
            'minimax' {
                if ($ApiKey -notmatch '^[a-zA-Z0-9]+$') {
                    Write-ClauverError "MiniMax API key must contain only alphanumeric characters"
                    return $false
                }
            }
            'kimi' {
                if ($ApiKey -notmatch '^[a-zA-Z0-9-]+$') {
                    Write-ClauverError "Kimi API key must contain only alphanumeric characters and hyphens"
                    return $false
                }
            }
            'deepseek' {
                if ($ApiKey -notmatch '^[a-zA-Z0-9._-]+$') {
                    Write-ClauverError "DeepSeek API key contains invalid characters"
                    return $false
                }
            }
            'custom' {
                # Custom providers may have different key formats
                if ($ApiKey -notmatch '^[a-zA-Z0-9._-]+$') {
                    Write-ClauverError "API key contains invalid characters"
                    return $false
                }
            }
        }

        return $true
    }
    catch {
        Write-ClauverError "Error validating API key: $_"
        return $false
    }
}

function Test-UrlFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        # Basic validation - non-empty
        if ([string]::IsNullOrEmpty($Url)) {
            Write-ClauverError "URL cannot be empty"
            return $false
        }

        # Check URL length (prevent DoS)
        if ($Url.Length -gt 2048) {
            Write-ClauverError "URL too long (maximum 2048 characters)"
            return $false
        }

        # Basic URL format validation
        if ($Url -notmatch '^https?://') {
            Write-ClauverError "URL must start with http:// or https://"
            return $false
        }

        # Security: Require HTTPS for external URLs
        if ($Url.StartsWith('http://')) {
            Write-ClauverError "HTTP URLs not allowed for security. Use HTTPS."
            return $false
        }

        # URL format validation using basic pattern matching
        if ($Url -notmatch '^https://[a-zA-Z0-9.-]+(\.[a-zA-Z]{2,})?(/.*)?$') {
            Write-ClauverError "Invalid URL format"
            return $false
        }

        # Extract hostname for SSRF protection
        $uri = [System.Uri]$Url
        $hostname = $uri.Host

        # Prevent localhost access (SSRF protection)
        if ($hostname -in @('localhost', '127.0.0.1', '::1')) {
            Write-ClauverError "Localhost URLs not allowed for security"
            return $false
        }

        # Prevent private IP ranges using regex (matching bash script)
        if ($hostname -match '^10\.|' -or
            $hostname -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.|' -or
            $hostname -match '^192\.168\.') {
            Write-ClauverError "Private IP addresses not allowed for security"
            return $false
        }

        # Prevent link-local addresses
        if ($hostname -match '^169\.254\.') {
            Write-ClauverError "Link-local addresses not allowed for security"
            return $false
        }

        # Check for .localhost TLD
        if ($hostname.EndsWith('.localhost')) {
            Write-ClauverError "Localhost domain not allowed for security"
            return $false
        }

        # Validate port range (if specified)
        if ($uri.Port -ne -1) {
            $port = $uri.Port
            # Reject privileged ports and common internal service ports (matching bash script)
            $blockedPorts = @(22, 23, 25, 53, 80, 110, 143, 443, 993, 995, 1433, 3306, 3389, 5432, 6379, 27017)
            if ($port -le 1024 -or $port -in $blockedPorts) {
                Write-ClauverError "Port $port not allowed for security"
                return $false
            }
        }

        return $true
    }
    catch {
        Write-ClauverError "Error validating URL: $_"
        return $false
    }
}

function Test-DecryptedContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    try {
        # Basic validation - non-empty
        if ([string]::IsNullOrEmpty($Content)) {
            Write-ClauverError "Decrypted content is empty"
            return $false
        }

        # Security: Check for error indicators that suggest corrupted content
        # More precise patterns for error messages (matching bash script)
        if ($Content -match '^(error|Error|ERROR)[:]\s+' -or
            $Content -match '^(failed|Failed|FAILED)[:]\s+' -or
            $Content -match '^(invalid|Invalid|INVALID)[:]\s+' -or
            $Content -match '^(corrupt|Corrupt|CORRUPT)[:]\s+' -or
            $Content -match '^(permission|Permission|PERMISSION)\s+denied') {
            Write-ClauverError "Decrypted content contains error indicators - may be corrupted"
            return $false
        }

        # Enhanced security validation - prevent malicious code injection
        # Check for common shell command patterns
        if ($Content -match '\$\(' -or
            $Content -match '`' -or
            $Content -match '\$\{') {
            Write-ClauverError "Decrypted content contains potentially malicious code"
            return $false
        }

        # Check for suspicious commands
        if ($Content -match 'rm\s+-rf|chmod|chown|wget|curl|nc\s+-') {
            Write-ClauverError "Decrypted content contains potentially malicious commands"
            return $false
        }

        # Validate environment variable format (KEY=value pairs)
        $lines = $Content -split "`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            $lineNum = $i + 1

            # Skip empty lines and comments
            if ([string]::IsNullOrEmpty($line) -or $line.StartsWith('#')) {
                continue
            }

            # Check if line matches environment variable format
            if ($line -notmatch '^[A-Z_][A-Z0-9_]*=.*$') {
                Write-ClauverError "Decrypted content contains invalid format on line $lineNum`: $line"
                return $false
            }

            # Extract and validate the value part
            $parts = $line -split '=', 2
            if ($parts.Count -eq 2) {
                $value = $parts[1]

                # Allow common API key characters but reject obviously dangerous patterns
                if ($value -match '\$\(' -or
                    $value -match '`' -or
                    $value -match 'rm\s+-rf|chmod|chown|wget|curl') {
                    Write-ClauverError "Decrypted content contains potentially malicious code in value on line $lineNum"
                    return $false
                }
            }
        }

        return $true
    }
    catch {
        Write-ClauverError "Error validating decrypted content: $_"
        return $false
    }
}

function Test-ProviderName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProviderName
    )

    try {
        # Basic validation - non-empty
        if ([string]::IsNullOrEmpty($ProviderName)) {
            Write-ClauverError "Provider name cannot be empty"
            return $false
        }

        # Format validation - allow only letters, numbers, underscores, and hyphens
        if ($ProviderName -notmatch '^[a-zA-Z0-9_-]+$') {
            Write-ClauverError "Provider name can only contain letters, numbers, underscores, and hyphens"
            return $false
        }

        # Prevent reserved names
        if ($ProviderName -in $script:ReservedProviderNames) {
            Write-ClauverError "Provider name '$ProviderName' is reserved"
            return $false
        }

        # Length validation
        if ($ProviderName.Length -gt 50) {
            Write-ClauverError "Provider name too long (maximum 50 characters)"
            return $false
        }

        return $true
    }
    catch {
        Write-ClauverError "Error validating provider name: $_"
        return $false
    }
}

function Test-ModelName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModelName
    )

    try {
        if ([string]::IsNullOrEmpty($ModelName)) {
            Write-ClauverError "Model name cannot be empty"
            return $false
        }

        # Security validation - prevent injection attacks
        # Reject dangerous characters that could be used for command injection
        $dangerousChars = '[;`$|&<>]'
        if ($ModelName -match $dangerousChars) {
            Write-ClauverError "Model name contains dangerous characters that could be used for injection attacks"
            return $false
        }

        # Reject potential command substitution patterns
        if ($ModelName -match '\$\(') {
            Write-ClauverError "Model name contains potential command substitution pattern"
            return $false
        }

        # Reject quote characters that could break parsing
        if ($ModelName -match '[''"]') {
            Write-ClauverError "Model name contains quote characters that could break parsing"
            return $false
        }

        # Basic model name validation - allow safe characters including provider/model:tag format
        if ($ModelName -notmatch '^[a-zA-Z0-9.\\/_:-]+$') {
            Write-ClauverError "Model name contains invalid characters (only alphanumeric, dot, underscore, hyphen, forward slash, colon allowed)"
            return $false
        }

        return $true
    }
    catch {
        Write-ClauverError "Error validating model name: $_"
        return $false
    }
}

# Export functions
