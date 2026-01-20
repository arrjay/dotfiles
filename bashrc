#!/bin/bash

#!# This whole shuffling about with 'read' is an attempt to not fork
#!# unnecessary processes. fork under cygwin is sloooow. so use builtins
#!# where you can, even if it makes it less clear.
#!# This was also the driving force behind the entire caching system, which
#!# cut the startup time for this under cygwin in THIRD.

# the triple underscores are because a lot of vendor shell extensions use double underscore and we don't want to stomp on that.
# on the other hand, stuff you might want to run is not prefixed at all. YOLO.
# the *quadruple* underscores are functions only used while initializing the environment and should be unset later.

# if you're shellchecking this, you will want -x to include stuff in vendor/

# specifically run these before debugging is even enabled to grab shell state - especially ${_}
___bash_invocation_parent=${_}
___bash_invocation=${0}
___bash_source_path=${BASH_SOURCE[0]}
___bash_init_argv0=${BASH_ARGV[0]}
___bash_host_tuple=${BASH_VERSINFO[5]}

## configure the debug prompt to include a timestamp.
PS4='+\t|'
## DEBUG SWITCH - UNCOMMENT TO TURN ON DEBUGGING
#set -x

# get the bash version for command definition unwinding
___bashmaj=${BASH_VERSION/.*/}
___bashmin=${BASH_VERSION#"${___bashmaj}".}
___bashmin=${___bashmin%%.*}

# set permissions for any newly created files to just ourselves.
umask 077

# version information
___rcver="6.3"
___rcver_str="jBashRc v${___rcver}(f)"

# nastyish hack for mingw32
PATH=/usr/bin:$PATH

# always configure pass keys/opts/signing req ;)
[[ "${PASSWORD_STORE_SIGNING_KEY:-}" ]] || export PASSWORD_STORE_SIGNING_KEY=43D02276EEDABA74858594CBD02D22EC7FE43DC1
[[ "${PASSWORD_STORE_GPG_OPTS:-}" ]] || export PASSWORD_STORE_GPG_OPTS="--cipher-algo AES256 --digest-algo SHA512"
export PASSWORD_STORE_ENABLE_EXTENSIONS=true

# remove any aliases we had. sorry, but you can't trust 'em ;)
____rm_aliases () {
  local line input IFS
  input="$(builtin alias)"
  IFS=$'\n'
  for line in ${input} ; do
    line="${line#alias }"
    line="${line%%=*}"
    builtin unalias "${line}"
  done
}
____rm_aliases
unset -f ____rm_aliases

# I like having USER set. If you don't have USER set, I will set it to this.
____default_username="rjlocal"

######################
## UTILITY FUNCTIONS #
######################

# tolower - convert string to lower case
___tolower () {
  local word char n ; word="${1}"
  case "${___bashmaj}" in
    2|3)
      # lowercase it one character at a time.
      for((i=0;i<${#word};++i)) ; do
        char="${word:$i:1}"
        case "${char}" in
          [A-Z])
          # lowercase the character and print it.
          n="$(printf '%d' \'"${char}")"
          n=$((n+32))
          # we are dealing with the single slash
          # shellcheck disable=SC1003
          printf '%b' '\'"$(printf '%o' "${n}")"
          ;;
          # print whatever character you got.
          *) printf '%s' "${char}" ;;
        esac
      done
      ;;
    *)
      # this is _much_ easier in set -x output ;)
      printf '%s' "${word,,}" ;;
  esac
}

# prevent errors if we're sourced in an environment that already has helper functions.
# this does mean that to upgrade versions of dotfiles, we need to *restart* the shell.
builtin declare -f __is_defined_function > /dev/null 2>&1 || __is_defined_function () {
  builtin declare -f "${1}" > /dev/null 2>&1
}
builtin declare -fr __is_defined_function

