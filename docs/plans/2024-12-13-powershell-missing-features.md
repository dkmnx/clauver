# PowerShell Missing Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete PowerShell implementation parity with bash by implementing Update, Migration, Custom Providers, and Tab Completion features.

**Architecture:** Incremental implementation using existing PowerShell module structure, following bash implementation patterns exactly, maintaining TDD approach with Pester testing framework.

**Tech Stack:** PowerShell 7+, Pester testing framework, Age encryption, GitHub API, PowerShell tab completion API.

---

## Context and Architecture

**PowerShell Module Structure:**
- Main entry: `clauver-powershell/clauver.ps1`
- Module: `clauver-powershell/Clauver.psm1`
- Public functions: `Clauver/Public/*.ps1`
- Private helpers: `Clauver/Private/*.ps1`
- Tests: `tests/Unit/*.Tests.ps1`

**Key Constants (Clauver/Private/ClauverConstants.ps1):**
- `$script:ClauverVersion = "1.12.1"`
- `$script:GitHubApiBase = "https://api.github.com/repos/dkmnx/clauver"`
- `$script:RawContentBase = "https://raw.githubusercontent.com/dkmnx/clauver"`
- `$script:ProviderDefaults`, `$script:PerformanceDefaults`

**Existing Patterns to Follow:**
- Use `$script:` scope for module variables
- Follow `Verb-Noun` PowerShell naming convention
- Use `Write-ClauverError` for error output
- Use ASCII art banners matching bash exactly
- Return values via pipeline, not exit codes

---

### Task 1: Update Command Implementation

**Files:**
- Modify: `clauver-powershell/Clauver/Public/Update-Clauver.ps1` (currently empty)
- Test: `tests/Unit/Update-Clauver.Tests.ps1`
- Reference: `clauver.sh` lines 2073-2127 (cmd_update function)

**Step 1: Write failing test for version checking**

```powershell
Describe 'Update-Clauver' {
    Context 'When checking for updates' {
        It 'Should detect newer version available' {
            Mock Get-LatestVersion { return "1.13.0" }
            $result = Update-Clauver -CheckOnly
            $result.NewerVersionAvailable | Should -Be $true
            $result.CurrentVersion | Should -Be "1.12.1"
            $result.LatestVersion | Should -Be "1.13.0"
        }

        It 'Should detect no updates needed' {
            Mock Get-LatestVersion { return "1.12.1" }
            $result = Update-Clauver -CheckOnly
            $result.NewerVersionAvailable | Should -Be $false
        }
    }
}
```

**Step 2: Run test to verify it fails**

Run: `pwsh -Command "Invoke-Pester tests/Unit/Update-Clauver.Tests.ps1"`
Expected: FAIL with "Get-LatestVersion not found" and "Update-Clauver returns nothing"

**Step 3: Implement version checking logic**

```powershell
function Update-Clauver {
    [CmdletBinding()]
    param(
        [switch]$CheckOnly,
        [switch]$Force
    )

    try {
        Write-Host "Current version: v$script:ClauverVersion"

        $latestVersion = Get-LatestVersion
        if (-not $latestVersion) {
            Write-ClauverError "Could not determine latest version"
            return @{
                Success = $false
                Error = "Version check failed"
            }
        }

        if ($script:ClauverVersion -eq $latestVersion) {
            Write-Host "$(ui_success) You are on the latest version" -ForegroundColor Green
            return @{
                Success = $true
                CurrentVersion = $script:ClauverVersion
                LatestVersion = $latestVersion
                NewerVersionAvailable = $false
            }
        }

        # Version comparison logic here
        $needsUpdate = Compare-Versions -Current $script:ClauverVersion -Latest $latestVersion

        if ($needsUpdate) {
            Write-Host "$(ui_warn) Update available: v$latestVersion" -ForegroundColor Yellow
            Write-Host "Run 'clauver update' to upgrade"

            if ($CheckOnly) {
                return @{
                    Success = $true
                    CurrentVersion = $script:ClauverVersion
                    LatestVersion = $latestVersion
                    NewerVersionAvailable = $true
                }
            }
        } else {
            Write-Host "! You are on a pre-release version (v$script:ClauverVersion) newer than latest stable (v$latestVersion)" -ForegroundColor Yellow
        }

        if (-not $CheckOnly -and $needsUpdate) {
            return Perform-Update -LatestVersion $latestVersion
        }

    } catch {
        Write-ClauverError "Update failed: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `pwsh -Command "Invoke-Pester tests/Unit/Update-Clauver.Tests.ps1"`
Expected: PASS

**Step 5: Implement helper functions**

```powershell
function Get-LatestVersion {
    # GitHub API call matching bash implementation
    $apiUrl = "$script:GitHubApiBase/tags"

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 30
        if ($response -and $response.Count -gt 0) {
            $version = $response[0].name
            # Sanitize version - only allow v followed by numbers and dots
            if ($version -match '^v[\d\.]+$') {
                return $version -replace '^v', ''
            }
        }
    } catch {
        Write-Debug "Failed to fetch latest version: $_"
    }

    return $null
}

