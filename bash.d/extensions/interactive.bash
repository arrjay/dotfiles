#!/usr/bin/env bash

# test ls color capabilities and define a function around that. only run when interactive.
____init_ls () {
  local line ls_linect
  ls_linect=0
  # note we call chkdef as ls may be a function at this point.
  ___chkdef ls && {
    mm_setenv ___ls_supports_help || {
      ___ls_supports_help=no
      while read -r line ; do
        # shellcheck disable=SC2219
        let ls_linect=ls_linect+1
      done < <(cd / && ls --help 2>&1)
      # NOTE: heuristic check if we have over 50 lines if output...
      [ "${ls_linect}" -gt 50 ] && ___ls_supports_help=yes
      mm_putenv ___ls_supports_help
    }
  }
  mm_setenv ___ls_supports_color || {
    ___ls_supports_color=no
    [ "${___ls_supports_help}" == 'yes' ] && {
      # if ls supports --help, check for --color flag
      while read -r line ; do
        case "${line}" in
          *--color=auto*)     ___ls_supports_color=auto         ;;
          *--color*)          ___ls_supports_color=yes          ;;
        esac
      done < <(ls --help 2>&1)
    }
    mm_putenv ___ls_supports_color
  }
  # if we already have a function defined, assume it's our gnu wrapper...
  case "${___ls_supports_color}" in
    auto) ___ls_global_opts=("${___ls_global_opts[@]}" '--color=auto') ;;
    yes)  ___ls_global_opts=("${___ls_global_opts[@]}" '--color')      ;;
  esac

  # if we don't have a wrapper, install that now
  # shellcheck disable=SC2006
  case `type -t ls` in
    file) ls () { command ls "${___ls_global_opts[@]}" "${@}" ; } ;;
  esac
}
____init_ls
unset -f ____init_ls

# if we have pinfo, use that instead of man
chkcmd pinfo && man () { command pinfo -m "${@}" ; }
