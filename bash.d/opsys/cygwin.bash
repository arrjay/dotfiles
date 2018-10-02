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

  mm_setenv ___CygwinRoot_winpath || {
    ___CygwinRoot_winpath="$(cygpath -w /)"
    mm_putenv ___CygwinRoot_winpath
  }

  # if you are, say, stupid enough to call back in to a windows environment here, have a utility to switch the PATH out
  # and _dispel_ anything cygwin native.
  _cenv2ms () {
    local ent inpath=() outpath=() outpath_str
#   IFS=';' read -r -a inpath < <(cygpath -wp "${PATH}")
    IFS=':' read -r -a inpath <<< "${PATH}"
    for ent in "${inpath[@]}" ; do
      case "${ent}" in
#       "${___CygwinRoot_winpath}"*) : ;;
	/cygdrive/*)                           outpath=("${outpath[@]}" "${ent}") ;;
      esac
    done
    IFS=':' outpath_str="${outpath[*]}"
    env PATH="${outpath_str}" "${@}"
  }
}

# define a function to allow my preferred editor for windows (editplus) via the shells
mm_setenv ___EditPlus_cygpath || {
  [ -e "${ProgramFilesX86}/EditPlus/editplus.exe" ] && ___EditPlus_cygpath="${ProgramFilesX86}/EditPlus/editplus.exe"
  [ -e "${ProgramFiles}/EditPlus/editplus.exe" ]    && ___EditPlus_cygpath="${ProgramFiles}/EditPlus/editplus.exe"
  mm_putenv ___EditPlus_cygpath
}

[ "${___EditPlus_cygpath}" ] && {
  editplus () { local toedit ; [ "${1}" ] && toedit=("$(_cpath2ms "${@}")") ; [ "${toedit}" ] && { "${___EditPlus_cygpath}" "${toedit}" ; return $? ; } ; "${___EditPlus_cygpath}" ; }

  mm_setenv ___EditPlus_dospath || {
    ___chkdef _cpath2ms && { ___EditPlus_dospath="$(_cpath2ms "${___EditPlus_cygpath}")" ; mm_putenv ___EditPlus_dospath ; }
  }
}

[ "${___EditPlus_dospath}" ] && { export EDITOR="${___EditPlus_dospath}" ; }