function Compare-Versions {
    param(
        [string]$Current,
        [string]$Latest
    )
    # Implement version comparison logic matching bash sort -V behavior
    try {
        $currentParts = $Current -split '\.' | ForEach-Object { [int]$_ }
        $latestParts = $Latest -split '\.' | ForEach-Object { [int]$_ }

        $maxLength = [Math]::Max($currentParts.Length, $latestParts.Length)

        for ($i = 0; $i -lt $maxLength; $i++) {
            $currentVal = if ($i -lt $currentParts.Length) { $currentParts[$i] } else { 0 }
            $latestVal = if ($i -lt $latestParts.Length) { $latestParts[$i] } else { 0 }

            if ($currentVal -lt $latestVal) {
                return $true  # Need update
            } elseif ($currentVal -gt $latestVal) {
                return $false # Current is newer
            }
        }

        return $false # Same version
    } catch {
        return $false
    }
}

function Perform-Update {
    param([string]$LatestVersion)

    # Implement download and update logic matching bash
    $installPath = Get-Command clauver -ErrorAction SilentlyContinue
    if (-not $installPath) {
        Write-ClauverError "Clauver installation not found in PATH"
        return @{
            Success = $false
            Error = "Installation not found"
        }
    }

    # Continue with update implementation...
}
```

**Step 6: Commit**

```bash
git add clauver-powershell/Clauver/Public/Update-Clauver.ps1 tests/Unit/Update-Clauver.Tests.ps1
git commit -m "feat: implement Update-Clauver with version checking"
```

---

### Task 2: Migration Command Implementation

**Files:**
- Modify: `clauver-powershell/Clauver/Public/Invoke-ClauverMigrate.ps1` (currently empty)
- Test: `tests/Unit/Invoke-ClauverMigrate.Tests.ps1`
- Reference: `clauver.sh` lines 2084-2115 (cmd_migrate function)

**Step 1: Write failing test for migration detection**

```powershell
Describe 'Invoke-ClauverMigrate' {
    Context 'When checking migration status' {
        It 'Should detect already encrypted secrets' {
            Mock Test-Path { return $true } -ParameterFilter { $_ -like "*.age" }
            Mock Test-Path { return $false } -ParameterFilter { $_ -notlike "*.age" }

            $result = Invoke-ClauverMigrate -CheckOnly
            $result.AlreadyEncrypted | Should -Be $true
            $result.NeedsMigration | Should -Be $false
        }

        It 'Should detect plaintext secrets needing migration' {
            Mock Test-Path { return $true } -ParameterFilter { $_ -eq "secrets.env" }
            Mock Test-Path { return $false } -ParameterFilter { $_ -like "*.age" }

            $result = Invoke-ClauverMigrate -CheckOnly
            $result.AlreadyEncrypted | Should -Be $false
            $result.NeedsMigration | Should -Be $true
        }
    }
}
```

**Step 2: Run test to verify it fails**

Run: `pwsh -Command "Invoke-Pester tests/Unit/Invoke-ClauverMigrate.Tests.ps1"`
Expected: FAIL with "Invoke-ClauverMigrate returns nothing"

**Step 3: Implement migration logic**

```powershell
function Invoke-ClauverMigrate {
    [CmdletBinding()]
    param(
        [switch]$CheckOnly,
        [switch]$Force
    )

    try {
        $clauverHome = Get-ClauverHome
        $secretsPath = Join-Path $clauverHome "secrets.env"
        $secretsAgePath = Join-Path $clauverHome "secrets.env.age"
        $ageKeyPath = Join-Path $clauverHome "age.key"

        Write-Host "$(ui_banner "Migrate Secrets to Encrypted Storage")" -ForegroundColor Cyan
        Write-Host ""

        # Check if already encrypted
        if ((Test-Path $secretsAgePath) -and (-not (Test-Path $secretsPath))) {
            Write-Success "Secrets are already encrypted!"
            Write-Host "  Location: $(sanitize_path $secretsAgePath)"

            if ($CheckOnly) {
                return @{
                    Success = $true
                    AlreadyEncrypted = $true
                    NeedsMigration = $false
                }
            }
            return
        }

        # Check if plaintext file exists
        if (-not (Test-Path $secretsPath)) {
            if (Test-Path $secretsAgePath) {
                Write-Success "Encrypted secrets file already exists at: $secretsAgePath"
            } else {
                Write-Warn "No secrets file found. Configure a provider first:"
                Write-Host "  clauver config <provider>"
            }

            if ($CheckOnly) {
                return @{
                    Success = $true
                    AlreadyEncrypted = $false
                    NeedsMigration = $false
                    NoSecretsFound = $true
                }
            }
            return
        }

        Write-Log "Found plaintext secrets file: $(sanitize_path $secretsPath)"
        Write-Host ""

        if ($CheckOnly) {
            return @{
                Success = $true
                AlreadyEncrypted = $false
                NeedsMigration = $true
                PlaintextPath = $secretsPath
            }
        }

        # Ensure age key exists
        $ensureResult = Ensure-AgeKey
        if (-not $ensureResult.Success) {
            Write-ClauverError "Failed to ensure age key. Migration aborted."
            return @{
                Success = $false
                Error = "Age key creation failed"
            }
        }

        # Perform migration
        return Perform-Migration -PlaintextPath $secretsPath -EncryptedPath $secretsAgePath

    } catch {
        Write-ClauverError "Migration failed: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `pwsh -Command "Invoke-Pester tests/Unit/Invoke-ClauverMigrate.Tests.ps1"`
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver/Public/Invoke-ClauverMigrate.ps1 tests/Unit/Invoke-ClauverMigrate.Tests.ps1
git commit -m "feat: implement Invoke-ClauverMigrate with encryption migration"
```

---

### Task 3: Custom Provider Support

**Files:**
- Modify: `clauver-powershell/clauver.ps1` (default case in switch statement)
- Modify: `clauver-powershell/Clauver/Public/Set-ClauverConfig.ps1` (custom provider config)
- Test: `tests/Unit/CustomProvider.Tests.ps1`
- Reference: `clauver.sh` lines 2311-2314 (custom provider handling)

**Step 1: Write failing test for custom provider detection**

```powershell
Describe 'Custom Provider Support' {
    Context 'When using custom provider names' {
        It 'Should detect custom provider and use it' {
            Mock Get-ConfigValue { return "sk-test-12345" } -ParameterFilter { $_ -eq "custom_myprovider_api_key" }
            Mock Invoke-ClauverProvider {} -Verifiable -ParameterFilter { $Provider -eq "myprovider" }

            ./clauver.ps1 "myprovider" "test prompt"

            Assert-MockCalled Invoke-ClauverProvider -Times 1 -ParameterFilter { $Provider -eq "myprovider" }
        }
    }
}
```

**Step 2: Run test to verify it fails**

Run: `pwsh -Command "Invoke-Pester tests/Unit/CustomProvider.Tests.ps1"`
Expected: FAIL - custom provider not detected

**Step 3: Fix clauver.ps1 default case to support custom providers**

```powershell
# Replace existing default case in clauver.ps1 switch statement
default {
    # Check if it's a custom provider
    $customApiKey = Get-ConfigValue -Key "custom_${command}_api_key"
    if ($customApiKey) {
        # It's a custom provider
        Write-Debug "Found custom provider: $command"
        $providerArgs = if ($RemainingArgs.Count -gt 1) { $RemainingArgs[1..($RemainingArgs.Count - 1)] } else { @() }
        Invoke-ClauverProvider -Provider $command -ClaudeArgs $providerArgs
    } else {
        # Check if a default provider is set
        $defaultProvider = Get-ClauverDefault
        if ($defaultProvider) {
            # Use the default provider with all arguments
            $providerArgs = $RemainingArgs
            Invoke-ClauverProvider -Provider $defaultProvider -ClaudeArgs $providerArgs
        } else {
            # Unknown command
            Write-Host "Unknown command: $command" -ForegroundColor Red
            Show-ClauverHelp
            exit 1
        }
    }
}
```

**Step 4: Enhance Set-ClauverConfig for custom providers**

```powershell
# Add to Set-ClauverConfig function
"custom" {
    Write-Host ""
    Write-Host "$(ui_banner "Custom Provider Configuration")" -ForegroundColor Cyan
    $name = Read-ClauverInput -Prompt "Provider name (e.g., 'my-provider')"

    if (-not $name) {
        Write-ClauverError "Provider name is required"
        return
    }

    if (-not (Test-ProviderName -Name $name)) {
        return
    }

    $baseUrl = Read-ClauverInput -Prompt "Base URL"
    $apiKey = Read-ClauverSecureInput -Prompt "API Key"
    $model = Read-ClauverInput -Prompt "Default model (optional)"

    if (-not $name -or -not $baseUrl -or -not $apiKey) {
        Write-ClauverError "Name, Base URL and API Key are required"
        return
    }

    # Validate inputs
    if (-not (Test-Url -Url $baseUrl)) {
        return
    }

    if (-not (Test-ApiKey -Key $apiKey -Provider "custom")) {
        return
    }

    if ($model -and -not (Test-ModelName -Model $model)) {
        return
    }

    Set-ConfigValue -Key "custom_${name}_api_key" -Value $apiKey
    Set-ConfigValue -Key "custom_${name}_base_url" -Value $baseUrl
    if ($model) {
        Set-ConfigValue -Key "custom_${name}_model" -Value $model
    }

    Write-Success "Custom provider '$name' configured. Use: clauver $name"
}
```

**Step 5: Run test to verify it passes**

Run: `pwsh -Command "Invoke-Pester tests/Unit/CustomProvider.Tests.ps1"`
Expected: PASS

**Step 6: Commit**

```bash
git add clauver-powershell/clauver.ps1 clauver-powershell/Clauver/Public/Set-ClauverConfig.ps1 tests/Unit/CustomProvider.Tests.ps1
git commit -m "feat: add custom provider support to PowerShell implementation"
```

---

### Task 4: PowerShell Tab Completion

**Files:**
- Modify: `clauver-powershell/Clauver/Public/Register-ClauverTabCompletion.ps1` (currently empty)
- Create: `clauver-powershell/Completion/clauver-completion.ps1`
- Test: Manual testing in PowerShell session
- Reference: `completion/bash-clauver` and `completion/zsh-clauver`

**Step 1: Write tab completion registration function**

```powershell
function Register-ClauverTabCompletion {
    [CmdletBinding()]
    param()

    try {
        # Register argument completer for clauver command
        Register-ArgumentCompleter -CommandName 'clauver' -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            # Get completion items
            $completions = Get-ClauverCompletions -WordToComplete $wordToComplete -CommandAst $commandAst

            # Return completion results
            return $completions | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.Text,
                    $_.ListItemText,
                    $_.CompletionType,
                    $_.ToolTip
                )
            }
        }

        Write-Success "Clauver tab completion registered"
        Write-Host "Restart PowerShell to use tab completion"

    } catch {
        Write-ClauverError "Failed to register tab completion: $_"
    }
}
```

**Step 2: Implement completion logic**

```powershell
function Get-ClauverCompletions {
    param(
        [string]$WordToComplete,
        $CommandAst
    )

    try {
        # Get command position
        $commandElements = $CommandAst.CommandElements
        $currentPosition = $commandElements.Count

        # Main commands completion
        if ($currentPosition -le 2) {
            return Get-CommandCompletions -WordToComplete $wordToComplete
        }

        # Provider completion for specific commands
        $mainCommand = $commandElements[1].Value
        switch ($mainCommand) {
            "config" { return Get-ProviderCompletions -WordToComplete $wordToComplete }
            "test" { return Get-ProviderCompletions -WordToComplete $wordToComplete }
            "default" { return Get-ProviderCompletions -WordToComplete $wordToComplete }
        }

        # Custom providers completion
        return Get-CustomProviderCompletions -WordToComplete $wordToComplete

    } catch {
        Write-Debug "Completion error: $_"
        return @()
    }
}

