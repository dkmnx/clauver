# Changelog

All notable changes to the Clauver PowerShell module will be documented in this file.

## [Unreleased - 2025-12-13]

### Fixed
- Added missing imports to Clauver.psm1:
  - ClauverConstants.ps1 - Contains provider defaults and configuration constants
  - Format-ClauverMaskedKey.ps1 - Contains function to mask API keys for display
- Reordered imports to ensure dependencies are loaded in the correct order (constants first, then other files)
- Added error handling around Set-ClauverConfig calls in Show-ClauverSetup.ps1 to catch and display any configuration errors
- Verified that Show-ClauverSetup is properly exported in the module

## Changes Details

### Module Import Fixes
The module now properly imports all required dependencies in the correct order:

1. Constants are loaded first (ClauverConstants.ps1) as other modules depend on these values
2. Helper functions are loaded next, including Format-ClauverMaskedKey which is used by Set-ClauverConfig
3. All other private and public functions are loaded in their original order

### Error Handling Improvements
The setup wizard now includes comprehensive error handling:

```powershell
try {
    Set-ClauverConfig -Provider "zai" -ErrorAction Stop
}
catch {
    Write-ClauverError "Failed to configure Z.AI: $_"
    exit 1
}
```

This ensures users get clear error messages if configuration fails, rather than experiencing unhandled exceptions.

### Module Exports
Verified that all public functions are properly exported:
- Show-ClauverSetup is now correctly exported and available for use
- Get-ClauverProvider is properly exported (function name differs from file name)

These fixes ensure the setup wizard works correctly without any dependency errors.