@{
    # PSScriptAnalyzer settings for Clauver PowerShell module
    # This file suppresses warnings that are not applicable to CLI tools

    # Exclude these rules for all files
    ExcludeRules = @(
        # Write-Host is appropriate for CLI tools to display user-facing output
        'PSAvoidUsingWriteHost'
    )

    # Include rules that should still be checked
    IncludeRules = @(
        'PSAvoidAssignmentToAutomaticVariable',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingUserNameAndPasswordParams',
        'PSDSCDscExamplesPresent',
        'PSDSCDscTestsPresent',
        'PSDSCStandardDscFunctionsInResource',
        'PSMisleadingBacktick',
        'PSMissingModuleManifestField',
        'PSPossibleIncorrectComparisonWithNull',
        'PSProvideCommentHelp',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSUseApprovedVerbs',
        'PSUseBOMForUnicodeEncodedFile',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUsePSCredentialType',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns',
        'PSUseToExportFieldsInManifest',
        'PSUseUTF8EncodingForHelpFile'
    )

    # Custom rule exclusions for specific files or functions
    Rules = @{
        PSUseShouldProcessForStateChangingFunctions = @{
            # These functions already have ShouldProcess support added
            ExcludeFunctions = @(
                'Set-ClauverDefault',
                'Update-Clauver',
                'Set-ClauverConfig',
                'Set-StandardProviderConfig',
                'Set-CustomProviderConfig',
                'Set-ConfigValue',
                'Set-ClauverSecret'
            )
        }
    }
}