if type mapfile > /dev/null 2>&1 ; then
  # we have mapfile (bash 4...)
  # fortunately, we're not going to run into pre-4.1 bugs with it.
  __is_defined_function __is_readonly_function || __is_readonly_function () {
    __is_defined_function "${1}" || return 1
    local -a output
    local lastline
    mapfile -t output < <(builtin declare -pf "${1}")
    lastline="${output[-1]}"
    lastline="${lastline#* }"
    lastline="${lastline% *}"
    case "${lastline}" in *r*) return 0 ;; *) return 1 ;; esac
  }
else
  # we're going to loop and look for a matching line.
  # we're also going to assume subshells are _kinda broken_ here (hi Cygwin 1.5)
  # as a result, debugging this is a _chore_...
  __is_defined_function __is_readonly_function || __is_readonly_function () {
    __is_defined_function "${1}" || return 1
    local line input IFS
    input="$(builtin declare -fr)"
    IFS=$'\n'
    # while IFS= read -r line ; do
    for line in ${input} ; do
      case "${line}" in "declare -fr ${1}") return 0 ;; esac
    done
    # done < <(builtin declare -fr)

    return 1
  }
fi
builtin declare -fr __is_readonly_function

# determine if a given command, builtin, alias or function exists.
__is_defined_function chkdef || chkdef () {
  builtin type "${1}" > /dev/null 2>&1
}
builtin declare -fr chkdef
___chkdef () { chkdef "${@}" ; }

# return errors to fd 2
__is_readonly_function errmsg || errmsg () {
  echo "${*}" 1>&2
}
builtin declare -fr errmsg
___error_msg () { errmsg "${@}" ; }

# md - test and create directory if needed - requires mkdir...
chkdef mkdir && md () {
  local dir ret rs ; ret=0
  [ "${1}" ] || { errmsg "${FUNCNAME[0]}: missing operand" ; return 1 ; }

  for dir in "${@}" ; do
    [ -d "${dir}" ] && continue
    mkdir -p "${dir}" ; rs=$?
    # shellcheck disable=SC2219
    let ret=ret+rs
  done
  return "${ret}"
}

# there are two versions of the following functions - a series using printf -v
# and a series with eval. I'd really rather use the printf ones if we can.
# oh god this is ugly, obtain set -x status and manipulate it so we always get a reliable answer.
____set_x=''
case "${-}" in *x*) ____set_x=x ; set +x ;; esac
# shellcheck disable=SC2006
___printf_supports_v=`exec 2>&1 ; printf -v test -- '%s' yes ; printf '%s' "${test}"`
[ "${____set_x}" ] && set -x
# the results of printf not working are ugly :P
[[ "${___printf_supports_v}" != "yes" ]] && ___printf_supports_v="no"
# clean up global space
unset ____set_x

