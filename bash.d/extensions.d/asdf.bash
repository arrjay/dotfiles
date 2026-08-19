#!/usr/bin/env bash

## asdf - prefer our version over the system one, but
___hook_asdf () {
  local asdf
  for asdf in "${HOME}/.asdf/asdf.sh" /opt/homebrew/opt/asdf/libexec/asdf.sh ; do
    [[ -e "${asdf}" ]] && . "${asdf}" && return 0
  done
  return 0
}

___hook_asdf
unset -f ___hook_asdf
