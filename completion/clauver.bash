#!/bin/bash

# Clauver Bash Completion

_clauver_completion() {

  # shellcheck disable=SC2034
  local cur prev words cword
  _init_completion || return

  local commands="help setup -s -h --help version -v --version update list status config test default migrate anthropic zai minimax kimi deepseek custom"

  if [[ $cword -eq 1 ]]; then
    read -ra COMPREPLY <<< "$(compgen -W "$commands" -- "$cur")"
    return 0
  fi

  if [[ "$prev" == "test" ]]; then
    read -ra COMPREPLY <<< "$(compgen -W "anthropic zai minimax kimi deepseek" -- "$cur")"
    return 0
  fi

  if [[ "$prev" == "default" ]]; then
    read -ra COMPREPLY <<< "$(compgen -W "anthropic zai minimax kimi deepseek" -- "$cur")"
    return 0
  fi

  if [[ "$prev" == "config" ]]; then
    read -ra COMPREPLY <<< "$(compgen -W "anthropic zai minimax kimi deepseek custom" -- "$cur")"
    return 0
  fi

  return 0
}

complete -F _clauver_completion clauver