# this reverts commit 0e0cbc321ea
# genstrip - remove element from path-type variable
# you need to specify the variable and the element!
__is_defined_function genstrip || genstrip () {
  [ "${2}" ] || { errmsg "${FUNCNAME[0]}: missing operand (needs: ENV, directory)" ; return 1 ; }
  eval "${1}"=\""${!1//':'"${2}":/:}"\"
  eval "${1}"=\""${!1%:"${2}"}"\"
  eval "${1}"=\""${!1#"${2}":}"\"
}

[ "${___printf_supports_v}" == "yes" ] && {
  __is_readonly_function genstrip || genstrip () {
    [ "${2}" ] || { errmsg "${FUNCNAME[0]}: missing operand (needs: ENV, directory)" ; return 1 ; }
    local n s t
    # grab value of path-like variable
    t=":${!1}:"
    # handle having a trailing slash or not for the component being removed. (remove both if both)
    n="${2%/}"         ; s="${n}/"
    # remove as an element _in_ the path list
    t="${t//:${n}:/:}" ; t="${t//:${s}:/:}"
    # compress any resulting triple-colons
    t="${t//:::/:}"
    # take the beginning/ending colons back out.
    t="${t#:}"         ; t="${t%:}"
    builtin printf -v "${1}" '%s' "${t}"
  }
}

# do not touch this function again...
builtin declare -fr genstrip

# this reverts commit e80ab23b5e
# check environment variables exist, make if needed
__is_defined_function cke || cke () {
  [ "${1}" ] || { errmsg "${FUNCNAME[0]}: missing operand (needs: ENV)" ; return 1 ; }
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
  __is_readonly_function cke || cke () {
    [ "${1}" ] || { errmsg "${FUNCNAME[0]}: missing operand (needs: ENV)" ; return 1 ; }
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

builtin declare -fr cke

# genappend - add directory element to path-like element
# you need variable, then element
__is_defined_function genappend || genappend () {
  [ "${2}" ] || { errmsg "${FUNCNAME[0]}: missing operands (needs: ENV, directory(s))" ; return 1 ; }
  local e d
  e="${1}" ; shift
  cke "${e}"
  for d in "${@}" ; do
    genstrip "${e}" "${d}"
    [ -d "${d}" ] && eval "${e}"=\""${!e}":"${d}"\"
  done
}

[ "${___printf_supports_v}" == "yes" ] && {
  __is_readonly_function genappend || genappend () {
    [ "${2}" ] || { errmsg "${FUNCNAME[0]}: missing operands (needs: ENV, directory(s))" ; return 1 ; }
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

builtin declare -fr genappend

# genprepend - add directory elements to FRONT of path-like list (NOTE: takes arguments as loop - later args are in the front!)
__is_defined_function genprepend || genprepend () {
  [ "${2}" ] || { errmsg "${FUNCNAME[0]}: missing operands (needs: ENV, directory(s))" ; return 1 ; }
  local e d
  e="${1}" ; shift
  cke "${e}"
  for d in "${@}" ; do
    genstrip "${e}" "${d}"
    [ -d "${d}" ] && eval "${e}"=\""${d}":"${!e}"\"
  done
}

[ "${___printf_supports_v}" == "yes" ] && {
  __is_readonly_function genprepend || genprepend () {
    [ "${2}" ] || { errmsg "${FUNCNAME[0]}: missing operands (needs: ENV, directory(s))" ; return 1 ; }
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

builtin declare -fr genprepend

# we keep pathappend and pathprepend, even though not used, for interactive purposes :)
__is_readonly_function pathappend || pathappend () {
  genappend PATH "${@}"
}

builtin declare -fr pathappend

__is_readonly_function pathprepend || pathprepend () {
  genprepend PATH "${@}"
}

builtin declare -fr pathprepend

# determine if a given _command_ exists.
__is_readonly_function chkcmd || chkcmd () {
  [[ -z "${1}" ]] && { errmsg "${FUNCNAME[0]}: check if command exists, indicate via error code" ; return 2 ; }
  case "$(builtin type -tf "${1}" 2>&1)" in
    file) return 0 ;;
  esac
  return 1
}
builtin declare -fr chkcmd

# source file if executeable and ending in .bash
__is_readonly_function sourcex || sourcex () {
  [[ "${1}" ]] || { errmsg "${FUNCNAME[0]}: missing operand (needs: file, perferably +x ending in .bash)" ; return 1 ; }
  local f
  for f in "${@}" ; do
    case "${f}" in *.bash) : ;; *) continue ;; esac
    # shellcheck disable=SC1090
    [[ -x "${f}" ]] && source "${f}"
  done
}

##########################################
# COMMAND/ENVIRONMENT CHECKS (uncaching) #
##########################################

# we're going to override this in a moment...
# but this will work until the memoizer sets up, or in cases we never load it.

# placeholders, simply return 1 as the cache doesn't work yet
__is_defined_function mm_putenv || mm_putenv () {
  return 1
}

__is_defined_function mm_setenv || mm_setenv () {
  return 1
}

__is_defined_function zapcmdcache || zapcmdcache () {
  hash -r
}

# verify cache system is set within any function at runtime.
__is_readonly_function ___vfy_cachesys || ___vfy_cachesys () {
  [[ "${BASH_CACHE_DIRECTORY}" ]] || { errmsg "BASH_CACHE_DIRECTORY is not set" ; return 3 ; }
}

# configure command caching/tokenization dir
## !! THE BELOW TWO ARE GLOBALS WE LEAK !! ##
___cache_checked=0	# track if we've already run...
___cache_active=0
____init_cachedir () {
  # have I been here before?
  case "${___cache_checked}${___cache_active}" in
    10) return 1 ;; # not going to work
    11) return 0 ;; # already done
  esac

  # build a potential cache directory
  [[ -z "${BASH_CACHE_DIRECTORY}" ]] && {
    # do I have a homedir that is a valid directory?
    [[ -d "${HOME}" ]] || { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; }
    # is the home directory / ? (okay, actually, is it one or less characters long?)
    # this is the main scenario in which we would get 10, above.
    [[ "${#HOME}" -lt 2 ]] && { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; }

    BASH_CACHE_DIRECTORY="${HOME%/}/.cache/dotfiles"
    [[ -z "${HOSTNAME}" ]] || BASH_CACHE_DIRECTORY="${BASH_CACHE_DIRECTORY}/${HOSTNAME}-"
    [[ -z "${___bash_host_tuple}" ]] || BASH_CACHE_DIRECTORY="${BASH_CACHE_DIRECTORY}${___bash_host_tuple}"
    builtin declare -r BASH_CACHE_DIRETORY
  }

  # actually try creating that directory
  # this relies on the md function, which in turn needed a mkdir somewhere.
  chkdef md || { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; }
  md "${BASH_CACHE_DIRECTORY}"/env || { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; }

  # check if we can write _in_ the directory
  : > "${BASH_CACHE_DIRECTORY}/.lck.$$" || { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; }

  # unfortunately, rm is _not_ a builtin, so carefully walk around it.
  chkdef rm && { rm "${BASH_CACHE_DIRECTORY}/.lck.$$" > /dev/null 2>&1 || { ___cache_checked=1 ; unset BASH_CACHE_DIRECTORY ; return 1 ; } ; }

  ___cache_checked=1 ; ___cache_active=1
}

########################################
# COMMAND/ENVIRONMENT CHECKS (caching) #
########################################

# after defining md (or not), roll along with the rest of the cache system. this redefines stubs we had up above with versions that cache.
____init_cachedir && {

  # mm_putenv - save environment memo
  __is_readonly_function mm_putenv || mm_putenv () {
    local env val ; env="${1}" ; val="${!1}"
    [[ -z "${env}" ]] && { __error_msg "${FUNCNAME[0]}: save environment variable to memoization system" ; return 2 ; }

    ___vfy_cachesys || return $?
    [[ -z "${val}" ]] || printf '%s' "${val}" > "${BASH_CACHE_DIRECTORY}/env/${env}"
  }
  builtin declare -fr mm_putenv

  # mm_setenv - read environment memo if available (NOTE: this will _replace_ the envvar)
  __is_readonly_function mm_setenv || mm_setenv () {
    local env ; env="${1}"
    [[ -z "${env}" ]] && { __error_msg "${FUNCNAME[0]}: restore environment variable from memoization system" ; return 2 ; }

    ___vfy_cachesys || return $?
    [[ -f "${BASH_CACHE_DIRECTORY}/env/${env}" ]] && { read -r "${env?}" < "${BASH_CACHE_DIRECTORY}/env/${env}" ; return 0 ; }
    # export that as well
    # shellcheck disable=SC2163
    export "${env}"
  }
  builtin declare -fr mm_setenv

  __is_readonly_function zapcmdcache || zapcmdcache () {
    ___vfy_cachesys zapcmdcache || return $?
    rm -rf "${BASH_CACHE_DIRECTORY}"/env/*
    hash -r
  }
  builtin declare -fr zapcmdcache
}
unset -f ____init_cachedir

####################################################
# START ENVIRONMENT INIT (path, machine discovery) #
####################################################

# set up the PATH block here before we go looking for any more external binaries.
# to be specific, we want a readlink, or awk/ls to locate our bash.d
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

# try turning the bashrc ref (if any) into an absolute path
____find_bashrc_file () {
  # hack for older bash(?) - if we don't have a source path, _or_ an invocation...
  # *and* the bash invocation ends in /bash...
  [[ -z "${___bash_source_path}" ]] && [[ -z "${___bash_init_argv0}" ]] && {
    case "${___bash_invocation}" in
      */bash)
        # HACK: set it to $HOME/.bashrc if we have that.
        [[ -e "${HOME%/}/.bashrc" ]] && ___bash_source_path="${HOME%/}/.bashrc"
      ;;
      *) : ;;
    esac
  }

  local rcpath linkdest abspath
  # first, handle ./path/to/thing
  if [[ "${___bash_source_path}" ]]; then
    rcpath="${___bash_source_path%/*}"
    [[ "${rcpath}" == "." ]] && rcpath="${PWD}/${___bash_source_path}"
  fi

  # is this a link? where is the real file?
  if [[ -h "${___bash_source_path}" ]]; then
    chkcmd readlink && linkdest="$(readlink "${___bash_source_path}")"
    # we didn't have readlink. huh. assume the very bad place and grovel ls, sorry.
    # shellcheck disable=SC2012
    [[ "${linkdest}" ]] || {
      chkcmd ls && chkcmd awk && linkdest="$(ls -l "${___bash_source_path}" | awk -F' -> ' '{print $2}')"
    }
    case "${linkdest}" in
      /*) abspath="${linkdest}"            ;;
      '') abspath="${___bash_source_path}" ;;
      *)  abspath="${rcpath}/${linkdest}"  ;;
    esac
  else
    abspath="${___bash_source_path}"
  fi
  printf '%s' "${abspath}"
}

# shellcheck disable=SC2006
___bashrc_dir="$(____find_bashrc_file)"
unset -f ____find_bashrc_file
___bashrc_dir="${___bashrc_dir%/*}"
unset ___bash_source_path
unset ___bash_init_argv0
unset ___bash_invocation_parent

# set up auxfiles paths. order is BASH_AUX_FILES, HOME, script source dir.
___bash_auxfiles_dirs=()
[[ -d "${BASH_AUX_FILES}" ]] && ___bash_auxfiles_dirs=("${___bash_auxfiles_dirs[@]}" "${BASH_AUX_FILES}")
[[ -d "${___bashrc_dir}/bash.d" ]] && ___bash_auxfiles_dirs=("${___bash_auxfiles_dirs[@]}" "${___bashrc_dir}/bash.d")
[[ -d "${HOME}/.bash.d" ]] && ___bash_auxfiles_dirs=("${___bash_auxfiles_dirs[@]}" "${HOME}/.bash.d")

# walk the bash auxfiles and go to town
____source_selected_subtree () {
  [[ "${1}" ]] || { errmsg "${FUNCNAME[0]}: missing directory component" ; return 1 ; }
  local d
  for d in "${___bash_auxfiles_dirs[@]}" ; do
    sourcex "${d}/${1}/${___os}.bash" \
            "${d}/${1}/${___os}_bash${___bashmaj}.bash" \
            "${d}/${1}/${___os}_bash${___bashmaj}${___bashmin}.bash" \
            "${d}/${1}/${___os}-${___cpu}.bash" \
            "${d}/${1}/${___os}${___osmaj}.bash" \
            "${d}/${1}/${___os}${___osmaj}-${___cpu}.bash" \
            "${d}/${1}/${___os}${___osflat}.bash" \
            "${d}/${1}/${___os}${___osflat}-${___cpu}.bash" \
            "${d}/${1}/host-${___host}.bash"
  done
}
____source_any_subtree() {
  [[ "${1}" ]] || { errmsg "${FUNCNAME[0]}: missing directory component" ; return 1 ; }
  local d
  for d in "${___bash_auxfiles_dirs[@]}" ; do
    sourcex "${d}/${1}"/*.bash
  done
}

# configure user/host pieces			# Fedora 28
mm_setenv ___host || {
  ___host="$(___tolower "${HOSTNAME:-}")"
  ___host="${___host%%.*}"
  mm_putenv ___host
}

# try `uname -p` first
mm_setenv ___cpu || {
  chkcmd uname && {
    # okay. check if uname supports -p next.
    uname -p > /dev/null 2>&1 && {
      ___cpu="$(uname -p)"			# x86_64
      ___cpu="$(___tolower "${___cpu}")"	# x86_64
    }
  }
  # next, try from bash HOSTTYPE
  [[ -z "${___cpu}" ]] && {
    ___cpu="$(___tolower "${HOSTTYPE}")"	# x86_64
    ___cpu="${___cpu%%-linux}"			# x86_64
  }

  # i?86 == x86
  if [[ "${___cpu:2}" == 86 ]] || [[ "${___cpu:2}" == "86-pc" ]]; then
    [[ "${___cpu:0:1}" == "i" ]] && ___cpu="x86"
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
  ___os="$(___tolower "${___os}")"		# linux
  mm_putenv ___os
}

# drop ___tolower from scope now.
unset -f ___tolower

# if we _have_ a uname command, use that to fill in the release pieces.
# uname -r is POSIX spec'd so just run with it.
# also, this is _not_ cached, linux likes updates ;)
chkcmd uname && {
  # shellcheck disable=SC2006
  ___osrel="$(uname -r)"
  [[ "${___osrel}" ]] || unset osrel
}

[[ -n "${___osrel:-}" ]] && {			# 4.18.5-200.fc28.x86_64
  ___osmaj="${___osrel%%\.*}"			# 4
  ___osmin="${___osrel##"${___osmaj}."}"	# 18.5-200.fc28.x86_64
  ___osmin="${___osmin%%-*}"			# 18.5
  ___osmin="${___osmin%%\.*}"			# 18
  ___osflat="${___osmaj}${___osmin}"		# 418
}

# part of the spec for prompt extensions
___rootusr=unk

## run early platform init now
____source_selected_subtree "early-init.d"

# hacks to re-set platform vars based on experience. note we used ___osmaj, so that's why it's here.
case "${___os}" in
  windows32|msys|win32)
    ___os=win32
    # specifically for win32, throw away the osrel pieces
    unset ___osrel ___osmaj ___osmin ___osflat
    # also set USER and HOME if they're not currently
    { [ -z "${USER}" ] && [ "${USERNAME}" ] ; }    && USER="${USERNAME}"
    { [ -z "${HOME}" ] && [ "${USERPROFILE}" ] ; } && HOME="${USERPROFILE}"
    export USER HOME
    # TODO: the niceties cygwin set up aren't here
  ;;
  sunos*)         [ "${___osmaj}" == 5 ] && ___os=solaris ;;
  gnueabihf)      chkcmd uname && ___os=$(uname -s) ;; # uname -s is posix.
  android*)       [ -z "${USER}" ] && USER="${____default_username}" ; export USER ;;
esac

# re-save ___os
mm_putenv ___os

# set up more of the loader environment now
genprepend PATH \
  "${HOME%/}/Library/Python/"*/bin \
  "${HOME%/}/Library/"*/bin \
  "${HOME%/}/Applications/"*/bin \
  "${HOME%/}/.cargo/bin" \
  "${HOME%/}/.cabal/bin" \
  "${HOME%/}/.rvm/bin" \
  "${HOME%/}/bin/${___os}-${___cpu}" \
  "${HOME%/}/bin/${___os}${___osmaj}-${___cpu}" \
  "${HOME%/}/bin/${___os}${___osflat}-${___cpu}" \
  "${HOME%/}/bin/noarch" \
  "${HOME%/}/bin/${___host}"

# determine if we are a superuser or not
# shellcheck disable=SC2006
[[ "${___rootusr}" == "unk" ]] && {
  case ${___os} in
    solaris)      [ -x /usr/xpg4/bin/id ] && { [ "`/usr/xpg4/bin/id -u`" == "0" ] && ___rootusr='yes' || ___rootusr='no' ; } ;;
    *)            chkcmd id && { [ "`id -u`" == "0" ] && ___rootusr='yes' || ___rootusr='no' ; } ;;
  esac
}

