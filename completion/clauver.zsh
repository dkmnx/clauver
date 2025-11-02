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
          _arguments '1: :(anthropic zai minimax kimi katcoder)'
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
      'setup:Interactive setup wizard'
      'config:Configure a provider'
      'list:List all configured providers'
      'status:Check status of all providers'
      'test:Test a provider configuration'
      'anthropic:Use Native Anthropic'
      'zai:Switch to Z.AI provider'
      'minimax:Switch to MiniMax provider'
      'kimi:Switch to Moonshot Kimi provider'
      'katcoder:Switch to KAT-Coder provider'
    )
    _describe 'commands' commands
  }
}

_clauver "$@"