function Get-CommandCompletions {
    param([string]$WordToComplete)

    $commands = @(
        "help", "setup", "version", "update", "list",
        "status", "config", "test", "default", "migrate",
        "anthropic", "zai", "minimax", "kimi", "deepseek"
    )

    return $commands | Where-Object { $_ -like "$WordToComplete*" } | ForEach-Object {
        @{
            Text = $_
            ListItemText = $_
            CompletionType = [System.Management.Automation.CompletionResultType]::ParameterValue
            ToolTip = "Clauver command: $_"
        }
    }
}

function Get-ProviderCompletions {
    param([string]$WordToComplete)

    # Get configured providers
    $providers = @("anthropic", "zai", "minimax", "kimi", "deepseek", "custom")

    # Add custom providers from config
    try {
        $configPath = Join-Path (Get-ClauverHome) "config"
        if (Test-Path $configPath) {
            $configContent = Get-Content $configPath
            $customProviders = $configContent | Where-Object { $_ -match "^custom_([^_]+)_api_key=" } |
                ForEach-Object { $matches[1] }
            $providers += $customProviders
        }
    } catch {
        Write-Debug "Failed to read custom providers: $_"
    }

    return $providers | Where-Object { $_ -like "$WordToComplete*" } | ForEach-Object {
        @{
            Text = $_
            ListItemText = $_
            CompletionType = [System.Management.Automation.CompletionResultType]::ParameterValue
            ToolTip = "Provider: $_"
        }
    }
}
```

**Step 3: Create installation script**

```powershell
# File: clauver-powershell/Completion/clauver-completion.ps1
# Install script for tab completion