____source_any_subtree "extensions.d"

# pry out some session info for interactive session niceties
___xdg_session_type='none'
___x11_environment='no'
# graphical environment?
[ "${XDG_SESSION_ID}" ] && {
  # shellcheck disable=SC2006
  chkcmd loginctl && ___xdg_session_type=`loginctl --no-ask-password show-session "${XDG_SESSION_ID}" -p Type --value`
}
____check_xhost () {
  [ "${DISPLAY}" ] && {
    chkcmd xhost && {
      xhost > /dev/null 2>&1 && { ___x11_environment='yes' ; }
    }
  }
}
____check_xhost
unset -f ____check_xhost

# source file if it exists and ends in .sh
___sourcef () {
  [ "${1}" ] || { errmsg "${FUNCNAME[0]}: missing operand (needs: file, perferably +x ending in .bash)" ; return 1 ; }
  local f
  for f in "${@}" ; do
    case "${f}" in *.sh) : ;; *) continue ;; esac
    # shellcheck disable=SC1090
    [ -f "${f}" ] && source "${f}"
  done
}

# walk the bash auxfiles and go to town
____hostsetup () {
  local d
  for d in "${___bash_auxfiles_dirs[@]}" ; do
    sourcex "${d}/opsys/${___os}.bash" \
            "${d}/opsys/${___os}_bash${___bashmaj}.bash" \
            "${d}/opsys/${___os}_bash${___bashmaj}${___bashmin}.bash" \
            "${d}/opsys/${___os}-${___cpu}.bash" \
            "${d}/opsys/${___os}${___osmaj}.bash" \
            "${d}/opsys/${___os}${___osmaj}-${___cpu}.bash" \
            "${d}/opsys/${___os}${___osflat}.bash" \
            "${d}/opsys/${___os}${___osflat}-${___cpu}.bash" \
            "${d}/host/${___host}.bash"
  done
}
____hostsetup
unset -f ____hostsetup

