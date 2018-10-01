#!/usr/bin/env bash

# oh god cygwin. this is actually targeting an environment that is a mishmash of git bash, cygwin and various windows utils.

chkcmd cygpath && {
  _cpath2ms () {
    local output f ; output=()
    for f in "${@}" ; do
      output=("${output[@]}" "$(cygpath -ms "${f}")")
    done
    printf '%q ' "${output[@]}"
  }
}

# define a function to allow my preferred editor for windows (editplus) via the shells
mm_setenv ___EditPlus_cygpath || {
  [ -e "${ProgramFilesX86}/EditPlus/editplus.exe" ] && ___EditPlus_cygpath="${ProgramFilesX86}/EditPlus/editplus.exe"
  [ -e "${ProgramFiles}/EditPlus/editplus.exe" ]    && ___EditPlus_cygpath="${ProgramFiles}/EditPlus/editplus.exe"
  [ "${___EditPlus_cygpath}" ] && {
    editplus () { local toedit ; toedit=("$(_cpath2ms "${@}")") ; "${___EditPlus_cygpath}" "${toedit}" ; }
  }
  mm_putenv ___EditPlus_cygpath
}

mm_setenv ___EditPlus_dospath || {
  ___chkdef _cpath2ms && { ___EditPlus_dospath="$(_cpath2ms "${___EditPlus_cygpath}")" ; mm_putenv ___EditPlus_dospath ; }
}

[ "${___EditPlus_dospath}" ] && { export EDITOR="${___EditPlus_dospath}" ; }