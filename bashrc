#!/bin/bash

#!# This whole shuffling about with 'read' is an attempt to not fork
#!# unnecessary processes. fork under cygwin is sloooow. so use builtins
#!# where you can, even if it makes it less clear.
#!# This was also the driving force behind the entire caching system, which
#!# cut the startup time for this under cygwin in THIRD.

# the triple underscores are because a lot of vendor shell extensions use double underscore and we don't want to stomp on that.
# on the other hand, stuff you might want to run is not prefixed at all. YOLO.
# the *quadruple* underscores are functions only used while initializing the environment and should be unset later.

# specifically run these before debugging is even enabled to grab shell state - especially ${_}
___bash_invocation_parent=${_}
___bash_invocation=${0}
___bash_source_path=${BASH_SOURCE[0]}
___bash_init_argv0=${BASH_ARGV[0]}
___bash_host_tuple=${BASH_VERSINFO[5]}

## DEBUG SWITCH - UNCOMMENT TO TURN ON DEBUGGING
#set -x

# set permissions for any newly created files to just ourselves.
umask 077

# version information
___rcver="5.1b"
___rcver_str="jBashRc v${JBVER}(c)"

# nastyish hack for mingw32
PATH=/usr/bin:$PATH

# always configure pass keys/opts/signing req ;)
export PASSWORD_STORE_SIGNING_KEY=B1A086C36A2C52A79015F25C95B6669B9D085FA5
export PASSWORD_STORE_GPG_OPTS="--cipher-algo AES256 --digest-algo SHA512"
export PASSWORD_STORE_ENABLE_EXTENSIONS=true

## function definitions
# return errors to fd 2
___error_msg () {
  echo "${*}" 1>&2
}

# get the bash version for command definition unwinding
___bashmaj=${BASH_VERSION/.*/}
___bashmin=${BASH_VERSION#${___bashmin}.}
___bashmin=${___bashmin%%.*}

# I like having USER set. If you don't have USER set, I will set it to this.
____default_username="rjlocal"

# pathsetup - set system path to work around cases of extreme weirdness (yes I have seen them!)
# defined here for convenience but called much later ;)
function ____pathsetup {
  genprepend PATH \
    "/usr/games" \
    "/etc" "/usr/etc" "/usr/sysadm/privbin" \
    "/sbin" "/usr/sysadm/bin" "/usr/sbin" \
    "/usr/ccs/bin" "/usr/sfw/bin" \
    "/usr/pkg/sbin" "/usr/tgcware/sbin" \
    "/usr/local/sbin" \
    "/usr/gfx" "/usr/dt/bin" "/usr/openwin/bin" "/usr/bin/X11" "/usr/X11R6/bin" \
    "/bin" "/usr/bin" \
    "/usr/pkg/bin" "/usr/xpg4/bin" \
    "/usr/bsd" "/usr/ucb" \
    "/usr/kerberos/bin" \
    "/usr/nekoware/bin" "/usr/tgcware/bin" \
    "/opt/local/bin" "/usr/local/bin"
}

# _lc - convert character to lower case
# hi bash 2.05
# shellcheck disable=SC2006
___lc () {
  local char n ; char="${1}"
  case "${char}" in
    [A-Z])
      n="`printf '%d' \'"${char}"`"
      n=$((n+32))
      # the first printf actually takes the second as a format specifier. really.
      # shellcheck disable=SC2059
      printf \\"`printf '%o' "${n}"`"
    ;;
    *) printf '%s' "${char}" ;;
  esac
}

# tolower - convert string to lower case
tolower () {
  local word ch ; word="${1}"
  case "${___bashmaj}" in
    2|3)
      # lowercase it one character at a time.
      for((i=0;i<${#word};++i)) ; do
        ch="${word:$i:1}"
        ___lc "${ch}"
      done
      ;;
    *)
      # this is _much_ easier in set -x output ;)
      printf '%s' "${word,,}" ;;
  esac
}

# determine if a given _command_ exists.
___chkcmd () {
  local cmd
  cmd="${1}"
  #shellcheck disable=SC2006
  case `type -tf "${cmd}" 2>&1` in
    file) return 0 ;;
    *)    return 1 ;;
  esac
}

# we're going to override this in a moment...
# but this will work until the memoizer sets up, or in cases we never load it.
chkcmd () {
  ___chkcmd "${@}"
}

# throw away input, even if we don't have /dev/null working
# yes, the name _is_ dos-inspired
nul () {
  IFS= read -rs ; return 0 ;
}

# determine if a given command, builtin, alias or function exists.
___chkdef () {
  local cmd
  cmd="${1}"
  # piping to | nul throws away the output at the cost of having to use PIPESTATUS
  builtin type "${cmd}" 2>&1 | nul
  return "${PIPESTATUS[0]}"
}

# placeholders, simply return 1 as the cache doesn't work yet
mm_putenv () {
  return 1
}

mm_setenv () {
  return 1
}

zapcmdcache () {
  hash -r
}

# verify cache system is set within any function at runtime.
___vfy_cachesys () {
  local caller msg ; caller="${1}"
  msg="BASH_CACHE_DIRECTORY is not set"
  [ "${caller}" ] && msg="${caller}: ${msg}"
  [ "${BASH_CACHE_DIRECTORY}" ] || { ___error_msg "${msg}" ; return 3 ; }
}

