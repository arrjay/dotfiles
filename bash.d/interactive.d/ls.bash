#!/usr/bin/env bash

# test ls color capabilities and define a function around that. only run when interactive.
____init_ls () {
  local line ls_linect output IFS ls_command
  ls_linect=0
  ls_command=gls
  chkdef "${ls_command}" || ls_command="ls"
  chkdef "${ls_command}" || return 1
  IFS=$'\n'

  # check for all the options here, first.
  mm_setenv ___ls_supports_help
  mm_setenv ___ls_supports_color
  mm_setenv ___ls_supports_human_readable
  mm_setenv ___ls_supports_almost_all

  # if we are missing one of the above, run ls and get the output
  { [[ "${___ls_supports_help}" ]] && \
    [[ "${___ls_supports_color}" ]] && \
    [[ "${___ls_supports_human_readable}" ]] && \
    [[ "${___ls_supports_almost_all}" ]]
  } || output="$(cd / && command "${ls_command}" --help 2>&1)"

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
    # these call atop the function (if defined) so it picks up global opts.
    yes) ll () { ls -Fl --almost-all "${@}" ; } ;;
    *)   ll () { ls -Fla "${@}"             ; } ;;
  esac

  # if we don't have a wrapper, install that now
  # shellcheck disable=SC2006
  case "$(type -t "${ls_command}")" in
    file) ls () { command ls "${___ls_global_opts[@]}" "${@}" ; } ;;
  esac

  # this also picks up the function if available
  l () { ls "${@}" ; }
}
____init_ls
unset -f ____init_ls
