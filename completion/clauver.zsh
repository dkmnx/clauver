# compdef clauver

_clauver() {
  local context curcontext="clauver" state line
  typeset -A opt_args

  _arguments \
    '1: :(_clauver_commands)' \
    '*::arg:->args' && return 0

  case $state in
    args)
      case $words[1] in
        test)
          _arguments '1: :(anthropic zai minimax kimi)'
          ;;
        default)
          _arguments '1: :(anthropic zai minimax kimi)'
          ;;
        *)
          ;;
      esac
      ;;
  esac
}

(( $+functions[_clauver_commands] )) || {
  _clauver_commands() {
    local commands; commands=(
      'help:Show help message'
      '-h:Show help message'
      '--help:Show help message'
      'setup:Interactive setup wizard'
      'version:Show current version and check for updates'
      '-v:Show current version and check for updates'
      '--version:Show current version and check for updates'
      'update:Update to the latest version'
      'config:Configure a provider'
      'list:List all configured providers'
      'status:Check status of all providers'
      'test:Test a provider configuration'
      'default:Set or show default provider'
      'migrate:Migrate plaintext secrets to encrypted storage'
      'anthropic:Use Native Anthropic'
      'zai:Switch to Z.AI provider'
      'minimax:Switch to MiniMax provider'
      'kimi:Switch to Moonshot Kimi provider'
    )
    _describe 'commands' commands
  }
}

_clauver "$@"