# configure command caching/tokenization dir
___cache_checked=0	# track if we've already run...
___cache_active=0
____init_cachedir () {
  # have I been here before?
  case "${___cache_checked}${___cache_active}" in
    10) return 1 ;; # not going to work
    11) return 0 ;; # already done
  esac

  # build a potential cache directory
  [ -z "${BASH_CACHE_DIRECTORY}" ] && {
    # do I have a homedir that is a valid directory?
    [ -d "${HOME}" ] || { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; }
    # is the home directory / ? (okay, actually, is it one character long?)
    [ "${#HOME}" == '1' ] && { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; }

    BASH_CACHE_DIRECTORY="${HOME}/.cmdcache"
    [ -z "${HOSTNAME}" ] || BASH_CACHE_DIRECTORY="${BASH_CACHE_DIRECTORY}/${HOSTNAME}-"
    [ -z "${___bash_host_tuple}" ] || BASH_CACHE_DIRECTORY="${BASH_CACHE_DIRECTORY}${___bash_host_tuple}"
  }

  # actually try creating that directory
  ___chkdef md || { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; }
  md "${BASH_CACHE_DIRECTORY}"/{env,chkcmd} || { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; }

  # check if we can write _in_ the directory
  : > "${BASH_CACHE_DIRECTORY}/.lck" || { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; }

  # unfortunately, rm is _not_ a builtin, so carefully walk around it.
  ___chkdef rm && { rm "${BASH_CACHE_DIRECTORY}/.lck" || { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; } ; }

  ___cache_checked=1 ; ___cache_active=1
}

# there are two versions of the following functions - a series using printf -v
# and a series with eval. I'd really rather use the printf ones if we can.
# shellcheck disable=SC2006
___printf_supports_v=`exec 2>&1 ; printf -v test -- '%s' yes ; printf '%s' "${test}"`

