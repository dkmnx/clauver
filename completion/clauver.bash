#!/bin/bash

# Clauver Bash Completion

_clauver_completion() {

  # shellcheck disable=SC2034
  local cur prev words cword
  _init_completion || return

  local commands="help setup config list status test anthropic zai minimax kimi katcoder"

  if [[ $cword -eq 1 ]]; then
    read -ra COMPREPLY <<< "$(compgen -W "$commands" -- "$cur")"
    return 0
  fi

  if [[ "$prev" == "test" ]]; then
    read -ra COMPREPLY <<< "$(compgen -W "anthropic zai minimax kimi katcoder" -- "$cur")"
    return 0
  fi

  return 0
}

complete -F _clauver_completion clauver
