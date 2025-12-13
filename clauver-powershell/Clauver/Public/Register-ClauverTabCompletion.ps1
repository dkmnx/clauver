function Register-ClauverTabCompletion {
    $scriptBlock = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

        $completions = @(
            @{ CompletionText = 'setup';   ToolTip = 'Initialize clauver configuration' }
            @{ CompletionText = 'list';    ToolTip = 'List all configured providers' }
            @{ CompletionText = 'status';  ToolTip = 'Check provider status' }
            @{ CompletionText = 'test';    ToolTip = 'Test a provider configuration' }
            @{ CompletionText = 'version'; ToolTip = 'Show version information' }
            @{ CompletionText = 'default'; ToolTip = 'Set or show default provider' }
            @{ CompletionText = 'migrate'; ToolTip = 'Migrate plaintext secrets to encrypted' }
            @{ CompletionText = 'anthropic'; ToolTip = 'Use anthropic provider' }
            @{ CompletionText = 'minimax';  ToolTip = 'Use minimax provider' }
            @{ CompletionText = 'zai';      ToolTip = 'Use zai provider' }
            @{ CompletionText = 'kimi';     ToolTip = 'Use kimi provider' }
            @{ CompletionText = 'deepseek'; ToolTip = 'Use deepseek provider' }
            @{ CompletionText = 'custom';   ToolTip = 'Use custom provider' }
        )

        foreach ($completion in $completions) {
            if ($completion.CompletionText -like "$wordToComplete*") {
                [System.Management.Automation.CompletionResult]::new(
                    $completion.CompletionText,
                    $completion.CompletionText,
                    'ParameterValue',
                    $completion.ToolTip
                )
            }
        }
    }

    Register-ArgumentCompleter -Native -CommandName 'clauver' -ScriptBlock $scriptBlock
}