# this reverts commit 0e0cbc321ea
# genstrip - remove element from path-type variable
# you need to specify the variable and the element!
genstrip () {
  [ "${2}" ] || { ___error_msg "${FUNCNAME[0]}: missing operand (needs: ENV, directory)" ; return 1 ; }
  eval "${1}"=\""${!1//':'"${2}":/:}"\"
  eval "${1}"=\""${!1%:"${2}"}"\"
  eval "${1}"=\""${!1#"${2}":}"\"
}

[ "${___printf_supports_v}" == "yes" ] && {
  genstrip () {
    [ "${2}" ] || { ___error_msg "${FUNCNAME[0]}: missing operand (needs: ENV, directory)" ; return 1 ; }
    local n s t
    t="${!1}"
    n="${2%/}"         ; s="${n}/"
    t="${t//:${n}:/:}" ; t="${t//:${s}:/:}"
    t="${t%:${n}}"     ; t="${t%:${s}}"
    t="${t#${n}:}"     ; t="${t%${s}:}"
    builtin printf -v "${1}" '%s' "${t}"
  }
}

# this reverts commit e80ab23b5e
# check environment variables exist, make if needed
cke () {
  [ "${1}" ] || { ___error_msg "${FUNCNAME[0]}: missing operand (needs: ENV)" ; return 1 ; }
  local x
  for x in "${@}" ; do
    if [[ -z "${x}" ]]; then
      eval "${x}"=\'\'
    fi
    # always export the thing
    eval export "${x}"
  done
}

[ "${___printf_supports_v}" == "yes" ] && {
  cke () {
    [ "${1}" ] || { ___error_msg "${FUNCNAME[0]}: missing operand (needs: ENV)" ; return 1 ; }
    local x
    for x in "${@}" ; do
      if [[ -z "${x}" ]]; then
        builtin printf -v "${x}" ''
      fi
      # always export the thing
      # shellcheck disable=SC2163
      export "${x}"
    done
  }
}

# genappend - add directory element to path-like element
# you need variable, then element
genappend () {
  [ "${2}" ] || { ___error_msg "${FUNCNAME[0]}: missing operands (needs: ENV, directory(s))" ; return 1 ; }
  local e d
  e="${1}" ; shift
  cke "${e}"
  for d in "${@}" ; do
    genstrip "${e}" "${d}"
    [ -d "${d}" ] && eval "${e}"=\""${!e}":"${d}"\"
  done
}

[ "${___printf_supports_v}" == "yes" ] && {
  genappend () {
    [ "${2}" ] || { ___error_msg "${FUNCNAME[0]}: missing operands (needs: ENV, directory(s))" ; return 1 ; }
    local e t d
    e="${1}" ; shift
    for d in "${@}" ; do
      genstrip "${e}" "${d}"
      t="${!e}"
      [ -d "${d}" ] && builtin printf -v "${e}" '%s' "${t}:${d}"
    done
    cke "${e}"
  }
}

# genprepend - add directory elements to FRONT of path-like list (NOTE: takes arguments as loop - later args are in the front!)
genprepend () {
  [ "${2}" ] || { ___error_msg "${FUNCNAME[0]}: missing operands (needs: ENV, directory(s))" ; return 1 ; }
  local e d
  e="${1}" ; shift
  cke "${e}"
  for d in "${@}" ; do
    genstrip "${e}" "${d}"
    [ -d "${d}" ] && eval "${e}"=\""${d}":"${!e}"\"
  done
}

[ "${___printf_supports_v}" == "yes" ] && {
  genprepend () {
    [ "${2}" ] || { ___error_msg "${FUNCNAME[0]}: missing operands (needs: ENV, directory(s))" ; return 1 ; }
    local e t d
    e="${1}" ; shift
    for d in "${@}" ; do
      genstrip "${e}" "${d}"
      t="${!e}"
      [ -d "${d}" ] && builtin printf -v "${e}" '%s' "${d}:${t}"
    done
    cke "${e}"
  }
}

# we keep pathappend and pathprepend, even though not used, for interactive purposes :)
pathappend () {
  genappend PATH "${@}"
}

pathprepend () {
  genprepend PATH "${@}"
}

## runtime - potential definitions
# _md - test and create directory if needed - requires mkdir...
# this is actually only the third thing run (the first was the path hack, then printf -v processing)
___chkdef mkdir && md () {
  local dir ret rs ; ret=0
  [ "${1}" ] || { ___error_msg "${FUNCNAME[0]}: missing operand" ; return 1 ; }

  for dir in "${@}" ; do
    [ -d "${dir}" ] && continue
    mkdir -p "${dir}" ; rs=$?
    # shellcheck disable=SC2219
    let ret=ret+rs
  done
  return "${ret}"
}

# after defining md (or not), roll along with the rest of the cache system. this redefines stubs we had up above with versions that cache.
# chkcmd - check if specific _command_ is present, now with memoization
____init_cachedir && {
  chkcmd () {
    local cmd found ; cmd="${1}"
    [ -z "${cmd}" ] && { ___error_msg "${FUNCNAME[0]}: check if command exists, indicate via error code" ; return 2 ; }

    ___vfy_cachesys chkcmd || return $?

    if [ -f "${BASH_CACHE_DIRECTORY}/chkcmd/${cmd}" ]; then
      # we already have this check cached
      read -r found < "${BASH_CACHE_DIRECTORY}/chkcmd/${cmd}"
      return "${found}"
    else
      # actually run ___chkcmd and cache the result of that
      ___chkcmd "${cmd}" ; found="${?}"
      printf '%s\n' "${found}" > "${BASH_CACHE_DIRECTORY}/chkcmd/${cmd}"
      return "${found}"
    fi
  }

  # mm_putenv - save environment memo
  mm_putenv () {
    local env val ; env="${1}" ; val="${!1}"
    [ -z "${env}" ] && { __error_msg "${FUNCNAME[0]}: save environment variable to memoization system" ; return 2 ; }

    ___vfy_cachesys mm_putenv || return $?
    [ -z "${val}" ] || printf '%s' "${val}" > "${BASH_CACHE_DIRECTORY}/env/${env}"
  }

  # mm_setenv - read environment memo if available (NOTE: this will _replace_ the envvar)
  mm_setenv () {
    local env ; env="${1}"
    [ -z "${env}" ] && { __error_msg "${FUNCNAME[0]}: restore environment variable from memoization system" ; return 2 ; }

    ___vfy_cachesys mm_setenv || return $?
    [ -f "${BASH_CACHE_DIRECTORY}/env/${env}" ] && { read -r "${env}" < "${BASH_CACHE_DIRECTORY}/env/${env}" ; return 0 ; }
    # export that as well
    # shellcheck disable=SC2163
    export "${env}"
    return 1
  }

  zapcmdcache () {
    ___vfy_cachesys zapcmdcache || return $?
    rm -rf "${BASH_CACHE_DIRECTORY}"/{chkcmd,env}/*
    hash -r
  }
}
unset -f ____init_cachedir

### actually set up the PATH block here before we go looking for any more external binaries.
____pathsetup
unset -f ____pathsetup

# try turning the bashrc ref (if any) into an absolute path
____find_bashrc_file () {
  local rcpath linkdest abspath
  # first, handle ./path/to/thing
  if [ "${___bash_source_path}" ]; then
    rcpath="${___bash_source_path%/*}"
    [ "${rcpath}" == "." ] && rcpath="${PWD}/${___bash_source_path}"
  fi

  # is this a link? where is the real file?
  if [ -h "${___bash_source_path}" ]; then
    chkcmd readlink && linkdest="$(readlink "${___bash_source_path}")"
    # we didn't have readlink. huh.
    [ "${linkdest}" ] || linkdest="$(ls -l "${___bash_source_path}"|awk -F' -> ' '{print $2}')"
    case "${linkdest}" in
      /*) abspath="${linkdest}" ;;
      *)  abspath="${rcpath}/${linkdest}" ;;
    esac
  else
    abspath="${___bash_source_path}"
  fi
  printf '%s' "${abspath}"
}

# shellcheck disable=SC2006
___bashrc_dir="`____find_bashrc_file`"
unset -f ____find_bashrc_file
___bashrc_dir="${___bashrc_dir%/*}"

# configure user/host pieces			# Fedora 28
# shellcheck disable=SC2006
mm_setenv ___host || {
  ___host=`tolower "${HOSTNAME:-}"`
}

# try `uname -p` first
# shellcheck disable=SC2006
mm_setenv ___cpu || {
  chkcmd uname && {
    # okay. check if uname supports -p next.
    uname -p 2>&1 | nul
    [ "${PIPESTATUS[0]}" == 0 ] && {
      ___cpu="`uname -p`"			# x86_64
      ___cpu="`tolower "${___cpu}"`"		# x86_64
    }
  }
  # next, try from bash HOSTTYPE
  [ -z "${___cpu}" ] && {
    ___cpu="`tolower "${HOSTTYPE}"`"		# x86_64
    ___cpu="${___cpu%%-linux}"			# x86_64
  }

  # i?86 == x86
  if [ "${___cpu:2}" == 86 ] || [ "${___cpu:2}" == "86-pc" ]; then
    [ "${___cpu:0:1}" == "i" ] && ___cpu="x86"
  fi

  mm_putenv ___cpu
}

# derive operating system name from bash MACHTYPE
						# x86_64-redhat-linux-gnu
mm_setenv ___os || {
  ___os="${MACHTYPE##"${___cpu}-"}"		# redhat-linux-gnu
  ___os="${___os%%-gnu}"			# redhat-linux
  ___os="${___os##*-}"				# linux
  ___os="${___os%%[0-9]*}"			# linux
  # shellcheck disable=SC2006
  ___os=`tolower "${___os}"`			# linux
  mm_putenv ___os
}

# if we _have_ a uname command, use that to fill in the release pieces.
# uname -r is POSIX spec'd so just run with it.
# also, this is _not_ cached, linux likes updates ;)
chkcmd uname && {
  # shellcheck disable=SC2006
  ___osrel="`uname -r`"
  [ "${___osrel}" ] || unset osrel
}

[ ! -z "${___osrel:-}" ] && {			# 4.18.5-200.fc28.x86_64
  ___osmaj="${___osrel%%\.*}"			# 4
  ___osmin="${___osrel##"${___osmaj}."}"	# 18.5-200.fc28.x86_64
  ___osmin="${___osmin%%-*}"			# 18.5
  ___osmin="${___osmin%%\.*}"			# 18
  ___osflat="${___osmaj}${___osmin}"		# 418
}

# common envvars for windows platforms setup
#shellcheck disable=SC2006,SC2153
____wininit () {
  mm_setenv SystemDrive     || {
    [ "${SYSTEMDRIVE}" ] && {
      { chkcmd cygpath && SystemDrive=`cygpath "${SYSTEMDRIVE}"` ; } || SystemDrive="${SYSTEMDRIVE}"
      mm_putenv SystemDrive
    }
  }
  mm_setenv SystemRoot      || {
    [ "${SYSTEMROOT}" ] && {
      { chkcmd cygpath && SystemRoot=`cygpath "${SYSTEMROOT}"` ; } || SystemRoot="${SYSTEMROOT}"
      mm_putenv SystemRoot
    }
  }
  mm_setenv ProgramFiles    || {
    [ "${PROGRAMFILES}" ] && {
      { chkcmd cygpath && ProgramFiles=`cygpath "${PROGRAMFILES}"` ; } || ProgramFiles="${PROGRAMFILES}"
      mm_putenv ProgramFiles
    }
  }
  mm_setenv ProgramFilesX86 || {
      { chkcmd cygpath && ProgramFilesX86=`cygpath -F 0x2a` ; } || ProgramFilesX86="${ProgramFiles} (x86)"
      mm_putenv ProgramFilesX86
  }

  # note the genappend call as a _fallback_
  genappend PATH "${SystemDrive}/bin"

  # add the native win32 GPG binaries to the front of the path if found.
  genprepend PATH "${ProgramFilesX86}/Gpg4win/bin" "${ProgramFiles}/Gpg4win/bin" "${ProgramFilesX86}/GnuPG/bin" "${ProgramFiles}/GnuPG/bin"

  # define a function to allow my preferred editor for windows (editplus) via the shells
  [ -e "${ProgramFilesX86}/EditPlus/editplus.exe" ] && editplus () { "${ProgramFilesX86}/EditPlus/editplus.exe" "${@}"; }
  [ -e "${ProgramFiles}/EditPlus/editplus.exe" ]    && editplus () { "${ProgramFiles}/EditPlus/editplus.exe" "${@}"; }
}

# hacks to re-set platform vars based on experience. note we used ___osmaj, so that's why it's here.
case "${___os}" in
  cygwin*)        ___os=cygwin ; ____wininit ;;
  windows32|msys)
    ___os=win32
    # specifically for win32, throw away the osrel pieces
    unset ___osrel ___osmaj ___osmin ___osflat
    # also set USER and HOME if they're not currently
    { [ -z "${USER}" ] && [ "${USERNAME}" ] ; }    && USER="${USERNAME}"
    { [ -z "${HOME}" ] && [ "${USERPROFILE}" ] ; } && HOME="${USERPROFILE}"
    export USER HOME
    ____wininit
  ;;
  sunos*)         [ "${___osmaj}" == 5 ] && ___os=solaris ;;
  gnueabihf)      chkcmd uname && ___os=$(uname -s) ;; # uname -s is posix.
  android*)       [ -z "${USER}" ] && USER="${____default_username}" ; export USER ;;
esac

unset -f ____wininit

# re-save ___os
mm_putenv ___os

# set up more of the loader environment now
genprepend PATH "${HOME}/Library/Python/"*/bin "${HOME}/Library/"*/bin "${HOME}/Applications/"*/bin \
                "${HOME}/.cargo/bin" "${HOME}/.rvm/bin" \
                "${HOME}/bin/${___os}-${___cpu}" "${HOME}/bin/${___os}${___osmaj}-${___cpu}" "${HOME}/bin/${___os}${___osflat}-${___cpu}" \
                "${HOME}/bin/noarch" "${HOME}/bin/${___host}"

# determine if we are a superuser or not
___rootusr=unk
# shellcheck disable=SC2006
case ${___os} in
  win32|cygwin) { chkcmd grep && chkcmd id ; } && { id -G | grep -q 544 && ___rootusr='yes' || ___rootusr='no' ; } ;;
  solaris)      [ -x /usr/xpg4/bin/id ] && { [ "`/usr/xpg4/bin/id -u`" == "0" ] && ___rootusr='yes' || ___rootusr='no' ; } ;;
  *)            chkcmd id && { [ "$(id -u)" == "0" ] && ___rootusr='yes' || ___rootusr='no' ; } ;;
esac

# configure LD_LIBRARY_PATH unless asked not to
[ "${NO_LDPATH_EXTENSION}" ] || mm_setenv NO_LDPATH_EXTENSION
[ -z "${NO_LDPATH_EXTENSION}" ] && {
  # add our personal ~/Library subdirectories
  for dir in "${HOME}"/Library/*/lib ; do
    genappend LD_LIBRARY_PATH "${dir}"
  done
  cke LD_LIBRARY_PATH
}

# envvars for auxiliary programs should go about here.
## perl
if [ -d "${HOME}"/Library/perl5 ]; then
  export PERL_MB_OPT="--install_base ${HOME}/Library/perl5"
  export PERL_MM_OPT="INSTALL_BASE=${HOME}/Library/perl5"
  export PERL_LOCAL_LIB_ROOT="${HOME}/Library/perl5"
  genappend PERL5LIB "${HOME}/Library/perl5"
  if [ -d "${HOME}/Library/perl5/lib/perl5" ]; then
    genappend PERL5LIB "${HOME}/Library/perl5/lib/perl5"
    if [ -d "${HOME}/Library/perl5/lib/perl5/${___cpu}-${___os}-gnu-thread-multi" ]; then
      genappend PERL5LIB "${HOME}/Library/perl5/lib/perl5/${___cpu}-${___os}-gnu-thread-multi"
    fi
  fi
fi

## go
# configure GOPATH/GOROOT here
if [ -f "${HOME}/Library/go-dist/bin/go" ] ; then
  # go distribution in go-dist, gopath in go, gox is happy, go away.
  export GOROOT="${HOME}/Library/go-dist"
fi
if [ -d "${HOME}/Library/go" ]; then
  if [ -f "${HOME}/Library/go/bin/go" ] ; then
    # found a go _compiler_ so this is a complete install.
    if [ ! -z "${GOROOT}" ] ; then
      if [[ -n ${PS1} ]]; then
        # warn of stupid times ahead.
        echo "WARNING: resetting GOROOT to ${HOME}/Library/go when GOROOT was already set."
      fi
    fi
    export GOROOT="${HOME}/Library/go"
  else
    if [ ! -z "${GOPATH}" ] ; then
      genprepend GOPATH "${HOME}/Library/go"
    else
      export GOPATH="${HOME}/Library/go"
    fi
  fi
fi

# setup MANPATH
genappend MANPATH "/usr/X11R6/man" "/usr/openwin/man" "/usr/dt/man" \
    "/usr/share/man" "/usr/man" \
    "/usr/pkg/man" "/usr/local/share/man" "/usr/local/man" \
    /opt/*/man

[ "${SystemRoot}" ] && genappend MANPATH "${SystemRoot}/man"

# if we have the git prompt support script in vendor/, load it now
[ -f "${___bashrc_dir}/vendor/git-prompt.sh" ] && source "${___bashrc_dir}/vendor/git-prompt.sh"

# cool. we've got some initial PATHs set up to play binary games, let's hand the rest off to extension scripts.
# set up auxfiles paths. order is BASH_AUX_FILES, HOME, script source dir.
___bash_auxfiles_dirs=()
[ -d "${BASH_AUX_FILES}" ] && ___bash_auxfiles_dirs=("${___bash_auxfiles_dirs[@]}" "${BASH_AUX_FILES}")
[ -d "${___bashrc_dir}/bash.d" ] && ___bash_auxfiles_dirs=("${___bash_auxfiles_dirs[@]}" "${___bashrc_dir}/bash.d")
[ -d "${HOME}/.bash.d" ] && ___bash_auxfiles_dirs=("${___bash_auxfiles_dirs[@]}" "${HOME}/.bash.d")

# source file if executeable and ending in .bash
sourcex () {
  [ "${1}" ] || { ___error_msg "${FUNCNAME[0]}: missing operand (needs: file, perferably +x ending in .bash)" ; return 1 ; }
  local f
  for f in "${@}" ; do
    case "${f}" in *.bash) : ;; *) continue ;; esac
    # shellcheck disable=SC1090
    [ -x "${f}" ] && source "${f}"
  done
}

