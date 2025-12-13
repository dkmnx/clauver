BeforeAll {
    Import-Module $PSScriptRoot/../../Clauver.psm1
}

Describe "Invoke-AgeEncrypt" {
    BeforeAll {
        $TestDir = Join-Path $TestDrive "clauver-age-test"
        New-Item -ItemType Directory -Path $TestDir -Force
        $env:USERPROFILE = $TestDir

        # Create .clauver directory and generate test age key
        $ClauverDir = Join-Path $TestDir ".clauver"
        New-Item -ItemType Directory -Path $ClauverDir -Force | Out-Null
        age-keygen -o (Join-Path $ClauverDir "age.key") 2>$null
    }

    It "Should encrypt text" {
        $plaintext = "test secret"
        $outputFile = Join-Path $TestDir "encrypted.txt"

        Invoke-AgeEncrypt -Plaintext $plaintext -OutputFile $outputFile

        $outputFile | Should -Exist
    }
}
