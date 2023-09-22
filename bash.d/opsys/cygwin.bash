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
    IFS=':' read -r -a inpath <<< "${PATH}"
    for ent in "${inpath[@]}" ; do
      case "${ent}" in
	/cygdrive/*)                           outpath=("${outpath[@]}" "${ent}") ;;
      esac
    done
    IFS=':' outpath_str="${outpath[*]}"
    env PATH="${outpath_str}" "${@}"
  }
}

# if we have ActiveState perl, _go use that_ (NOTE: really?)
init_aspn_perl () {
  local _aspn_rpath="/proc/registry/HKEY_LOCAL_MACHINE/SOFTWARE/ActiveState/ActivePerl"
  local _aspn_hive ; local _aspn_path
  [ -f "${_aspn_rpath}" ] && {
    read -r _aspn_hive < "${_aspn_rpath}/CurrentVersion"
    read -r _aspn_path < "${_aspn_rpath}/${_aspn_hive}/@"
    ASPN_PATH="$(cygpath "${_aspn_path}/bin")"
    perl () { "${ASPN_PATH}/perl.exe" "${@}" ; }
  }
}
init_aspn_perl
unset -f init_aspn_perl

# define a function to allow my preferred editor for windows (editplus) via the shells
mm_setenv ___EditPlus_cygpath || {
  [ -e "${ProgramFilesX86}/EditPlus/editplus.exe" ] && ___EditPlus_cygpath="${ProgramFilesX86}/EditPlus/editplus.exe"
  [ -e "${ProgramFiles}/EditPlus/editplus.exe" ]    && ___EditPlus_cygpath="${ProgramFiles}/EditPlus/editplus.exe"
  mm_putenv ___EditPlus_cygpath
}

[ "${___EditPlus_cygpath}" ] && {
  editplus () { local toedit ; [ "${1}" ] && toedit=("$(_cpath2ms "${@}")") ; [ "${toedit[0]}" ] && { "${___EditPlus_cygpath}" "${toedit[@]}" ; return $? ; } ; "${___EditPlus_cygpath}" ; }

  mm_setenv ___EditPlus_dospath || {
    ___chkdef _cpath2ms && { ___EditPlus_dospath="$(_cpath2ms "${___EditPlus_cygpath}")" ; mm_putenv ___EditPlus_dospath ; }
  }
}

[ "${___EditPlus_dospath}" ] && { export EDITOR="${___EditPlus_dospath}" ; }

# other useful aliases...
[ -x "${SystemRoot}/system32/ping.exe" ] && ping () { "${SystemRoot}/system32/ping.exe" "${@}" ; }
[ -x "${SystemRoot}/system32/tracert.exe" ] && traceroute () { "${SystemRoot}/system32/tracert.exe" "${@}" ; }

chkcmd cygstart && start () { command cygstart "${@}" ; }