# walk the bash auxfiles and go to town
____hostsetup () {
  local d
  for d in "${___bash_auxfiles_dirs[@]}" ; do
    sourcex "${d}/opsys/${___os}.bash" \
            "${d}/opsys/${___os}_bash${___bashmaj}.bash" \
            "${d}/opsys/${___os}-${___cpu}.bash" \
            "${d}/opsys/${___os}${___osmaj}.bash" \
            "${d}/opsys/${___os}${___osmaj}-${___cpu}.bash" \
            "${d}/opsys/${___os}${___osflat}.bash" \
            "${d}/opsys/${___os}${___osflat}-${___cpu}.bash" \
            "${d}/extensions.bash" \
            "${d}/extensions/common.bash" \
            "${d}/extensions/bash${___bashmaj}.bash" \
            "${d}/prompt/common.bash" \
            "${d}/prompt/bash${___bashmaj}.bash" \
            "${d}/prompt/${___os}.bash" \
            "${d}/host/${___host}.bash"
  done
}
____hostsetup
unset -f ____hostsetup

## internal functions
#-# HELPER FUNCTIONS
#--# Text processing
# v_alias - overloads command with specified function if command exists
function v_alias {
  if [ ! -n "${1}" ]; then
    builtin alias
    return $?
  fi
  chkcmd "${2}" && builtin alias "${1}=${2}"
}

