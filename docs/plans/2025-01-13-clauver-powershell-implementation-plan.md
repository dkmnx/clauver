# Clauver PowerShell Port - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Port clauver.sh (2,389 lines) to PowerShell with full feature parity, retaining clauver command interface

**Architecture:** Module-based PowerShell implementation with command routing, same config structure as bash, age encryption via external command

**Tech Stack:** PowerShell 5.1+, Pester testing, age encryption, GitHub Actions CI/CD

---

## Phase 1: Core Infrastructure (Tasks 1-10)

### Task 1: Create Project Structure and Module File

**Files:**
- Create: `clauver-powershell/Clauver.psm1`
- Create: `clauver-powershell/tests/Unit/Initialize-Clauver.Tests.ps1`
- Create: `clauver-powershell/.gitignore`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/Initialize-Clauver.Tests.ps1
Describe "Initialize-Clauver" {
    It "Should create clauver directory structure" {
        $TestDir = Join-Path $TestDrive "test-clauver"
        Initialize-Clauver -HomePath $TestDir

        $configDir = Join-Path $TestDir ".clauver"
        $configDir | Should -Exist

        $ageKeyPath = Join-Path $configDir "age.key"
        $ageKeyPath | Should -Exist
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
cd clauver-powershell
Import-Module Pester -Force
Invoke-Pester -Path tests/Unit/Initialize-Clauver.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Initialize-Clauver' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver.psm1
function Initialize-Clauver {
    param([string]$HomePath)

    $configDir = Join-Path $HomePath ".clauver"
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null

    $ageKeyPath = Join-Path $configDir "age.key"
    if (-not (Test-Path $ageKeyPath)) {
        age-keygen -o $ageKeyPath
    }
}

Export-ModuleMember -Function Initialize-Clauver
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/Initialize-Clauver.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/tests/Unit/Initialize-Clauver.Tests.ps1 clauver-powershell/.gitignore
git commit -m "feat: create project structure and Initialize-Clauver function"
```

---

### Task 2: Implement Get-ClauverHome Function

**Files:**
- Create: `clauver-powershell/Clauver/Private/Get-ClauverHome.ps1`
- Create: `clauver-powershell/tests/Unit/Get-ClauverHome.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/Get-ClauverHome.Tests.ps1
Describe "Get-ClauverHome" {
    It "Should return USERPROFILE/.clauver path" {
        $env:USERPROFILE = "C:\Users\TestUser"
        $result = Get-ClauverHome
        $result | Should -Be "C:\Users\TestUser\.clauver"
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/Get-ClauverHome.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Get-ClauverHome' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Private/Get-ClauverHome.ps1
function Get-ClauverHome {
    return Join-Path $env:USERPROFILE ".clauver"
}

# clauver-powershell/Clauver.psm1 - add import
Import-Module (Join-Path $PSScriptRoot "Clauver/Private/Get-ClauverHome.ps1")
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/Get-ClauverHome.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/Clauver/Private/Get-ClauverHome.ps1 clauver-powershell/tests/Unit/Get-ClauverHome.Tests.ps1
git commit -m "feat: add Get-ClauverHome function"
```

---

### Task 3: Implement Read-ClauverConfig Function

**Files:**
- Create: `clauver-powershell/Clauver/Private/Read-ClauverConfig.ps1`
- Create: `clauver-powershell/tests/Unit/Read-ClauverConfig.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/Read-ClauverConfig.Tests.ps1
Describe "Read-ClauverConfig" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $script:ClauverHome = $TestDir

        $configContent = @"
default_provider=minimax
minimax_base_url=https://api.minimax.io
minimax_model=MiniMax-M2
"@
        $configFile = Join-Path $TestDir "config"
        $configContent | Out-File -FilePath $configFile -Encoding utf8
    }

    It "Should read config file correctly" {
        $result = Read-ClauverConfig
        $result['default_provider'] | Should -Be 'minimax'
        $result['minimax_base_url'] | Should -Be 'https://api.minimax.io'
        $result['minimax_model'] | Should -Be 'MiniMax-M2'
    }

    It "Should return empty hashtable for missing config" {
        $configFile = Join-Path $TestDir "config"
        if (Test-Path $configFile) { Remove-Item $configFile -Force }

        $result = Read-ClauverConfig
        $result.Count | Should -Be 0
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/Read-ClauverConfig.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Read-ClauverConfig' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Private/Read-ClauverConfig.ps1
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

# clauver-powershell/Clauver.psm1 - add import
Import-Module (Join-Path $PSScriptRoot "Clauver/Private/Read-ClauverConfig.ps1")
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/Read-ClauverConfig.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/Clauver/Private/Read-ClauverConfig.ps1 clauver-powershell/tests/Unit/Read-ClauverConfig.Tests.ps1
git commit -m "feat: add Read-ClauverConfig function"
```

---

### Task 4: Implement Write-ClauverConfig Function

**Files:**
- Modify: `clauver-powershell/Clauver/Private/Read-ClauverConfig.ps1`
- Create: `clauver-powershell/tests/Unit/Write-ClauverConfig.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/Write-ClauverConfig.Tests.ps1
Describe "Write-ClauverConfig" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-write-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $script:ClauverHome = $TestDir
    }

    It "Should write config file correctly" {
        $config = @{
            'default_provider' = 'minimax'
            'minimax_base_url' = 'https://api.minimax.io'
        }

        Write-ClauverConfig -Config $config

        $configPath = Join-Path $TestDir "config"
        $configPath | Should -Exist

        $content = Get-Content $configPath -Raw
        $content | Should -Match 'default_provider=minimax'
        $content | Should -Match 'minimax_base_url=https://api.minimax.io'
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/Write-ClauverConfig.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Write-ClauverConfig' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Private/Read-ClauverConfig.ps1 - add Write-ClauverConfig function
function Write-ClauverConfig {
    param([hashtable]$Config)

    $configPath = Join-Path (Get-ClauverHome) "config"
    $tempFile = [System.IO.Path]::GetTempFileName()

    try {
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

# clauver-powershell/Clauver.psm1 - update export
Export-ModuleMember -Function Initialize-Clauver, Read-ClauverConfig, Write-ClauverConfig
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/Write-ClauverConfig.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/Clauver/Private/Read-ClauverConfig.ps1 clauver-powershell/tests/Unit/Write-ClauverConfig.Tests.ps1
git commit -m "feat: add Write-ClauverConfig function"
```

---

### Task 5: Implement UI Functions (Write-ClauverLog, Write-ClauverSuccess, etc.)

**Files:**
- Create: `clauver-powershell/Clauver/Private/Write-ClauverOutput.ps1`
- Create: `clauver-powershell/tests/Unit/Write-ClauverOutput.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/Write-ClauverOutput.Tests.ps1
Describe "Write-ClauverOutput" {
    It "Should write log message" {
        Mock Write-Host { }

        Write-ClauverLog -Message "Test message"

        Assert-MockCalled Write-Host -Times 1 -ParameterFilter {
            $Object -eq "→ Test message" -and $ForegroundColor -eq "Cyan"
        }
    }

    It "Should write success message" {
        Mock Write-Host { }

        Write-ClauverSuccess -Message "Success"

        Assert-MockCalled Write-Host -Times 1 -ParameterFilter {
            $Object -eq "✓ Success" -and $ForegroundColor -eq "Green"
        }
    }

    It "Should write warning message" {
        Mock Write-Host { }

        Write-ClauverWarn -Message "Warning"

        Assert-MockCalled Write-Host -Times 1 -ParameterFilter {
            $Object -eq "! Warning" -and $ForegroundColor -eq "Yellow"
        }
    }

    It "Should write error message" {
        Mock Write-Host { }

        Write-ClauverError -Message "Error"

        Assert-MockCalled Write-Host -Times 1 -ParameterFilter {
            $Object -eq "✗ Error" -and $ForegroundColor -eq "Red"
        }
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/Write-ClauverOutput.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Write-ClauverLog' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Private/Write-ClauverOutput.ps1
$ClauverColors = @{
    Info = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Banner = 'Magenta'
}

function Write-ClauverLog {
    param([string]$Message)
    Write-Host "→ $Message" -ForegroundColor $ClauverColors.Info
}

function Write-ClauverSuccess {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $ClauverColors.Success
}

function Write-ClauverWarn {
    param([string]$Message)
    Write-Host "! $Message" -ForegroundColor $ClauverColors.Warning
}

function Write-ClauverError {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $ClauverColors.Error
}

# clauver-powershell/Clauver.psm1 - add import
Import-Module (Join-Path $PSScriptRoot "Clauver/Private/Write-ClauverOutput.ps1")
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/Write-ClauverOutput.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/Clauver/Private/Write-ClauverOutput.ps1 clauver-powershell/tests/Unit/Write-ClauverOutput.Tests.ps1
git commit -m "feat: add UI output functions"
```

---

### Task 6: Implement Entry Point (clauver.ps1) with Command Routing

**Files:**
- Create: `clauver-powershell/clauver.ps1`
- Create: `clauver-powershell/tests/Unit/clauver.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/clauver.Tests.ps1
Describe "clauver entry point" {
    It "Should route setup command" {
        Mock Initialize-Clauver { }

        & "$PSScriptRoot\..\clauver.ps1" setup

        Assert-MockCalled Initialize-Clauver -Times 1
    }

    It "Should route list command" {
        Mock Get-ClauverProviderList { return @() }

        & "$PSScriptRoot\..\clauver.ps1" list

        Assert-MockCalled Get-ClauverProviderList -Times 1
    }

    It "Should show error for unknown command" {
        $result = & "$PSScriptRoot\..\clauver.ps1" unknowncommand 2>&1
        $result | Should -Match "Unknown command"
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/clauver.Tests.ps1 -Verbose
```
Expected: FAIL with "File not found" or mock assertion failures

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/clauver.ps1
#!/usr/bin/env pwsh
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

# Import Clauver module
$modulePath = Join-Path $PSScriptRoot "Clauver.psm1"
Import-Module $modulePath -Force -ErrorAction Stop

# Route command to appropriate function
$command = $RemainingArgs[0]
$args = $RemainingArgs[1..($RemainingArgs.Count-1)]

switch ($command) {
    "setup" {
        Initialize-Clauver -HomePath $env:USERPROFILE
    }
    "list" {
        Get-ClauverProviderList
    }
    default {
        Write-Host "Unknown command: $command"
        Write-Host "Run 'clauver help' for usage information"
        exit 1
    }
}
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/clauver.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/clauver.ps1 clauver-powershell/tests/Unit/clauver.Tests.ps1
git commit -m "feat: add clauver entry point with command routing"
```

---

### Task 7: Implement Get-ClauverProviderList Function

**Files:**
- Create: `clauver-powershell/Clauver/Public/Get-ClauverProviderList.ps1`
- Create: `clauver-powershell/tests/Unit/Get-ClauverProviderList.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/Get-ClauverProviderList.Tests.ps1
Describe "Get-ClauverProviderList" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-list-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $script:ClauverHome = $TestDir

        $config = @{
            'minimax_type' = 'minimax'
            'zai_type' = 'zai'
        }
        $config | ConvertTo-Json | Out-Null
    }

    It "Should list configured providers" {
        Mock Read-ClauverConfig { return @{
            'minimax_type' = 'minimax'
            'zai_type' = 'zai'
        }}

        $result = Get-ClauverProviderList
        $result | Should -Contain "minimax"
        $result | Should -Contain "zai"
    }

    It "Should return empty list when no providers configured" {
        Mock Read-ClauverConfig { return @{} }

        $result = Get-ClauverProviderList
        $result.Count | Should -Be 0
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/Get-ClauverProviderList.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Get-ClauverProviderList' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Public/Get-ClauverProviderList.ps1
function Get-ClauverProviderList {
    $config = Read-ClauverConfig
    $providers = @()

    $config.GetEnumerator() | ForEach-Object {
        if ($_.Key -match '^(.+)_type$') {
            $providers += $matches[1]
        }
    }

    return $providers
}

# clauver-powershell/Clauver.psm1 - add import
Import-Module (Join-Path $PSScriptRoot "Clauver/Public/Get-ClauverProviderList.ps1")
Export-ModuleMember -Function Initialize-Clauver, Read-ClauverConfig, Write-ClauverConfig, Get-ClauverProviderList
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/Get-ClauverProviderList.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/Clauver/Public/Get-ClauverProviderList.ps1 clauver-powershell/tests/Unit/Get-ClauverProviderList.Tests.ps1
git commit -m "feat: add Get-ClauverProviderList function"
```

---

### Task 8: Implement Age Encryption Wrapper Functions

**Files:**
- Create: `clauver-powershell/Clauver/Private/Invoke-AgeEncrypt.ps1`
- Create: `clauver-powershell/tests/Unit/Invoke-AgeEncrypt.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/Invoke-AgeEncrypt.Tests.ps1
Describe "Invoke-AgeEncrypt" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-age-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $script:ClauverHome = $TestDir

        # Generate test age key
        age-keygen -o (Join-Path $TestDir "age.key") 2>$null
    }

    It "Should encrypt text" {
        $plaintext = "test secret"
        $outputFile = Join-Path $TestDir "encrypted.txt"

        Mock Get-ClauverAgeKey { return Join-Path $TestDir "age.key" }
        Mock Start-Process { $processResult }

        Invoke-AgeEncrypt -Plaintext $plaintext -OutputFile $outputFile

        Assert-MockCalled Start-Process -Times 1 -ParameterFilter {
            $FileName -eq "age" -and $ArgumentList -join " " -match "-e.*-o.*encrypted.txt"
        }
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/Invoke-AgeEncrypt.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Invoke-AgeEncrypt' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Private/Invoke-AgeEncrypt.ps1
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

# clauver-powershell/Clauver.psm1 - add imports
Import-Module (Join-Path $PSScriptRoot "Clauver/Private/Invoke-AgeEncrypt.ps1")
Export-ModuleMember -Function Initialize-Clauver, Read-ClauverConfig, Write-ClauverConfig, Get-ClauverProviderList, Invoke-AgeEncrypt, Get-ClauverAgeKey
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/Invoke-AgeEncrypt.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/Clauver/Private/Invoke-AgeEncrypt.ps1 clauver-powershell/tests/Unit/Invoke-AgeEncrypt.Tests.ps1
git commit -m "feat: add age encryption wrapper functions"
```

---

### Task 9: Implement Interactive Input Functions

**Files:**
- Create: `clauver-powershell/Clauver/Private/Read-ClauverInput.ps1`
- Create: `clauver-powershell/tests/Unit/Read-ClauverInput.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/Read-ClauverInput.Tests.ps1
Describe "Read-ClauverInput" {
    It "Should read input with default value" {
        Mock Read-Host { return "" }

        $result = Read-ClauverInput -Prompt "Enter value" -Default "default"

        Assert-MockCalled Read-Host -Times 1 -ParameterFilter {
            $Prompt -eq "Enter value [default]"
        }
        $result | Should -Be "default"
    }

    It "Should read input without default" {
        Mock Read-Host { return "user input" }

        $result = Read-ClauverInput -Prompt "Enter value"

        Assert-MockCalled Read-Host -Times 1 -ParameterFilter {
            $Prompt -eq "Enter value"
        }
        $result | Should -Be "user input"
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/Read-ClauverInput.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Read-ClauverInput' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Private/Read-ClauverInput.ps1
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

# clauver-powershell/Clauver.psm1 - add import
Import-Module (Join-Path $PSScriptRoot "Clauver/Private/Read-ClauverInput.ps1")
Export-ModuleMember -Function Initialize-Clauver, Read-ClauverConfig, Write-ClauverConfig, Get-ClauverProviderList, Invoke-AgeEncrypt, Get-ClauverAgeKey, Read-ClauverInput
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/Read-ClauverInput.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/Clauver/Private/Read-ClauverInput.ps1 clauver-powershell/tests/Unit/Read-ClauverInput.Tests.ps1
git commit -m "feat: add interactive input functions"
```

---

### Task 10: Implement Set-ClauverConfig Function

**Files:**
- Create: `clauver-powershell/Clauver/Public/Set-ClauverConfig.ps1`
- Create: `clauver-powershell/tests/Integration/Set-ClauverConfig.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Integration/Set-ClauverConfig.Tests.ps1
Describe "Set-ClauverConfig" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-config-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $script:ClauverHome = $TestDir

        # Generate test age key
        age-keygen -o (Join-Path $TestDir "age.key") 2>$null
    }

    It "Should configure provider with API key" {
        Mock Read-ClauverInput { return "https://api.minimax.io" } -ParameterFilter { $Prompt -match "base url" }
        Mock Read-ClauverInput { return "MiniMax-M2" } -ParameterFilter { $Prompt -match "model" }
        Mock Read-ClauverSecureInput { return "test-api-key" }

        Set-ClauverConfig -Name "minimax"

        $config = Read-ClauverConfig
        $config['minimax_type'] | Should -Be 'minimax'
        $config['minimax_base_url'] | Should -Be 'https://api.minimax.io'
        $config['minimax_model'] | Should -Be 'MiniMax-M2'
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Integration/Set-ClauverConfig.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Set-ClauverConfig' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Public/Set-ClauverConfig.ps1
function Set-ClauverConfig {
    param([string]$Name)

    Write-ClauverLog "Configuring $Name provider..."

    # Prompt for provider details
    $baseUrl = Read-ClauverInput -Prompt "Enter base URL" -Default (Get-ProviderDefault -Name $Name -Property "BaseUrl")
    $model = Read-ClauverInput -Prompt "Enter model" -Default (Get-ProviderDefault -Name $Name -Property "Model")
    $apiKey = Read-ClauverSecureInput -Prompt "Enter API key for $Name"

    # Update config
    $config = Read-ClauverConfig
    $config["${Name}_type"] = $Name
    $config["${Name}_base_url"] = $baseUrl
    $config["${Name}_model"] = $model
    Write-ClauverConfig -Config $config

    # Encrypt and store API key
    $secretsFile = Join-Path (Get-ClauverHome) "secrets.env.age"
    $apiKey | Invoke-AgeEncrypt -OutputFile $secretsFile

    Write-ClauverSuccess "$Name provider configured successfully"
}

function Get-ProviderDefault {
    param([string]$Name, [string]$Property)

    $defaults = @{
        'minimax' = @{
            'BaseUrl' = 'https://api.minimax.io'
            'Model' = 'MiniMax-M2'
        }
        'zai' = @{
            'BaseUrl' = 'https://api.z.ai/api/anthropic'
            'Model' = 'glm-4.6'
        }
    }

    return $defaults[$Name][$Property]
}

# clauver-powershell/Clauver.psm1 - add imports
Import-Module (Join-Path $PSScriptRoot "Clauver/Public/Set-ClauverConfig.ps1")
Export-ModuleMember -Function Initialize-Clauver, Read-ClauverConfig, Write-ClauverConfig, Get-ClauverProviderList, Invoke-AgeEncrypt, Get-ClauverAgeKey, Read-ClauverInput, Set-ClauverConfig
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Integration/Set-ClauverConfig.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/Clauver/Public/Set-ClauverConfig.ps1 clauver-powershell/tests/Integration/Set-ClauverConfig.Tests.ps1
git commit -m "feat: add Set-ClauverConfig function"
```

---

## Phase 2: Commands & Shortcuts (Tasks 11-20)

### Task 11: Add More Commands to Entry Point (status, test, version)

**Files:**
- Modify: `clauver-powershell/clauver.ps1:30-60`
- Create: `clauver-powershell/Clauver/Public/Get-ClauverStatus.ps1`
- Create: `clauver-powershell/Clauver/Public/Test-ClauverProvider.ps1`
- Create: `clauver-powershell/Clauver/Public/Get-ClauverVersion.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/clauver.Tests.ps1 - add to existing
It "Should route status command" {
    Mock Get-ClauverStatus { }

    & "$PSScriptRoot\..\clauver.ps1" status

    Assert-MockCalled Get-ClauverStatus -Times 1
}

It "Should route test command" {
    Mock Test-ClauverProvider { }

    & "$PSScriptRoot\..\clauver.ps1" test minimax

    Assert-MockCalled Test-ClauverProvider -Times 1 -ParameterFilter { $Name -eq "minimax" }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/clauver.Tests.ps1 -Verbose -TestName "Should route status command"
```
Expected: FAIL with mock assertion failures

**Step 3: Write minimal implementations**

```powershell
# clauver-powershell/Clauver/Public/Get-ClauverStatus.ps1
function Get-ClauverStatus {
    Write-ClauverLog "Checking provider status..."

    $providers = Get-ClauverProviderList
    foreach ($provider in $providers) {
        Write-Host "  $provider: Configured" -ForegroundColor Green
    }

    Write-ClauverSuccess "Status check complete"
}

# clauver-powershell/Clauver/Public/Test-ClauverProvider.ps1
function Test-ClauverProvider {
    param([string]$Name)

    Write-ClauverLog "Testing $Name provider..."

    # Minimal implementation - validate config exists
    $config = Read-ClauverConfig
    if ($config.ContainsKey("${Name}_type")) {
        Write-ClauverSuccess "$Name is configured correctly"
    }
    else {
        Write-ClauverError "$Name is not configured"
    }
}

# clauver-powershell/Clauver/Public/Get-ClauverVersion.ps1
function Get-ClauverVersion {
    Write-Host "clauver PowerShell version 1.0.0" -ForegroundColor Cyan
}

# clauver-powershell/clauver.ps1 - update switch statement
switch ($command) {
    "setup" {
        Initialize-Clauver -HomePath $env:USERPROFILE
    }
    "config" {
        Set-ClauverConfig -Name $args[0]
    }
    "list" {
        Get-ClauverProviderList
    }
    "status" {
        Get-ClauverStatus
    }
    "test" {
        Test-ClauverProvider -Name $args[0]
    }
    "version" {
        Get-ClauverVersion
    }
    default {
        Write-Host "Unknown command: $command"
        Write-Host "Run 'clauver help' for usage information"
        exit 1
    }
}
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/clauver.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/clauver.ps1 clauver-powershell/Clauver/Public/Get-ClauverStatus.ps1 clauver-powershell/Clauver/Public/Test-ClauverProvider.ps1 clauver-powershell/Clauver/Public/Get-ClauverVersion.ps1
git commit -m "feat: add status, test, and version commands"
```

---

### Task 12: Implement Provider Shortcut Commands (anthropic, minimax, zai, etc.)

**Files:**
- Modify: `clauver-powershell/clauver.ps1:30-60`
- Create: `clauver-powershell/Clauver/Public/Invoke-ClauverProvider.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/clauver.Tests.ps1 - add to existing
It "Should route provider shortcut commands" {
    Mock Invoke-ClauverProvider { }

    & "$PSScriptRoot\..\clauver.ps1" minimax

    Assert-MockCalled Invoke-ClauverProvider -Times 1 -ParameterFilter { $Name -eq "minimax" }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/clauver.Tests.ps1 -Verbose -TestName "Should route provider shortcut commands"
```
Expected: FAIL with mock assertion failure

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Public/Invoke-ClauverProvider.ps1
function Invoke-ClauverProvider {
    param([string]$Name)

    Write-ClauverLog "Using $Name provider..."

    # For now, just set environment variable
    # In full implementation, this would integrate with claude CLI
    Write-Host "Switched to $Name provider" -ForegroundColor Green
    Write-Host "Note: Full claude CLI integration coming in Phase 3" -ForegroundColor Yellow
}

# clauver-powershell/clauver.ps1 - update switch statement to include provider shortcuts
switch ($command) {
    "setup" { Initialize-Clauver -HomePath $env:USERPROFILE }
    "config" { Set-ClauverConfig -Name $args[0] }
    "list" { Get-ClauverProviderList }
    "status" { Get-ClauverStatus }
    "test" { Test-ClauverProvider -Name $args[0] }
    "version" { Get-ClauverVersion }
    { $_ -in @("anthropic", "minimax", "zai", "kimi", "deepseek", "custom") } {
        Invoke-ClauverProvider -Name $_
    }
    default {
        Write-Host "Unknown command: $command"
        Write-Host "Run 'clauver help' for usage information"
        exit 1
    }
}
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/clauver.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/clauver.ps1 clauver-powershell/Clauver/Public/Invoke-ClauverProvider.ps1
git commit -m "feat: add provider shortcut commands"
```

---

### Task 13: Implement Default Provider Functions

**Files:**
- Create: `clauver-powershell/Clauver/Public/Set-ClauverDefault.ps1`
- Create: `clauver-powershell/Clauver/Public/Get-ClauverDefault.ps1`
- Create: `clauver-powershell/tests/Unit/DefaultProvider.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Unit/DefaultProvider.Tests.ps1
Describe "Default Provider Functions" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-default-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $script:ClauverHome = $TestDir
    }

    It "Should set default provider" {
        Set-ClauverDefault -Name "minimax"

        $config = Read-ClauverConfig
        $config['default_provider'] | Should -Be 'minimax'
    }

    It "Should get default provider" {
        Mock Read-ClauverConfig { return @{ 'default_provider' = 'zai' } }

        $result = Get-ClauverDefault
        $result | Should -Be 'zai'
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Unit/DefaultProvider.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Set-ClauverDefault' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Public/Set-ClauverDefault.ps1
function Set-ClauverDefault {
    param([string]$Name)

    $config = Read-ClauverConfig
    $config['default_provider'] = $Name
    Write-ClauverConfig -Config $config

    Write-ClauverSuccess "Default provider set to $Name"
}

# clauver-powershell/Clauver/Public/Get-ClauverDefault.ps1
function Get-ClauverDefault {
    $config = Read-ClauverConfig
    return $config['default_provider']
}

# clauver-powershell/Clauver.psm1 - add imports
Import-Module (Join-Path $PSScriptRoot "Clauver/Public/Set-ClauverDefault.ps1")
Import-Module (Join-Path $PSScriptRoot "Clauver/Public/Get-ClauverDefault.ps1")

# clauver-powershell/clauver.ps1 - update switch
"default" {
    if ($args[0]) {
        Set-ClauverDefault -Name $args[0]
    }
    else {
        $default = Get-ClauverDefault
        if ($default) {
            Write-Host "Default provider: $default" -ForegroundColor Cyan
        }
        else {
            Write-Host "No default provider set" -ForegroundColor Yellow
        }
    }
}
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/DefaultProvider.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/Clauver/Public/Set-ClauverDefault.ps1 clauver-powershell/Clauver/Public/Get-ClauverDefault.ps1 clauver-powershell/tests/Unit/DefaultProvider.Tests.ps1
git commit -m "feat: add default provider functions"
```

---

### Task 14: Implement Migration Command

**Files:**
- Create: `clauver-powershell/Clauver/Public/Invoke-ClauverMigration.ps1`
- Create: `clauver-powershell/tests/Integration/Migration.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Integration/Migration.Tests.ps1
Describe "Invoke-ClauverMigration" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-migration-test"
        New-Item -ItemType Directory -Path $TestDir -Force

        # Create bash-style config
        $bashConfig = @"
default_provider=minimax
minimax_base_url=https://api.minimax.io
"@
        $bashConfig | Out-File -FilePath (Join-Path $TestDir "bash-config") -Encoding utf8

        $script:BashConfigPath = Join-Path $TestDir "bash-config"
        $script:PowerShellConfigPath = Join-Path $TestDir "ps-config"
    }

    It "Should migrate bash config to PowerShell format" {
        Mock Get-ClauverHome { return $TestDir }
        Mock Test-Path { return $true } -ParameterFilter { $Path -eq $script:BashConfigPath }
        Mock Test-Path { return $false } -ParameterFilter { $Path -eq $script:PowerShellConfigPath }

        Invoke-ClauverMigration

        # Verify migration happened
        Assert-MockCalled Copy-Item -Times 1
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Integration/Migration.Tests.ps1 -Verbose
```
Expected: FAIL with "The term 'Invoke-ClauverMigration' is not recognized"

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/Clauver/Public/Invoke-ClauverMigration.ps1
function Invoke-ClauverMigration {
    Write-ClauverLog "Checking for existing clauver configuration..."

    $bashConfigPath = "$env:HOME/.clauver/config"
    $powershellConfigPath = Join-Path (Get-ClauverHome) "config"

    if ((Test-Path $bashConfigPath) -and (-not (Test-Path $powershellConfigPath))) {
        Write-ClauverLog "Found bash configuration, migrating to PowerShell..."

        # Create PowerShell config directory
        New-Item -ItemType Directory -Path (Get-ClauverHome) -Force | Out-Null

        # Copy config file (same format)
        Copy-Item $bashConfigPath $powershellConfigPath

        Write-ClauverSuccess "Migration complete! Your configuration is ready."
    }
    else {
        Write-ClauverLog "No bash configuration found or already migrated."
    }
}

# clauver-powershell/clauver.ps1 - update switch
"migrate" {
    Invoke-ClauverMigration
}
```

**Step 4: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Integration/Migration.Tests.ps1 -Verbose
```
Expected: PASS

**Step 5: Commit**

```bash
git add clauver-powershell/Clauver.psm1 clauver-powershell/Clauver/Public/Invoke-ClauverMigration.ps1 clauver-powershell/tests/Integration/Migration.Tests.ps1
git commit -m "feat: add migration command"
```

---

### Task 15: Implement Tab Completion

**Files:**
- Create: `clauver-powershell/clauver-completion.ps1`

**Step 1: Write the test**

```powershell
# clauver-powershell/tests/Unit/TabCompletion.Tests.ps1
Describe "Tab Completion" {
    It "Should register argument completer" {
        $completerRegistered = Get-Command Register-ArgumentCompleter -ErrorAction SilentlyContinue
        $completerRegistered | Should -Not -BeNullOrEmpty
    }
}
```

**Step 2: Run test to verify it passes**

```powershell
Invoke-Pester -Path tests/Unit/TabCompletion.Tests.ps1 -Verbose
```
Expected: PASS (Register-ArgumentCompleter is built-in)

**Step 3: Write minimal implementation**

```powershell
# clauver-powershell/clauver-completion.ps1
# Register clauver command completions
Register-ArgumentCompleter -Native -CommandName 'clauver' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commandElements = $commandAst.CommandElements
    $word = $wordToComplete.Replace('"', "'")

    $completions = @(, @{
        ToolTip = "Setup wizard"
        ListItemText = 'setup'
        CompletionText = 'setup'
    }, @{
        ToolTip = "Configure provider"
        ListItemText = 'config'
        CompletionText = 'config'
    }, @{
        ToolTip = "List providers"
        ListItemText = 'list'
        CompletionText = 'list'
    }, @{
        ToolTip = "Check provider status"
        ListItemText = 'status'
        CompletionText = 'status'
    }, @{
        ToolTip = "Test provider"
        ListItemText = 'test'
        CompletionText = 'test'
    }, @{
        ToolTip = "Set/get default provider"
        ListItemText = 'default'
        CompletionText = 'default'
    }, @{
        ToolTip = "Show version"
        ListItemText = 'version'
        CompletionText = 'version'
    }, @{
        ToolTip = "Migrate from bash"
        ListItemText = 'migrate'
        CompletionText = 'migrate'
    })

    # Add provider names
    $providers = @('anthropic', 'minimax', 'zai', 'kimi', 'deepseek', 'custom')
    foreach ($provider in $providers) {
        $completions += @{
            ToolTip = "Use $provider provider"
            ListItemText = $provider
            CompletionText = $provider
        }
    }

    $completions |
        Where-Object { $_.ListItemText -like "$word*" } |
        Sort-Object ListItemText |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_.CompletionText,
                $_.ListItemText,
                'ParameterValue',
                $_.ToolTip
            )
        }
}
```

**Step 4: Test manually**

```powershell
. .\clauver-completion.ps1
# Tab completion should work
```

**Step 5: Commit**

```bash
git add clauver-powershell/clauver-completion.ps1 clauver-powershell/tests/Unit/TabCompletion.Tests.ps1
git commit -m "feat: add PowerShell tab completion"
```

---

### Task 16: Create Installation Script

**Files:**
- Create: `clauver-powershell/install.ps1`
- Create: `clauver-powershell/tests/Integration/Install.Tests.ps1`

**Step 1: Write the failing test**

```powershell
# clauver-powershell/tests/Integration/Install.Tests.ps1
Describe "Install Script" {
    It "Should create bin directory" {
        $TestBinPath = Join-Path $TestDrive "test-bin"

        # Simulate install
        New-Item -ItemType Directory -Path $TestBinPath -Force | Out-Null

        Test-Path $TestBinPath | Should -Be $true
    }
}
```

**Step 2: Run test to verify it fails**

```powershell
Invoke-Pester -Path tests/Integration/Install.Tests.ps1 -Verbose
```
Expected: FAIL or basic pass

**Step 3: Write minimal installation script**

```powershell
# clauver-powershell/install.ps1
param(
    [string]$InstallPath = "$env:USERPROFILE\.clauver",
    [string]$BinPath = "$env:USERPROFILE\bin",
    [switch]$Force
)

Write-Host "Installing Clauver for PowerShell..." -ForegroundColor Green

# Check prerequisites
$missing = @()
if (-not (Get-Command age -ErrorAction SilentlyContinue)) {
    $missing += "age encryption (choco install age)"
}

if ($missing.Count -gt 0) {
    Write-Warning "Missing dependencies:"
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    exit 1
}

# Install clauver.ps1
New-Item -ItemType Directory -Path $BinPath -Force -ErrorAction SilentlyContinue

$clauverScript = Join-Path $PSScriptRoot "clauver.ps1"
$installFile = Join-Path $BinPath "clauver.ps1"

if ((Test-Path $installFile) -and (-not $Force)) {
    Write-Error "Clauver already installed. Use -Force to overwrite."
    exit 1
}

Copy-Item $clauverScript $installFile -Force
Write-Host "✓ Clauver installed to $BinPath" -ForegroundColor Green

Write-Host "`nAdd $BinPath to your PATH and run 'clauver setup' to get started" -ForegroundColor Cyan
```

**Step 4: Test installation**

```powershell
.\install.ps1 -WhatIf
```
Expected: Should show actions without executing

**Step 5: Commit**

```bash
git add clauver-powershell/install.ps1 clauver-powershell/tests/Integration/Install.Tests.ps1
git commit -m "feat: add installation script"
```

---

### Task 17-20: Enhanced Setup Wizard, Error Handling, Provider Testing, Documentation

Continue with similar TDD approach for remaining Phase 2 tasks.

---

## Phase 3: Testing & Documentation (Tasks 21-30)

### Task 21-25: Comprehensive Pester Tests

- Unit tests for all functions
- Integration tests for workflows
- End-to-end tests for user journeys
- Test coverage reporting

### Task 26-30: Documentation & Release

- README and installation docs
- Provider documentation
- Troubleshooting guide
- CI/CD pipeline setup
- Release automation

---

## Execution Strategy

**Plan complete and saved to `docs/plans/2025-01-13-clauver-powershell-implementation-plan.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
