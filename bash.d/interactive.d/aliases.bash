#!/usr/bin/env bash

# test ls color capabilities and define a function around that. only run when interactive.
____init_ls () {
  local line ls_linect output IFS ls_command
  ls_linect=0
  chkdef ls || return 1
  output="$(cd / && ls --help 2>&1)"
  IFS=$'\n'
  mm_setenv ___ls_supports_help
  [[ "${___ls_supports_help}" ]] || {
    ___ls_supports_help=no
    for line in ${output} ; do
      ((ls_linect++))
    done
    # NOTE: heuristic check if we have over 50 lines if output...
    [[ "${ls_linect}" -gt 50 ]] && ___ls_supports_help=yes
    mm_putenv ___ls_supports_help
  }
  # bail early if --help does not work for ls
  [[ "${___ls_supports_help}" == "no" ]] && return 0

  # check for other command flags
  mm_setenv ___ls_supports_color
  [[ "${___ls_supports_color}" ]] || {
    ___ls_supports_color=no
    for line in ${output} ; do
      case "${line}" in
        *--color=auto*)     ___ls_supports_color=auto         ;;
        *--color*)          ___ls_supports_color=yes          ;;
      esac
    done
  }
  mm_putenv ___ls_supports_color
  case "${___ls_supports_color}" in
    auto) __insert_array_singleton ___ls_global_opts '--color=auto' ;;
    yes)  __insert_array_singleton ___ls_global_opts '--color'      ;;
  esac

  mm_setenv ___ls_supports_human_readable
  [[ "${___ls_supports_human_readable}" ]] || {
    ___ls_supports_human_readable=no
    for line in ${output} ; do
      case "${line}" in
        *--human-readable*) ___ls_supports_human_readable=yes ;;
      esac
    done
  }
  mm_putenv ___ls_supports_human_readable
  case "${___ls_supports_human_readable}" in
    yes) __insert_array_singleton ___ls_global_opts '--human-readable' ;;
  esac

  mm_setenv ___ls_supports_almost_all
  [[ "${___ls_supports_almost_all}" ]] || {
    ___ls_supports_almost_all=no
    for line in ${output} ; do
      case "${line}" in
        *--almost-all*) ___ls_supports_almost_all=yes ;;
      esac
    done
  }
  mm_putenv ___ls_supports_almost_all
  case "${___ls_supports_almost_all}" in
    yes) ll () { ls -Fl --almost-all "${@}" ; } ;;
    *)   ll () { ls -Fla "${@}"             ; } ;;
  esac

  # if we don't have a wrapper, install that now
  # shellcheck disable=SC2006
  case `type -t ls` in
    file|function) ls () { ls "${___ls_global_opts[@]}" "${@}" ; } ;;
  esac

  l () { ls "${@}" ; }
}
____init_ls
unset -f ____init_ls

____init_du () {
  local line du_linect
  du_linect=0
  chkdef du && {
    mm_setenv ___du_supports_help
    [[ "${___du_supports_help}" ]] || {
      ___du_supports_help=no
      while read -r line ; do
        ((du_linect++))
      done < <(cd / && du --help 2>&1)
      [[ "${du_linect}" -gt 25 ]] && ___du_supports_help=yes
      mm_putenv ___du_supports_help
    }
  }
}
____init_du
unset -f ____init_du

# if we have pinfo, use that instead of man
chkcmd pinfo && man () { command pinfo -m "${@}" ; }

# other commands I'd rahter replace
chkcmd gpg2 && gpg () { command gpg2 "${@}" ; }
chkcmd ncftp && ftp () { command ncftp "${@}" ; }