# gethostinfo - initialize host variables for function use
function gethostinfo {
  local x p

  # are we a laptop (rather, do we have ACPI or APM batteries?)
  case ${OPSYS} in
    android)
      # if we have termux-battery-status *and* jq, use those.
      chkcmd termux-battery-status && chkcmd jq && PMON_TYPE="termux" && PMON_BATTERIES="termux-api"
    ;;
    *) : ;; # I have no idea.
  esac
}


function zapenv {
  unset -f gethostinfo
  unset -f kickenv
  unset -f zapenv
}

# kickenv - run all variable initialization, set PATH.
function kickenv {
  gethostinfo
  # shellcheck disable=SC1090
  # shellcheck disable=SC1090
  [[ -s "${HOME}/.rvm/scripts/rvm" ]] && source "${HOME}/.rvm/scripts/rvm"
  zapenv
}

#-# TERMINAL FUNCTIONS

function _properties {
  echo -n "${JBVERSTRING}"
  echo "SysID: ${HOST} ${OPSYS}${LVER} ${CPU} (${TERM})"
  echo "using bash ${BASH_VERSION}"
  if [ "${CONNFROM}" ]; then
    echo "Connecting From: ${CONNFROM}"
  fi
  if [ -n "${1}" ] && [ "${1}" == "-x" ]; then
    echo "--"
    if [ "${OPSYS}" == "darwin" ]; then
      OSXVER=$(echo -e 'Tell application "Finder"\nget version\nend tell'|osascript -) && echo "Apple Mac OS X ${OSXVER}"
      NCPU=$(sysctl -n hw.ncpu)
      # shellcheck disable=SC2003
      CPUSPEED=$(expr "$(sysctl -n hw.cpufrequency)" / 1000000)
      CPUTYPE=$(machine)
      echo "${CPUTYPE}" | grep -q ppc && CPUARCH="PowerPC"
      CPUTYPE=${CPUTYPE//ppc/}
      case "${CPUTYPE}" in 7450) CPUSUB="G4" ;; esac
      echo -n "${NCPU} ${CPUSPEED}MHz ${CPUARCH} ${CPUTYPE} "
      [ "${CPUTYPE}" ] && echo -n "(${CPUSUB}) "
      echo "Processor(s)"
    fi

    if   [ -f /etc/fedora-release ]; then cat /etc/fedora-release
    elif [ -f /etc/redhat-release ]; then cat /etc/redhat-release
    fi

    [ "${OPSYS}" == "freebsd" ] && {
      echo -n "FreeBSD "
      uname -r
      NCPU=$(sysctl -n hw.ncpu)
      CPUSPEED=$(sysctl -n hw.clockrate)
      CPUTYPE=$(sysctl -n hw.model)
      echo "${NCPU} ${CPUSPEED}MHz ${CPUTYPE} Processor(s)"
    }

    if [ "${OPSYS}" == "win32" ] || [ "${OPSYS}" == "cygwin" ]; then
      [ ! -f "${HOME}"/.sysinfo.vbs ] && {
        cat << _EOF_ | sed -e 's/$/'"$(printf "\\r")"'/' > "${HOME}/.sysinfo.vbs"
set w = getobject("winmgmts:\\\\.\\root\\cimv2")
set o = w.instancesof("win32_operatingsystem")
for each i in o
wscript.echo i.caption & " SP" & i.servicepackmajorversion
next
_EOF_
      }
      SYSIVBS=$(mm_getenv SYSIVBS) || {
        [ "${OPSYS}" == 'cygwin' ] && SYSIVBS=$(cygpath -da "${HOME}"/.sysinfo.vbs) || SYSIVBS=$(ls -d "${HOME}"/.sysinfo.vbs)
        mm_putenv SYSIVBS
      }
      cscript //nologo "${SYSIVBS}"
      [ ! -f "${HOME}"/.ucount.vbs ] && {
        cat << _EOF_ | sed -e 's/$/'"$(printf "\\r")"'/' > "${HOME}/.ucount.vbs"
set w = getobject("winmgmts:\\\\.\\root\\cimv2")
set c = w.execquery("select * from win32_logonsession where logontype = 2")
wscript.echo c.count
_EOF_
      }
      UCOUNT=$(cscript //nologo "${HOME}"/.ucount.vbs)
    else
      UCOUNT=$(who|wc -l|sed 's/^ *//g')
    fi
    PC=$(pscount + 1)
    echo "${PC} Processes, ${UCOUNT} users"
    unset PC
    unset UCOUNT
    [ "${DISPLAY}" ] && {
      echo "X Display: ${DISPLAY}"
      xdpyinfo | grep -E 'dimensions|depth of root window'
    }
    [ "${PMON_BATTERIES}" ] && {
      echo -n "Batteries installed, using "
      case "${PMON_TYPE}" in
        lxsysfs) echo -n "Linux /sys FS" ;;
        termux)  echo -n "Termux API" ;;
      esac
      echo " for monitoring"
      echo " Monitoring ${PMON_BATTERIES}"
      echo -n " Batteries are "
      x=$(battstat chrg);   echo -n "${x}/"
      x=$(battstat cap);    echo -n "${x} ("
      x=$(battstat chgpct); echo    "${x}%) charged"
    }
  fi
}

