#!/usr/bin/env fish

# Clauver Fish Completion

complete -c clauver -n "__fish_use_subcommand" -f -xa "help -h --help setup -s version -v --version update list status config test default migrate anthropic zai minimax kimi deepseek custom"

complete -c clauver -n "__fish_seen_subcommand_from test" -xa "anthropic zai minimax kimi deepseek"
complete -c clauver -n "__fish_seen_subcommand_from default" -xa "anthropic zai minimax kimi deepseek"
complete -c clauver -n "__fish_seen_subcommand_from config" -xa "anthropic zai minimax kimi deepseek custom"

complete -c clauver -n "__fish_seen_subcommand_from help" -d "Show help message"
complete -c clauver -n "__fish_seen_subcommand_from -h" -d "Show help message"
complete -c clauver -n "__fish_seen_subcommand_from --help" -d "Show help message"
complete -c clauver -n "__fish_seen_subcommand_from setup" -d "Interactive setup wizard"
complete -c clauver -n "__fish_seen_subcommand_from version" -d "Show current version and check for updates"
complete -c clauver -n "__fish_seen_subcommand_from -v" -d "Show current version and check for updates"
complete -c clauver -n "__fish_seen_subcommand_from --version" -d "Show current version and check for updates"
complete -c clauver -n "__fish_seen_subcommand_from update" -d "Update to the latest version"
complete -c clauver -n "__fish_seen_subcommand_from config" -d "Configure a provider"
complete -c clauver -n "__fish_seen_subcommand_from list" -d "List all configured providers"
complete -c clauver -n "__fish_seen_subcommand_from status" -d "Check status of all providers"
complete -c clauver -n "__fish_seen_subcommand_from test" -d "Test a provider configuration"
complete -c clauver -n "__fish_seen_subcommand_from default" -d "Set or show default provider"
complete -c clauver -n "__fish_seen_subcommand_from migrate" -d "Migrate plaintext secrets to encrypted storage"
complete -c clauver -n "__fish_seen_subcommand_from anthropic" -d "Use Native Anthropic"
complete -c clauver -n "__fish_seen_subcommand_from zai" -d "Switch to Z.AI provider"
complete -c clauver -n "__fish_seen_subcommand_from minimax" -d "Switch to MiniMax provider"
complete -c clauver -n "__fish_seen_subcommand_from kimi" -d "Switch to Moonshot Kimi provider"
complete -c clauver -n "__fish_seen_subcommand_from deepseek" -d "Switch to DeepSeek provider"
complete -c clauver -n "__fish_seen_subcommand_from custom" -d "Switch to custom provider"
complete -c clauver -n "__fish_seen_subcommand_from -s" -d "Interactive setup wizard"