# run anything interactive here, assuming bash set up PS1 properly.
[[ "${PS1}" ]] && ____source_any_subtree "interactive.d"

____interactive_setup () {
  local d f c
   # if we have the git prompt support script in vendor/, load it now using ___sourcef
   {
     chkcmd git  && {
       ___sourcef "${___bashrc_dir}/vendor/git-prompt.sh" "${___bashrc_dir}/vendor/git-completion.sh"
     }
     chkcmd pass && \
       [[ "${___bashmaj}${___bashmin:0:1}" -gt 31 ]] && ___sourcef "${___bashrc_dir}/vendor/pass-completion.sh"
   }

  for d in "${___bash_auxfiles_dirs[@]}" ; do
    sourcex "${d}/prompt/common.bash" \
            "${d}/prompt/bash${___bashmaj}.bash" \
            "${d}/prompt/${___os}.bash"
  done
}
[ "${PS1}" ] && {
  ____interactive_setup
}
unset -f ____interactive_setup

# leaving the properties function _here_ as it's useful when the extension scripts don't run.
_properties () {
  printf '%s\n' "${___rcver_str}"
  printf 'account_rootcap: %s\n' "${___rootusr}"
  printf 'bash_inv: %s\n' "${___bash_invocation}"
  printf 'bashrc_dir: %s\n' "${___bashrc_dir}"
  printf 'host: %s\n' "${___host}"
  printf 'os, osmaj, osmin, cpu: %s, %s, %s, %s\n' "${___os}" "${___osmaj}" "${___osmin}" "${___cpu}"
  printf 'bashmaj, min: %s %s\n' "${___bashmaj}" "${___bashmin}"
  [[ "${BASH_CACHE_DIRECTORY:-}" ]] && printf 'cachedir: %s\n' "${BASH_CACHE_DIRECTORY}"
  printf 'printf_supports_v: %s\n' "${___printf_supports_v}"
  printf 'xdg_session_type: %s\n' "${___xdg_session_type}"
  printf 'x11_environment: %s\n' "${___x11_environment}"
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
  # this is never set with the current loader, oops!
  case ${OPSYS} in
    cygwin*|win32)
      alias du='du -h'
      alias df='df -h'
      if [ "${OPSYS}" == "win32" ]; then
        builtin alias clear='echo -ne\\033c'
      fi
    ;;
    linux)
      alias du='du -h'
      alias df='df -h'
    ;;
    darwin)
      alias du='du -h'
      alias df='df -h'
      chkcmd mvim && { export EDITOR='mvim -f' ; alias gvim=mvim ; }
    ;;
    openbsd)
      PKG_PATH="ftp://ftp.openbsd.org/pub/OpenBSD/$(uname -r)/packages/$(machine -a)/" && export PKG_PATH
      alias du='du -h'
      alias df='df -h'
      alias free='vmstat'
      alias mem='vmstat'
    ;;
    solaris)
      alias ln='/usr/bin/ln'
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
monolith_setfunc