# (m)su - su with term color change for extra attention
function msu {
  setcscheme "${CSCHEME_SU}"
  "${REAL_SU}" "${@}"
  echo ' '
  setcscheme "${CSCHEME_DEFAULT}"
}

## environment manipulation
# dealias - undefine alias if it exists
function dealias {
  unalias "${1}" >& /dev/null
}

# setenv - sets an *exported* environment variable
function setenv {
  oifs=$IFS
  IFS=' '
  name="${1}"
  shift
  export "$name=$*"
  IFS=$oifs
  unset oifs
}

# unsetenv - unsets exported environment variables
function unsetenv {
  if export|grep 'declare -x'|grep -q "${1}"
    then unset "${1}"
  fi
}

# battstatt - pull battery status generic-ish
function battstat {
  case "${1}" in
    cap)
      # get total capacity
#        termux)
          # termux only returns percentage
          PMON_CAP=100
      echo "${PMON_CAP}"
    ;;
    chrg)
#        termux) PMON_CHARGE=$(jq .percentage < "$HOME/.termux-battery-status") ;;
      echo "${PMON_CHARGE}"
    ;;
    chgpct)
        echo $(($(battstat chrg)00 / $(battstat cap)))
    ;;
    stat)
      # discahrge (v), idle (-), or charging (^)?
      # batteries at idle is the default state
#        termux)
          __plugged=$(jq -r .plugged < "$HOME/.termux-battery-status")
          __status=$(jq -r .status < "$HOME/.termux-battery-status")
          [ "${__status}" == "NOT_CHARGING" ] && [ "${__plugged}" == "UNPLUGGED" ] && PMON_STAT="v"
          [ "${__status}" == "CHARGING" ] && PMON_STAT="^"
    ;;
    *)
      echo "I don't know how to $1"
      echo "$0 (cap|chrg|chgpct|stat)"
      return 2;
    ;;
  esac
}

# this is a function because pulling up a graphical editor when running 'vi' is *very* surprising
function _ed {
  "${EDITOR}" "${@}"
}