try {
    # Get module path
    $modulePath = Join-Path $PSScriptRoot ".." "Clauver.psm1"
    Import-Module $modulePath -Force

    # Register completion
    Register-ClauverTabCompletion

    # Add to PowerShell profile for persistence
    $profilePath = $PROFILE.CurrentUserCurrentHost
    $completionLine = "Import-Module '$modulePath'; Register-ClauverTabCompletion"

    if (-not (Test-Path $profilePath)) {
        New-Item -Path $profilePath -ItemType File -Force | Out-Null
    }

    $profileContent = Get-Content $profilePath -Raw
    if ($profileContent -notcontains [regex]::Escape($completionLine)) {
        Add-Content -Path $profilePath -Value "`n# Clauver tab completion`n$completionLine`n"
        Write-Success "Added to PowerShell profile: $profilePath"
    }

} catch {
    Write-Error "Failed to install tab completion: $_"
    exit 1
}

Write-Success "Clauver tab completion installed successfully!"
Write-Host "Restart PowerShell to use tab completion."
```

**Step 4: Manual testing**

Run in PowerShell session:
```powershell
# Load completion
. ./clauver-powershell/Completion/clauver-completion.ps1

# Test completion
clauver <TAB>
clauver config <TAB>
clauver <custom-provider-name> <TAB>
```

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver/Public/Register-ClauverTabCompletion.ps1 clauver-powershell/Completion/clauver-completion.ps1
git commit -m "feat: implement PowerShell tab completion support"
```