if [[ -n ${PS1} ]]; then
  # kick up gpg-agent here if we have it.
  case "${___os}" in
    win32) : ;;
    *)     chkcmd gpg-connect-agent && gpg-connect-agent updatestartuptty /bye > /dev/null 2>&1 ;;
  esac
  case "${___os}" in
    android)
      [ -e "${HOME}/.gnupg/S.gpg-agent.ssh" ] && export SSH_AUTH_SOCK="${HOME}/.gnupg/S.gpg-agent.ssh"
    ;;
    darwin)
      # shellcheck disable=SC2207
      ppid=($(ps -o ppid $$))
      pcomm=$(ps -o comm "${ppid[1]}")
      case "${pcomm}" in
        *Term*/Contents/MacOS/*Term* | *login)
          pgrep -U "${USER}" gpg-agent > /dev/null 2>&1 && {
            [ -e "${HOME}/.gnupg/S.gpg-agent.ssh" ] && {
              export SSH_AUTH_SOCK="${HOME}/.gnupg/S.gpg-agent.ssh"
            }
            [ -f "${HOME}/.gpg-agent-info" ] && {
              # shellcheck disable=SC1090
              . "${HOME}/.gpg-agent-info"
              [[ "${GPG_AGENT_INFO}" ]] && export GPG_AGENT_INFO
              export SSH_AUTH_SOCK
            }
          }
        ;;
      esac
    ;;
  esac
  { [ "${SSH_CONNECTION:-}" ] || [ "${GNUPGHOME:-}" ] ; } || { [ -e "${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh" ] && export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh" ; }
  lyricsfile="${HOME}"/.fortune/song-lyrics
  if [ -f "${lyricsfile}" ]; then
    chkcmd strfile && {
      function lyric {
        [ "${lyricsfile}" -nt "${lyricsfile}".dat ] && strfile "${lyricsfile}" > /dev/null 2>&1
        fortune "${lyricsfile}"
      }
      lyric
    }
  fi
fi

monolith_cleanup

# things to not leak into the larger environment.
unset ____default_username
