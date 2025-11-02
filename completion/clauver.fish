#!/usr/bin/env fish

# Clauver Fish Completion

complete -c clauver -n "__fish_use_subcommand" -f -xa "help setup config list status test anthropic zai minimax kimi katcoder"

complete -c clauver -n "__fish_seen_subcommand_from test" -xa "anthropic zai minimax kimi katcoder"

complete -c clauver -n "__fish_seen_subcommand_from help" -d "Show help message"
complete -c clauver -n "__fish_seen_subcommand_from setup" -d "Interactive setup wizard"
complete -c clauver -n "__fish_seen_subcommand_from config" -d "Configure a provider"
complete -c clauver -n "__fish_seen_subcommand_from list" -d "List all configured providers"
complete -c clauver -n "__fish_seen_subcommand_from status" -d "Check status of all providers"
complete -c clauver -n "__fish_seen_subcommand_from test" -d "Test a provider configuration"
complete -c clauver -n "__fish_seen_subcommand_from anthropic" -d "Use Native Anthropic"
complete -c clauver -n "__fish_seen_subcommand_from zai" -d "Switch to Z.AI provider"
complete -c clauver -n "__fish_seen_subcommand_from minimax" -d "Switch to MiniMax provider"
complete -c clauver -n "__fish_seen_subcommand_from kimi" -d "Switch to Moonshot Kimi provider"
complete -c clauver -n "__fish_seen_subcommand_from katcoder" -d "Switch to KAT-Coder provider"
