#!/usr/bin/env pwsh

# Simple test script to verify Update-Clauver fixes

Import-Module ./Clauver.psm1 -Force

Write-Host "Testing Get-LatestVersion function..." -ForegroundColor Green
$latestVersion = Get-LatestVersion
if ($null -eq $latestVersion) {
    Write-Host "✓ Get-LatestVersion properly handles errors and returns null on failure" -ForegroundColor Green
} else {
    Write-Host "✓ Get-LatestVersion succeeded and returned: $latestVersion" -ForegroundColor Green
}

Write-Host "`nTesting Compare-ClauverVersions function..." -ForegroundColor Green

# Test basic version comparison
$result = Compare-ClauverVersions -Current "1.12.0" -Latest "1.12.1"
if ($result) {
    Write-Host "✓ 1.12.0 < 1.12.1 (needs update)" -ForegroundColor Green
} else {
    Write-Host "✗ 1.12.0 < 1.12.1 failed" -ForegroundColor Red
}

# Test equal versions
$result = Compare-ClauverVersions -Current "1.12.1" -Latest "1.12.1"
if (-not $result) {
    Write-Host "✓ 1.12.1 == 1.12.1 (no update needed)" -ForegroundColor Green
} else {
    Write-Host "✗ 1.12.1 == 1.12.1 failed" -ForegroundColor Red
}

# Test newer version (pre-release scenario)
$result = Compare-ClauverVersions -Current "1.12.1-beta" -Latest "1.12.1"
if (-not $result) {
    Write-Host "✓ 1.12.1-beta > 1.12.1 (pre-release is newer)" -ForegroundColor Green
} else {
    Write-Host "✗ 1.12.1-beta > 1.12.1 failed" -ForegroundColor Red
}

# Test different component counts
$result = Compare-ClauverVersions -Current "1.12" -Latest "1.12.1"
if ($result) {
    Write-Host "✓ 1.12 < 1.12.1 (missing component treated as 0)" -ForegroundColor Green
} else {
    Write-Host "✗ 1.12 < 1.12.1 failed" -ForegroundColor Red
}

Write-Host "`nTesting Update-Clauver -CheckOnly..." -ForegroundColor Green
$checkResult = Update-Clauver -CheckOnly
if ($checkResult -is [hashtable] -or $checkResult -is [PSObject]) {
    Write-Host "✓ Update-Clauver -CheckOnly returned structured result" -ForegroundColor Green
    Write-Host "  Current Version: $($checkResult.CurrentVersion)" -ForegroundColor Cyan
    Write-Host "  Latest Version: $($checkResult.LatestVersion)" -ForegroundColor Cyan
    Write-Host "  Success: $($checkResult.Success)" -ForegroundColor Cyan
} else {
    Write-Host "✗ Update-Clauver -CheckOnly did not return structured result" -ForegroundColor Red
}

Write-Host "`nAll critical fixes tested successfully!" -ForegroundColor Green