---

### Task 5: Integration Testing and Documentation

**Files:**
- Create: `tests/Integration/FullWorkflow.Tests.ps1`
- Modify: `README.md` (add PowerShell section)
- Create: `docs/POWERSHELL.md` (PowerShell-specific documentation)

**Step 1: Create comprehensive integration test**

```powershell
Describe 'Clauver PowerShell Integration Tests' {
    BeforeEach {
        # Use test home directory
        $env:CLAUVER_HOME = Join-Path $TestDrive "clauver-test"
        New-Item -ItemType Directory -Path $env:CLAUVER_HOME -Force | Out-Null
    }

    Context 'End-to-end workflow' {
        It 'Should configure and use zai provider' {
            # Setup
            Set-ConfigValue -Key "zai_api_key" -Value "sk-test-12345"
            Set-ClauverDefault -Name "zai"

            # Test default provider
            $default = Get-ClauverDefault
            $default | Should -Be "zai"

            # Test provider switching
            Mock Switch-ToZai {} -Verifiable
            Invoke-ClauverProvider -Provider "zai" -ClaudeArgs @("test")
            Assert-MockCalled Switch-ToZai -Times 1
        }

        It 'Should migrate plaintext secrets to encrypted' {
            # Create plaintext secrets
            $secretsPath = Join-Path $env:CLAUVER_HOME "secrets.env"
            "ZAI_API_KEY=sk-test-12345" | Out-File -FilePath $secretsPath -Encoding UTF8

            # Mock age functions
            Mock Ensure-AgeKey { return @{ Success = $true } }
            Mock Invoke-AgeEncrypt { return $true }

            # Test migration
            $result = Invoke-ClauverMigrate
            $result.Success | Should -Be $true
            $result.NeedsMigration | Should -Be $true
        }
    }
}
```

