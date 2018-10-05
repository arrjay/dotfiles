#!/usr/bin/env bash

___quiet_input () {
  local ____set_x='' thestr avar="${1:-}"
  printf '%s' 'Input string: ' 1>&2
  chkcmd stty && command stty -echo
  case "${-}" in *x*) ____set_x=x ; set +x ;; esac
  read -r thestr
  [ "${avar}" ] && {
    case "${___printf_supports_v:-}" in
      yes) builtin printf -v "${avar}" '%s' "${thestr}" ;;
      *)   eval "${avar}=\'${thestr}\'" ;;
    esac
  } || printf '%s' "${thestr}"
  [ "${____set_x}" ] && set -x
  printf '\n' 1>&2
  chkcmd stty && command stty echo
  return 0
}

_cloud_logout () {
  unset "${___CLOUD_AUTH_KEYS[@]}"
  ___CLOUD_AUTH_KEYS=()
}