## Monolithic version - now we config some things!
function monolith_setfunc {
  case "${OPSYS}" in
    openbsd|darwin)
      # redefine linux-specific functions
      function pscount {
        echo -n "$(("$(ps ax|wc -l)" - 5))"
      }
    ;;
    cygwin|win32)
      # create a .pscount.vbs script if needed
      [ ! -f "${HOME}/.pscount.vbs" ] && {
        cat << _EOF_ | sed -e 's/$/'"$(printf "\\r")"'/' > "${HOME}/.pscount.vbs"
c = 0
set w = GetObject("winmgmts:{impersonationlevel=impersonate}!\\\\.\\root\\cimv2")
set l = w.ExecQuery ("Select * from Win32_Process")
for each objProcess in l
c = c + 1
next
c = c - 3
wscript.stdout.write c
_EOF_
      }
      # MSYS doesn't seem to have cygpath
      PSCVBS=$(mm_getenv PSCVBS) || {
        if [ "${OPSYS}" == "cygwin" ]; then
          PSCVBS=$(cygpath -da "${HOME}/.pscount.vbs")
        else
          PSCVBS=$(ls -d "${HOME}/.pscount.vbs")
        fi
        mm_putenv PSCVBS
      }

      function pscount {
        out=$(cscript //nologo "${PSCVBS}") && echo "${out}"
      }

      # fake getent - call mkpasswd/mkgroup as appropriate
      function getent {
        case "${1}" in
          passwd) mkpasswd.exe -du "${2}" ;;
          group)  mkgroup.exe  -du "${2}" ;;
          *)      echo 'Wha?'             ;;
        esac
      }
    ;;
    solaris)
      function pscount {
        echo -n $(("$(ps ax|wc -l)" - 5))
      }
    ;;
    freebsd)
      function pscount {
        # try to exclude kernel threads
        # shellcheck disable=SC2009
        echo -n $(("$(ps ax|grep -cv '[0-9] \[')" - 7))
      }
    ;;
    irix)
      function pscount {
        echo -n $(("$(ps -ef|wc -l)" - 6))
      }
    ;;
    *) : ;; # do nothing...
  esac
  unset -f monolith_setfunc
}

