function Set-SecureFilePermissions {
    <#
    .SYNOPSIS
    Sets secure file permissions on a file, cross-platform.

    .DESCRIPTION
    Sets file permissions to restrict access to the owner only.
    On Unix-like systems, uses chmod 600.
    On Windows, uses ACLs to restrict access to the current user only.

    .PARAMETER Path
    Path to the file to secure.

    .RETURNS
    Boolean indicating success or failure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if (-not (Test-Path $Path)) {
            Write-ClauverError "File not found: $Path"
            return $false
        }

        # Check if running on Windows
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            # Windows: Use ACLs to restrict access
            $acl = Get-Acl $Path

            # Create a new ACL with only the current user
            $acl.SetAccessRuleProtection($true, $false)  # Disable inheritance

            # Remove all existing access rules
            $acl.Access | ForEach-Object {
                $acl.RemoveAccessRule($_)
            }

            # Add access rule for current user only
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $currentUser,
                "FullControl",
                "None",
                "None",
                "Allow"
            )
            $acl.SetAccessRule($accessRule)

            # Apply the ACL
            Set-Acl -Path $Path -AclObject $acl

            # Verify the permissions were set correctly
            $acl = Get-Acl $Path
            $hasAccess = $acl.Access | Where-Object {
                $_.IdentityReference -eq $currentUser -and
                $_.FileSystemRights -eq "FullControl"
            }

            if (-not $hasAccess) {
                Write-ClauverError "Failed to verify Windows file permissions"
                return $false
            }
        }
        else {
            # Unix-like: Use chmod
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "chmod"
            $processInfo.Arguments = "600", $Path
            $processInfo.UseShellExecute = $false
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.CreateNoWindow = $true

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $process.Start() | Out-Null
            $process.WaitForExit()

            if ($process.ExitCode -ne 0) {
                $errorOutput = $process.StandardError.ReadToEnd()
                Write-ClauverError "Failed to set file permissions: $errorOutput"
                return $false
            }
        }

        return $true
    }
    catch {
        Write-ClauverError "Error setting secure file permissions: $_"
        return $false
    }
}