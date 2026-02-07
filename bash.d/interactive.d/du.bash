#!/usr/bin/env bash

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

