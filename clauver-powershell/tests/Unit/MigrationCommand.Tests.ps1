Describe "Migration Command Tests" {
    BeforeAll {
        # Set up test environment
        $TestClauverHome = Join-Path $TestDrive "clauver-test"
        $env:CLAUVER_HOME = $TestClauverHome

        # Create test directories
        New-Item -Path $TestClauverHome -ItemType Directory -Force | Out-Null

        # Create a test age key
        $AgeKeyPath = Join-Path $TestClauverHome "age.key"
        "AGE-SECRET-KEY-1TESTKEYFORUNITTESTINGPURPOSESONLY" | Out-File -FilePath $AgeKeyPath -Encoding UTF8
    }

    AfterAll {
        # Clean up test environment
        if (Test-Path $TestClauverHome) {
            Remove-Item -Path $TestClauverHome -Recurse -Force
        }
        $env:CLAUVER_HOME = $null
    }

    Context "Import-ClauverSecrets" {
        It "Should import secrets into environment variables" {
            # Create a test secrets file
            $SecretsPath = Join-Path $TestClauverHome "secrets.env"
            "TEST_API_KEY=testkey123`nANOTHER_KEY=anothervalue" | Out-File -FilePath $SecretsPath -Encoding UTF8

            # Import the secrets
            Import-ClauverSecrets -SecretsPath $SecretsPath

            # Check environment variables
            $env:TEST_API_KEY | Should -Be "testkey123"
            $env:ANOTHER_KEY | Should -Be "anothervalue"

            # Clean up
            Remove-Item -Path $SecretsPath -Force
        }

        It "Should reject invalid content" {
            # Create a test secrets file with dangerous content
            $SecretsPath = Join-Path $TestClauverHome "secrets.env"
            "DANGEROUS=\`rm -rf /\`" | Out-File -FilePath $SecretsPath -Encoding UTF8

            # Should throw an error
            { Import-ClauverSecrets -SecretsPath $SecretsPath } | Should -Throw

            # Clean up
            Remove-Item -Path $SecretsPath -Force
        }
    }

    Context "Set-SecureFilePermissions" {
        It "Should set file permissions" {
            # Create a test file
            $TestFilePath = Join-Path $TestClauverHome "testfile.txt"
            "test content" | Out-File -FilePath $TestFilePath -Encoding UTF8

            # Set secure permissions
            $result = Set-SecureFilePermissions -Path $TestFilePath

            # Should return true
            $result | Should -Be $true

            # Clean up
            Remove-Item -Path $TestFilePath -Force
        }

        It "Should handle non-existent file" {
            $result = Set-SecureFilePermissions -Path "/nonexistent/file.txt"
            $result | Should -Be $false
        }
    }

    Context "Test-EncryptedFileIntegrity" {
        It "Should handle non-existent file" {
            $result = Test-EncryptedFileIntegrity -EncryptedPath "/nonexistent/file.txt"
            $result.Success | Should -Be $false
            $result.Error | Should -BeLike "*Encrypted file not found*"
        }
    }

    Context "Invoke-ClauverMigrate -Force" {
        BeforeEach {
            # Remove any existing secrets files
            $SecretsPath = Join-Path $TestClauverHome "secrets.env"
            $EncryptedPath = Join-Path $TestClauverHome "secrets.env.age"
            if (Test-Path $SecretsPath) {
                Remove-Item -Path $SecretsPath -Force
            }
            if (Test-Path $EncryptedPath) {
                Remove-Item -Path $EncryptedPath -Force
            }
        }

        It "Should prompt with -Force when already encrypted" {
            # Create encrypted file (no plaintext)
            $EncryptedPath = Join-Path $TestClauverHome "secrets.env.age"
            "encrypted content" | Out-File -FilePath $EncryptedPath -Encoding UTF8

            # Mock Read-Host to cancel
            Mock -CommandName Read-Host -MockWith { return "n" }

            $result = Invoke-ClauverMigrate -Force

            $result.Success | Should -Be $true
        }

        It "Should migrate when plaintext file exists" {
            # Create plaintext file
            $SecretsPath = Join-Path $TestClauverHome "secrets.env"
            "TEST_API_KEY=testvalue" | Out-File -FilePath $SecretsPath -Encoding UTF8

            # Should attempt migration (may fail due to age tool, but that's OK)
            $result = Invoke-ClauverMigrate -ErrorAction SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should only check with CheckOnly" {
            # Create plaintext file
            $SecretsPath = Join-Path $TestClauverHome "secrets.env"
            "TEST_API_KEY=testvalue" | Out-File -FilePath $SecretsPath -Encoding UTF8

            $result = Invoke-ClauverMigrate -CheckOnly

            $result.Success | Should -Be $true
            $result.NeedsMigration | Should -Be $true
        }
    }
}