BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Write-ClauverOutput" {
    It "Should write log message without error" {
        { Write-ClauverLog -Message "Test message" } | Should -Not -Throw
    }

    It "Should write success message without error" {
        { Write-ClauverSuccess -Message "Success" } | Should -Not -Throw
    }

    It "Should write warning message without error" {
        { Write-ClauverWarn -Message "Warning" } | Should -Not -Throw
    }

    It "Should write error message without error" {
        { Write-ClauverError -Message "Error" } | Should -Not -Throw
    }

    It "Should handle empty message" {
        { Write-ClauverLog -Message "" } | Should -Not -Throw
    }

    It "Should handle special characters in message" {
        { Write-ClauverLog -Message "Test with special chars: !@#$%^&*()" } | Should -Not -Throw
    }
}