**Step 2: Run integration tests**

Run: `pwsh -Command "Invoke-Pester tests/Integration/FullWorkflow.Tests.ps1"`
Expected: All tests PASS

**Step 3: Update documentation**

```markdown
# PowerShell README Section

## PowerShell Support

Clauver now supports PowerShell 7+ on Windows, macOS, and Linux with full feature parity to the bash version.

### Installation

```powershell
# Clone repository
git clone https://github.com/dkmnx/clauver.git
cd clauver/clauver-powershell

# Install tab completion
. ./Completion/clauver-completion.ps1

# Run setup wizard
./clauver.ps1 setup
```

### Usage

```powershell
# Basic provider switching
./clauver.ps1 zai
./clauver.ps1 "your prompt here"

# Configuration
./clauver.ps1 config zai
./clauver.ps1 default zai

# Use default provider
./clauver.ps1 "prompt with default provider"
```

### Features

- ✅ All bash commands supported
- ✅ Custom providers
- ✅ Encrypted secrets storage
- ✅ Automatic updates
- ✅ Tab completion
- ✅ Cross-platform support
```

**Step 4: Commit**

```bash
git add tests/Integration/FullWorkflow.Tests.ps1 README.md docs/POWERSHELL.md
git commit -m "feat: add integration tests and PowerShell documentation"
```

---

## Final Verification

### Step 1: Run all tests

```bash
# Unit tests
pwsh -Command "Invoke-Pester tests/Unit/"

# Integration tests
pwsh -Command "Invoke-Pester tests/Integration/"

# Coverage report
pwsh -Command "Invoke-Pester -CodeCoverage"
```

### Step 2: Manual verification

```bash
# Test all missing features
./clauver.ps1 update --check-only
./clauver.ps1 migrate --check-only
./clauver.ps1 config custom
./clauver.ps1 <TAB> # Test completion
```

### Step 3: Final commit

```bash
git add .
git commit -m "feat: complete PowerShell feature parity with bash implementation

- Implement Update-Clauver with version checking and automatic updates
- Add Invoke-ClauverMigrate for secrets encryption migration
- Support custom providers in configuration and CLI
- Implement PowerShell tab completion
- Add comprehensive integration tests
- Update documentation for PowerShell users"
```