function monolith_aliases {
  # we actually set PAGER/EDITOR here as well
  chkcmd less && export PAGER=less

  # try to call coreutils & friends
  v_alias ls gls
  v_alias cp gcp
  v_alias mv gmv
  v_alias rm grm
  v_alias df gdf
  v_alias du gdu
  v_alias id gid
  v_alias tail gtail
  v_alias md5sum gmd5sum
  v_alias vi vim
  v_alias wc gwc
  v_alias expr gexpr
  v_alias chgrp gchgrp
  v_alias chown gchown
  v_alias chmod gchmod
  v_alias find gfind
  v_alias lynx links
  v_alias more less
  v_alias watch cmdwatch
  v_alias man pinfo
  v_alias mpg123 mpg321	# we prefer mpg321 if we have it...
  v_alias mpg321 mpg123	# else mpg123
  v_alias ftp ncftp
  v_alias gpg gpg2
	
  # common custom aliases
  alias path='echo ${PATH}'
  alias scx='screen -x'
  alias l='ls'
  alias s='sync;sync;sync'

  # pretend to be DOS, sometimes
  alias cls='clear'
  alias rd='rm -rf'
  alias copy='cp'
  alias move='mv'
  alias tracert='traceroute'

  # common typo
  alias Grep='grep'

  # if I _have_ docker, set it up here
  chkcmd docker && {
    __docker_sh () {
      # run bash in a docker container, overriding entrypoint. optionally, mount some volumes, too.
      local opt volume image OPTARG OPTIND xauthority dt env xsockdir
      volume=() ; env=() ; xauthority="" ; image="" ; xsockdir=""
      while getopts "v:xi:" opt "${@}" ; do case "${opt}" in
          i) image="${OPTARG}" ;;
          v) volume+=('-v' "${OPTARG}") ;;
          x)
             xauthority=$(__docker_xauth) || { echo "unable to manipulate X security settings" 1>&2 ; return 1 ; }
             chkcmd socat || { echo "socat needed for X11 socket handling" 1>& 2 ; return 1 ; }
             xsockdir=$(mktemp -d) || { echo "unable to create container transient X socket dir" 1>&2 ; return 1 ; }
             chcon -t sandbox_file_t "${xsockdir}"
             dt=${DISPLAY/:/} ; dt=${dt%.*}
             case "${DISPLAY}" in
               # local X
               :*) [ -e "/tmp/.X11-unix/X${dt}" ] && {
                 # this works via the socat-x.te file also in the dotfiles repo :/ install if needed doing this:
                 # checkmodule -M -m -o socat-x.mod socat-x.te && semodule_package -o socat-x.pp -m socat-x.mod
                 # sudo semodule -i socat-x.pp
                 ( env LD_LIBRARY_PATH='' runcon -t sandbox_x_t socat "UNIX-LISTEN:${xsockdir}/X0,fork" "UNIX:/tmp/.X11-unix/X${dt}" & )
                 volume+=('-v' "${xsockdir}/X0:/tmp/.X11-unix/X0:Z") ; } ;;
             esac
             volume+=('-v' "${xauthority}:/.Xauthority:Z")
             env+=('--env' 'XAUTHORITY=/.Xauthority')
             env+=('--env' 'DISPLAY=:0')
          ;;
          *) { echo "${BASH_FUNCTION[0]} [-v][-x]" ; } 1>&2 ; return 2 ;;
      esac ; done
      shift $((OPTIND-1))
      command docker run --rm=true -it "${env[@]}" "${volume[@]}" --entrypoint bash "${image}" -i
      [ -e "${xauthority}" ] && rm "${xauthority}"
      [ -e "${xsockdir}" ] && { fuser -k "${xsockdir}/X0" 2>/dev/null 1>&2 ; rm -rf "${xsockdir}" ; }
    }

    __docker_xauth () {
      # clone our X11 magic cookie and return a file that has a wildcard copy.
      local xauthority
      xauthority=$(mktemp) && {
        echo "ffff 0000 0001 30 $(xauth nlist "${DISPLAY}" | cut -d\  -f6-)" | xauth -f "${xauthority}" nmerge -
        echo "${xauthority}"
      } || return 1
    }

    docker () {
      local wd ; wd=$(pwd)
        case "${1}" in
          i|iamges)
            command docker images "${@:2}" ;;
          sh)
            __docker_sh -i "${2}" ;;
          xsh)
            __docker_sh -i "${2}" -x ;;
          sandbox|sbox|scratch)
            case "${wd}" in
              /|/usr|/usr/*|/bin|/sbin|/root|/var/*|/var|/dev|/dev/*|/sys|/sys/*|/etc|/etc/*|/home|"${HOME}"|/boot|/boot/*|/lib*|/proc|/proc/*|/run|/run/*|/tmp*)
                 echo "refusing to bind mount ${wd} try some where else" 1>&2 ; return 1 ;;
              *) echo "NOTE: running with selinux flags this will change a fslabel!" ;;
            esac
            __docker_sh -i "${2}" -v "$(pwd):/mnt:ro,Z" ;;
          cmd)
            command docker run --rm=true -it "${2}" "${@:3}" ;;
          find)
            command docker images -a | awk 'BEGIN { OFS=":" } ; NR != 1 && $1 ~ "'"${2}"'" { print $1, $2 ; }' ;;
          rmie)
            command docker rmi "$(docker find "${2}")" ;;
          *)
            command docker "${@}" ;;
        esac
    }
  }

  case ${OPSYS} in
    cygwin*|win32)
      alias ll='ls -FlAh --color=tty'
      alias ls='ls --color=tty -h'
      alias start='cygstart'
      alias du='du -h'
      alias df='df -h'
      alias cdw='cd "$USERPROFILE"'
      builtin alias ping="${SystemRoot}/system32/ping.exe"
      builtin alias traceroute="${SystemRoot}/system32/tracert.exe"
      aspn_rpath=/proc/registry/HKEY_LOCAL_MACHINE/SOFTWARE/ActiveState/ActivePerl
      if [ -f ${aspn_rpath}/CurrentVersion ]; then
        read -r aspn_hive < "${aspn_rpath}/CurrentVersion"
        read -r ASPN_PATH < "${aspn_rpath}/${aspn_hive}/@"
        ASPN_PATH="$(cygpath "${ASPN_PATH}")/bin"
        v_alias perl "${ASPN_PATH}/perl.exe"
      fi
      if [ "${OPSYS}" == "win32" ]; then
        builtin alias clear='echo -ne\\033c'
        builtin alias ll='ls -Flah'
        builtin alias ls='ls -h'
      fi
    ;;
    linux)
      alias ll='ls -FlAh --color=tty'
      alias ls='ls --color=tty -h'
      alias du='du -h'
      alias df='df -h'
      alias mem='free -m'
      alias free='free -m'
    ;;
    darwin)
      ppid=$(ps -o ppid $$)
      pcomm=$(ps -o comm "${ppid/PPID/}")
      case "${pcomm}" in
        *Term*/Contents/MacOS/*Term* | *login)
          pgrep -U "${USER}" gpg-agent >& /dev/null &&{
            [ -f "${HOME}/.gpg-agent-info" ] && {
              # shellcheck disable=SC1090
              . "${HOME}/.gpg-agent-info"
              export GPG_AGENT_INFO
              export SSH_AUTH_SOCK
            }
          }
          chkcmd mvim && { export EDITOR='mvim -f' ; alias gvim=mvim ; }
        ;;
      esac
      alias ll='ls -FlAh'
      alias du='du -h'
      alias df='df -h'
    ;;
    openbsd)
      PKG_PATH="ftp://ftp.openbsd.org/pub/OpenBSD/$(uname -r)/packages/$(machine -a)/" && export PKG_PATH
      alias ll='ls -FlAh'
      alias du='du -h'
      alias df='df -h'
      alias free='vmstat'
      alias mem='vmstat'
    ;;
    solaris)
      alias ln='/usr/bin/ln'
    ;;
    *)
      alias ll='ls -FlAh'
    ;;
  esac

  case "${EDITOR}" in
    *vim*) : ;;
    *)
      chkcmd vi && export EDITOR="vi"
      chkcmd vim && export EDITOR="vim"
      [ "${DISPLAY}" ] && xdpyinfo > /dev/null && chkcmd gvim && export EDITOR="gvim -f"
    ;;
  esac
}
# cleanup
function monolith_cleanup {
  unset -f monolith_setfunc
  unset -f monolith_aliases
  unset -f monolith_cleanup
}

# Call setup routines
kickenv
monolith_setfunc
monolith_aliases

if [[ -n ${PS1} ]]; then
  # kick up gpg-agent here if we have it.
  case "${OPSYS}" in
    win32) : ;;
    *)     chkcmd gpg-connect-agent && gpg-connect-agent updatestartuptty /bye 2> /dev/null 1>&2 ;;
  esac
  case "${OPSYS}" in
    android)
      [ -e "${HOME}/.gnupg/S.gpg-agent.ssh" ] && export SSH_AUTH_SOCK="${HOME}/.gnupg/S.gpg-agent.ssh"
    ;;
  esac
  [ "${SSH_CONNECTION:-}" ] || { [ -e "${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh" ] && export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh" ; }
  # configure history for interactive sessions
  HISTCONTROL=ignoreboth
  lyricsfile="${HOME}"/.fortune/song-lyrics
  if [ -f "${lyricsfile}" ]; then
    chkcmd strfile && {
      function lyric {
        [ "${lyricsfile}" -nt "${lyricsfile}".dat ] && strfile "${lyricsfile}" >& /dev/null
        fortune "${lyricsfile}"
      }
      lyric
    }
  fi
fi

monolith_cleanup
