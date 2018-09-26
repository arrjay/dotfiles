#!/bin/bash

#!# This whole shuffling about with 'read' is an attempt to not fork
#!# unnecessary processes. fork under cygwin is sloooow. so use builtins
#!# where you can, even if it makes it less clear.
#!# This was also the driving force behind the entire caching system, which
#!# cut the startup time for this under cygwin in THIRD.

# prescribe pills to offset the shakes to offset the pills you know you should take it a day at a time
#             panic! at the disco - "nails for breakfast, tacks for snacks"

# specifically run these before debugging is even enabled to grab shell state - especially ${_}
__bash_invocation_parent=${_}
__bash_invocation=${0}
__bash_source_path=${BASH_SOURCE[0]}
__bash_init_argv0=${BASH_ARGV[0]}

## DEBUG SWITCH - UNCOMMENT TO TURN ON DEBUGGING
#set -x

# nastyish hack for mingw32
PATH=/usr/bin:$PATH

# try turning these into absolute paths
__bashrc_path=$__bash_source_path
if [ "${__bashrc_path}" ]; then
  __bashrc_dir="${__bashrc_path%/*}"

  [ "${__bashrc_dir}" == "." ] && __bashrc_path="${PWD}/${__bashrc_path}"
fi

# is this a link? where is the real file?
# oh, and THANKS SO MUCH SOLARIS for not having readlink!
if [[ ${__bashrc_path} && -h "${__bashrc_path}" ]]; then
  # yeaaaah, but I don't have chkcmd yet.
  # shellcheck disable=SC2012
  ___linkdest="$(ls -l "${__bashrc_path}"|awk -F' -> ' '{print $2}')"
  case "${___linkdest}" in
    /*) __bashrc_path="${___linkdest}" ;;
    *)  __bashrc_path="${__bashrc_dir}/${___linkdest}" ;;
  esac
fi

# Run rcdir again, in an attempt to get more information
if [ "${__bashrc_path}" ]; then
  case "${__bashrc_path}" in
    /*) : ;;
    *)  __bashrc_path=${__bashrc_dir}/${__bashrc_path} ;;
  esac
  __bashrc_dir="${__bashrc_path%/*}"
fi

# version information
JBVER="5.0b"
JBVERSTRING='jBashRc v'${JBVER}'(u)'

BASH_MAJOR=${BASH_VERSION/.*/}
BASH_MINOR=${BASH_VERSION#${BASH_MAJOR}.}
BASH_MINOR=${BASH_MINOR%%.*}

BASHFILES="${HOME}/.bash.d"

## path(-like) functions
#?# TEST: do these work for directories with spaces?

# genstrip - remove element from path-type variable
# you need to specify the variable and the element!
function genstrip {
  local n s t
  t="${!1}"
  n="${2%/}"         ; s="${n}/"
  t="${t//:${n}:/:}" ; t="${t//:${s}:/:}"
  t="${t%:${n}}"     ; t="${t%:${s}}"
  t="${t#${n}:}"     ; t="${t%${s}:}"
  builtin printf -v "${1}" '%s' "${t}"
}

# t_mkdir - test and create directory if needed
function t_mkdir {
  if [ ! -n "${1}" ]; then
    echo "${FUNCNAME[$0]}: missing operand" 1>&2
    return 1
  fi

  if [ ! -d "${1}" ]; then
    mkdir -p "${1}"
  fi
}

# getconn - get where we are connecting from
function getconn {
  if [ -n "${SSH_CONNECTION}" ]; then
    CURTTY=${SSH_TTY}
    CONNFROM=${SSH_CLIENT/ *}
  else
    CURTTY=$(tty)
    [ "${OPSYS}" != "win32" ] && CURTTY=${CURTTY:5}
    CONNFROM=$(who|awk '$0 ~ "'"${CURTTY}"'" { print $5 }')
    CONNFROM=${CONNFROM//(/}
    CONNFROM=${CONNFROM//)/}
  fi
  if [ ! -n "${CONNFROM}" ]; then
    echo "no remote connection found" 1>&2
    unset CONNFROM
    return 1
  else
    echo "${CONNFROM}"
  fi
}

# initcachedirs - create command cache directories
function initcachedirs {
  CMDCACHE="${HOME}/.cmdcache/${FQDN}-${OPSYS}"
  t_mkdir "${CMDCACHE}/chkcmd"
  t_mkdir "${CMDCACHE}/env"
}

#!# ALL FUNCTIONS USE STRIPPATH TO REMOVE DUPLICATES
#!# ALL FUNCTIONS CHECK EXISTENCE OF DIRECTORY BEFORE ADDING!
function cke {
  local x
  for x in "${@}" ; do
    # check if environment variable exists, make if needed
    if [[ -z "${x}" ]]; then
      printf -v "${x}" ""
    fi
    # always export the thing
    # shellcheck disable=SC2163
    export "${x}"
  done
}

# genappend - add directory element to path-like element
# you need variable, then element
function genappend {
  local t d
  d="${2}"
  genstrip "${1}" "${d}"
  t="${!1}"
  cke "${1}"
  [ -d "${d}" ] && builtin printf -v "${1}" '%s' "${t}:${d}"
}

# genprepend - add directory element to FRONT of path-like list
function genprepend {
  local t d
  d="${2}"
  genstrip "${1}" "${d}"
  t="${!1}"
  cke "${1}"
  [ -d "${d}" ] && builtin printf -v "${1}" '%s' "${d}:${t}"
}

# we keep pathappend and pathprepend, even though not used, for interactive purposes :)
function pathappend {
  genappend PATH "${1}"
}
function pathprepend {
  genprepend PATH "${1}"
}

# pathsetup - set system path to work around cases of extreme weirdness (yes I have seen them!)
function pathsetup {
  local __path_prepend_list d
  __path_prepend_list=(
    "/etc"
    "/usr/etc"
    "/usr/sysadm/privbin"
    "/usr/games"
    "/sbin"
    "/usr/sysadm/bin"
    "/usr/sbin"
    "/usr/ccs/bin"
    "/usr/sfw/bin"
    "/usr/pkg/sbin"
    "/usr/tgcware/sbin"
    "/usr/local/sbin"
    "/usr/gfx"
    "/usr/dt/bin"
    "/usr/openwin/bin"
    "/usr/bin/X11"
    "/usr/X11R6/bin"
    "/bin"
    "/usr/bin"
    "/usr/pkg/bin"
    "/usr/xpg4/bin"
    "/usr/bsd"
    "/usr/ucb"
    "/usr/kerberos/bin"
    "/usr/nekoware/bin"
    "/usr/tgcware/bin"
    "/opt/local/bin"
    "/usr/local/bin"
  )
  for d in "${__path_prepend_list[@]}" ; do genprepend PATH "${d}" ; done

  case "${OPSYS}" in
    cygwin*)
      SystemDrive=$(mm_getenv SystemDrive) || {
        # shellcheck disable=SC2153
        SystemDrive=$(cygpath "${SYSTEMDRIVE}")
        mm_putenv SystemDrive
      }
      SystemRoot=$(mm_getenv SystemRoot) || {
        # shellcheck disable=SC2153
        SystemRoot=$(cygpath "${SYSTEMROOT}")
        mm_putenv SystemRoot
      }
      ProgramFiles=$(mm_getenv ProgramFiles) || {
        # shellcheck disable=SC2153
        ProgramFiles=$(cygpath "${PROGRAMFILES}")
        mm_putenv ProgramFiles
      }
      ProgramFilesX86=$(mm_getenv ProgramFilesX86) || {
        chkcmd cygpath && ProgramFilesX86="$(cygpath -F 0x2a)" || ProgramFilesX86="${ProgramFiles} (x86)"
	mm_putenv ProgramFilesX86
      }
      genappend PATH "${SystemDrive}/bin"
      ;;

    win32)
      SystemDrive=$(mm_getenv SystemDrive) || {
        { chkcmd cygpath && SystemDrive="$(cygpath "${SYSTEMDRIVE}")" ; } || SystemDrive="${SYSTEMDRIVE}"
	mm_putenv SystemDrive
      }
      SystemRoot=$(mm_getenv SystemRoot) || {
        { chkcmd cygpath && SystemRoot="$(cygpath "${SYSTEMROOT}")" ; } || SystemRoot="${SYSTEMROOT}"
	mm_putenv SystemRoot
      }
      ProgramFiles=$(mm_getenv ProgramFiles) || {
        { chkcmd cygpath && ProgramFiles="$(cygpath "${PROGRAMFILES}")" ; } || ProgramFiles="${PROGRAMFILES}"
	mm_putenv ProgramFiles
      }
      ProgramFilesX86=$(mm_getenv ProgramFilesX86) || {
        chkcmd cygpath && ProgramFilesX86="$(cygpath -F 0x2a)" || ProgramFilesX86="${ProgramFiles} (x86)"
	mm_putenv ProgramFilesX86
      }
      ;;

  esac

  case "${OPSYS}" in
    cygwin*|win32)
      cke SystemDrive SystemRoot ProgramFiles
      t_mkdir "${CMDCACHE}/chkcmd/${SystemRoot}/system32"
      genprepend PATH "${ProgramFilesX86}/Gpg4win/bin"
      genprepend PATH "${ProgramFiles}/Gpg4win/bin"
      genprepend PATH "${ProgramFilesX86}/GnuPG/bin"
      genprepend PATH "${ProgramFiles}/GnuPG/bin"
      [ -e "${ProgramFilesX86}/EditPlus/editplus.exe" ] && editplus () { "${ProgramFilesX86}/EditPlus/editplus.exe" "${@}"; }
      [ -e "${ProgramFiles}/EditPlus/editplus.exe" ] && editplus () { "${ProgramFiles}/EditPlus/editplus.exe" "${@}"; }
    ;;
  esac
}

function set_manpath {
  local __path_prepend_list d
  __path_prepend_list=(
    "/usr/X11R6/man"
    "/usr/openwin/man"
    "/usr/dt/man"
    "/usr/share/man"
    "/usr/man"
    "/usr/pkg/man"
    "/usr/local/share/man"
    "/usr/local/man"
  )
  for d in "${__path_prepend_list[@]}" ; do genappend MANPATH "${d}" ; done

  if [ -d /opt ]; then
    for d in /opt/*/man ; do
      genappend MANPATH "${d}"
    done
  fi
  genappend MANPATH "${SystemRoot}/man"

  cke MANPATH
}

## internal functions
#-# HELPER FUNCTIONS
#--# Text processing
# matchstart - match word at beginning of a line (anywhere in a file) [used by getterminfo]
#?# TEST: spaces?
function matchstart {
  grep -q "^${1}" "${2}"
}

# tolower - convert string to lower case, in pure bash
function tolower {
  local output
  output=${1//A/a}
  output=${output//B/b}
  output=${output//C/c}
  output=${output//D/d}
  output=${output//E/e}
  output=${output//F/f}
  output=${output//G/g}
  output=${output//H/h}
  output=${output//I/i}
  output=${output//J/j}
  output=${output//K/k}
  output=${output//L/l}
  output=${output//M/m}
  output=${output//N/n}
  output=${output//O/o}
  output=${output//P/p}
  output=${output//Q/q}
  output=${output//R/r}
  output=${output//S/s}
  output=${output//T/t}
  output=${output//U/u}
  output=${output//V/v}
  output=${output//W/w}
  output=${output//X/x}
  output=${output//Y/y}
  output=${output//Z/z}
  echo "${output}"
}

# sourcex - source file if found executable
function sourcex {
  # shellcheck disable=SC1090
  [ -x "${1}" ] && source "${1}"
}

# mm_getenv - read environment memo if available 
function mm_getenv {
  local output
  if [ -f "${CMDCACHE}/env/${1}" ]; then
    read -r output < "${CMDCACHE}/env/${1}"
    echo "${output}"
  else
    false
  fi
}

function mm_putenv {
  echo "${!1}" > "${CMDCACHE}/env/${1}"
}

function zapcmdcache {
  rm -rf "${CMDCACHE}"/chkcmd/*
  rm -rf "${CMDCACHE}"/env/*
  hash -r
}

# chkcmd - check if specific command is present, wrapper around which being evil on some platforms
function chkcmd {
  local found
  if [ ! -n "${1}" ]; then
    echo "${FUNCNAME[0]}: check if command exists, indicate via error code" 1>&2
    return 2
  fi
  if [ -f "${CMDCACHE}/chkcmd/${1}" ]; then
    read -r found < "${CMDCACHE}/chkcmd/${1}"
    case "${found}" in
      true) return 0 ;;
      *)    return 1 ;;
    esac
  else
    case ${WSTR} in
      "0 1"|"1 1"|"2 1")
        if "${REAL_WHICH}" "${1}" &> /dev/null ; then
          echo "true" > "${CMDCACHE}/chkcmd/${1}"
          return 0
        else
          echo "false" > "${CMDCACHE}/chkcmd/${1}"
          return 1
        fi
      ;;
      *)
        "${REAL_WHICH}" "${1}" 2>&1 | grep -q ^no
        if [ ${?} == "1" ]; then
          echo "true" > "${CMDCACHE}/chkcmd/${1}"
          return 0
        else
          echo "false" > "${CMDCACHE}/chkcmd/${1}"
          return 1
        fi
      ;; 
    esac
  fi
}

# v_alias - overloads command with specified function if command exists
function v_alias {
  if [ ! -n "${1}" ]; then
    builtin alias
    return $?
  fi
  chkcmd "${2}" && builtin alias "${1}=${2}"
}

#-# SETUP FUNCTIONS
# colordefs - defines for XTerm/Console colors
# shellcheck disable=SC2034
function colordefs {
  RS='\[\e[0m\]' # I think this is xterm specific?
  # BC - bold colorset
  BC_LT_GRA='\[\e[0;37m\]'
  BC_BO_LT_GRA='\[\e[1;37m\]'
  #BC_DM_GRA='\[\e[2;37m\]' # 2-series not supported by xterm?
  BC_CY='\[\e[0;36m\]'
  BC_GRN='\[\e[0;32m\]'
  BC_BL='\[\e[0;34m\]'
  BC_PR='\[\e[0;35m\]'
  BC_BR='\[\e[0;33m\]'
  BC_RED='\[\e[0;31m\]'
}

# getterminfo - initialize term variables for function use
# we set color caps EVERY time in case of environment being handed to us via ssh/screen/?
function getterminfo {
  case ${TERM} in
    ## bright (vs. bold), titleable terms
    cygwin*)
      TERM_CAN_TITLE=1 ; TERM_COLORSET="bright" ;TERM_CAN_SETCOLOR=0 ;;
    ## bold, titleable terms (with background colorset cmds!)
    xterm*|rxvt*)
      TERM_CAN_TITLE=1 ; TERM_COLORSET="bold" ; TERM_CAN_SETCOLOR=1 ;;
    ## bold, titlable terms (w/o background color caps)
    # putty - not available in everyone's termcaps... we work around that.
    putty*)
      TERM_CAN_TITLE=1 ; TERM_COLORSET="bold" ; TERM_CAN_SETCOLOR=0
      [[ ! ( $(matchstart "${TERM}" /etc/termcap) = 0 ) ]] && export TERM=xterm ;;
    ## bright, not titleable
    linux*|ansi*)
      TERM_CAN_TITLE=0 ; TERM_COLORSET="bright" ; TERM_CAN_SETCOLOR=0 ;;
      # okay, a lie for linux, but it sets codes very differently than Xterm.
    ## bold, not titleable (have not seen...)

    ## SCREEN
    # ah yes, screen... just assume we're running it as an xterm
    # it drops color codes the incoming terminal doesn't understand :)
    # also, work around missing termcap entry. or the 'screen.linux' shit
    screen*)
      TERM_CAN_TITLE=1 ; TERM_COLORSET="bold" ; TERM_CAN_SETCOLOR=1
      if [ -f /etc/termcap ]; then
        if [[ ! ( $(matchstart "${TERM}" /etc/termcap) = 0 ) ]]; then
          if [[ ! ( $(matchstart screen /etc/termcap) = 0 ) ]]; then
            export TERM=xterm # be an xterm!
          else
            export TERM=screen
          fi
        fi
        elif [ -d /usr/share/terminfo/s ]; then
          if [ ! -f "/usr/share/terminfo/s/${TERM}" ]; then
            if [ -f /usr/share/terminfo/s/screen ]; then
              export TERM=screen
            else
              export TERM=xterm
            fi
          fi
        fi
      ;;
      ## failsafe for when we have no idea
      *)
        TERM_CAN_TITLE=0 ; TERM_COLORSET="none" ; TERM_CAN_SETCOLOR=0 ;;
  esac
}

# gethostinfo - initialize host variables for function use
function gethostinfo {
  local x p
  #?# TEST: are all unames created equal?
  #!# all trs are *not* created equal
  if [ -x /usr/bin/tr ]; then alias tr=/usr/bin/tr; fi
  FQDN=$(tolower "${HOSTNAME}")
  HOST=${FQDN%%\.*} # in case uname returns FQDN
  # shellcheck disable=SC2034
  DOMAIN=${FQDN##${HOST}.}
  CPU=$(tolower "${HOSTTYPE}")
  CPU=${CPU%%-linux}
  OPSYS=${BASH_VERSINFO[5]##${CPU}-}
  OPSYS=${OPSYS%%-gnu}
  OPSYS=${OPSYS##*-}
  OPSYS=${OPSYS%%[0-9]*}
  AVER=$(uname -r)
  MVER=${AVER%%\.*}
  LVER=${AVER##${MVER}.}	# remainder of AVER...
  LVER=${LVER%%-*}	# don't care about -RELEASE, -STABLE
  LVER=${LVER%%\.*}	# don't care about sub-minor versions
  LVER=${MVER}${LVER}
	
  case $OPSYS in
    # hack around cygwin including the Windows ver
    cygwin*) OPSYS=cygwin ;;
    # shorten 'windows32' set USER, HOME
    windows32|msys)
      OPSYS=win32
      unset LVER	# version of MSYS?
      unset MVER
      # you cannot call chkcmd yet
      [ -z "$USER" ] && USER=$USERNAME
      [ -z "$HOME" ] && HOME=$USERPROFILE
      ;;
    # the first of MANY hacks around solaris
    sunos)
      CPU=$(uname -p|tr '[:upper:]' '[:lower:]')
      [ "${MVER}" == 5 ] && OPSYS="solaris"
      ;;
    # OS X is actually similar here
    darwin)
      CPU=$(uname -p|tr '[:upper:]' '[:lower:]') ;;
    android*) export USER=rjlocal ;;
    # what the fuck raspbian
    gnueabihf)
      OPSYS=$(uname -s)
    ;;
  esac

  # i?86 == x86
  if [ "${CPU:2}" == 86 ] || [ "${CPU:2}" == "86-pc" ]; then
    [ "${CPU:0:1}" == "i" ] && CPU="x86"
  fi
	
  # initialize the cache system
  initcachedirs

  # while we're here, find 'which' and see if it works
  dealias which
  REAL_WHICH=$(mm_getenv REAL_WHICH) || {
    REAL_WHICH=$(which which) || REAL_WHICH="/usr/bin/which" # Pray!
      if { [ "${__bashrc_path}" -nt "${HOME}"/.whichery.sh ] || [ ! -e "${HOME}/.whichery.sh" ] ; } then
        (
          cat <<\WHICHERY
            if [[ "${REAL_WHICH}" =~ ":" ]]; then
            # paths do not contain colons, wtf?
            REAL_WHICH=/usr/bin/which
            fi
WHICHERY
        ) > "${HOME}"/.whichery.sh
      fi
    # shellcheck disable=1090
    . "${HOME}"/.whichery.sh
    mm_putenv REAL_WHICH
  }

  WSTR=$(mm_getenv WSTR) || {
    WSTR=$("${REAL_WHICH}" --help 2>&1 | grep ^no > /dev/null ; echo "${PIPESTATUS[@]}")
    # 1 0 - which returned an error, grep did not - bad which
    # 1 1 - which returned an error, grep did too - bad which (?)
    # 2 1 - which returned an error, grep did too - strange which
    # 0 1 - which success, grep returned an error - good which
    # 0 0 - which success, grep success           - EVIL WHICH!
    mm_putenv WSTR
  }

  REAL_SU=$(mm_getenv REAL_SU) || {
    REAL_SU=$("${REAL_WHICH}" su 2> /dev/null)
    mm_putenv REAL_SU
  }

  # shellcheck disable=2034
  SED=$(mm_getenv SED) || {
    SED=$("${REAL_WHICH}" sed 2> /dev/null) || SED="/bin/sed"
    mm_putenv SED
  }

  # are we a laptop (rather, do we have ACPI or APM batteries?)
  case ${OPSYS} in
    linux|android*)
      # try sysfs first.
      {
        ls /sys/class/power_supply/BAT* > /dev/null 2>&1 || \
        ls /sys/class/power_supply/CMB* > /dev/null 2>&1 || \
        ls /sys/class/power_supply/battery > /dev/null 2>&1 ;
      } && {
        # using sysfs to deal with power status
        PMON_TYPE="lxsysfs"
        # clear battery list
        PMON_BATTERIES=""
        for x in /sys/class/power_supply/BAT*/present /sys/class/power_supply/CMB*/present /sys/class/power_supply/battery/present ; do
          if [ -f "${x}" ] ; then
            read -r p < "${x}" ; if [ -n "${p}" ] && [ "${p}" == 1 ]; then
              # we have a battery here
              PMON_BATTERIES="$(basename "${x///present/}") $PMON_BATTERIES"
            fi
          fi
        done
      }
      # if we have termux-battery-status *and* jq, use those.
      chkcmd termux-battery-status && chkcmd jq && PMON_TYPE="termux" && PMON_BATTERIES="termux-api"
    ;;
    *) : ;; # I have no idea.
  esac
}

# getuserinfo - initialize user variables for function use (mostly determine if we are a superuser)
function getuserinfo {
  case ${OPSYS} in
    win32)
      # set printer here
      PRINTER="$(cscript //nologo "${SystemRoot}/system32/prnmngr.vbs" -g)"
      PRINTER="${PRINTER//The default printer is /}"
      export PRINTER
    ;;
    cygwin*)
      id -G | grep -q 544 && HD='#' || HD='$' ;;
    solaris)
      [ "$(/usr/xpg4/bin/id -u)" == "0" ] && HD='#' || HD='$' ;;
    *)
      [ "$(id -u)" == "0" ] && HD='#' || HD='$' ;;
  esac
}

# hostsetup - call host/os-specific subscripts
# call after gethostinfo, BEFORE getuserinfo!
function hostsetup {
  sourcex "${BASHFILES}/opsys/${OPSYS}.sh"
  sourcex "${BASHFILES}/opsys/${OPSYS}-${CPU}.sh"
  sourcex "${BASHFILES}/opsys/${OPSYS}${MVER}.sh"
  sourcex "${BASHFILES}/opsys/${OPSYS}${MVER}-${CPU}.sh"
  sourcex "${BASHFILES}/opsys/${OPSYS}${LVER}.sh"
  sourcex "${BASHFILES}/opsys/${OPSYS}${LVER}-${CPU}.sh"
  sourcex "${BASHFILES}/host/${HOST}.sh"
  sourcex "${BASHFILES}/extensions.sh"
}

# pbinsetup - load personal bin directory for host
function pbinsetup {
  local dir
  # add our personal ~/Applications subdirectories
  for dir in "${HOME}"/Library/Python/*/bin "${HOME}"/Library/*/bin "${HOME}"/Applications/*/bin ; do
    genprepend PATH "${dir}"
  done

  genprepend PATH "${HOME}/.cargo/bin"
  genprepend PATH "${HOME}/.rvm/bin"
  genprepend PATH "${HOME}/bin/${OPSYS}-${CPU}"
  genprepend PATH "${HOME}/bin/${OPSYS}${MVER}-${CPU}"
  genprepend PATH "${HOME}/bin/${OPSYS}${LVER}-${CPU}"
  genprepend PATH "${HOME}/bin/noarch"
  genprepend PATH "${HOME}/bin/${HOST}"

  # set PERL5LIB here
  if [ -d "${HOME}"/Library/perl5 ]; then
    export PERL_MB_OPT="--install_base ${HOME}/Library/perl5"
    export PERL_MM_OPT="INSTALL_BASE=${HOME}/Library/perl5"
    export PERL_LOCAL_LIB_ROOT="${HOME}/Library/perl5"
    genappend PERL5LIB "${HOME}/Library/perl5"
    if [ -d "${HOME}/Library/perl5/lib/perl5" ]; then
      genappend PERL5LIB "${HOME}/Library/perl5/lib/perl5"
      if [ -d "${HOME}/Library/perl5/lib/perl5/${CPU}-${OPSYS}-gnu-thread-multi" ]; then
        genappend PERL5LIB "${HOME}/Library/perl5/lib/perl5/${CPU}-${OPSYS}-gnu-thread-multi"
      fi
    fi
  fi

  # configure GOPATH/GOROOT here
  if [ -f "${HOME}"/Library/go-dist/bin/go ] ; then
    # go distribution in go-dist, gopath in go, gox is happy, go away.
    export GOROOT="${HOME}/Library/go-dist"
  fi
  if [ -d "${HOME}"/Library/go ]; then
    if [ -f "${HOME}"/Library/go/bin/go ] ; then
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

  # add our personal ~/Library subdirectories
  for dir in "${HOME}"/Library/*/lib ; do
    genappend LD_LIBRARY_PATH "${dir}"
  done
  cke LD_LIBRARY_PATH
}

# zapenv - kill all environment setup routines, including itself(!)
function zapenv {
  unset -f pathsetup
  unset -f getterminfo
  unset -f gethostinfo
  unset -f getuserinfo
  unset -f hostsetup
  unset -f pbinsetup
  unset -f kickenv
  unset -f colordef
  unset -f matchstart
  unset -f set_manpath
  unset -f zapenv
}

# kickenv - run all variable initialization, set PATH.
function kickenv {
  # first and formost, prevent others from reading our precious files
  umask 077
  gethostinfo # set REAL_WHICH!!
  pathsetup
  # shellcheck disable=SC1090
  [[ -f "${__bashrc_dir}/vendor/git-prompt.sh" ]] && source "${__bashrc_dir}/vendor/git-prompt.sh"
  hostsetup # to extend path, at least for solaris
  getuserinfo
  getterminfo
  colordefs
  set_manpath
  pbinsetup
  # shellcheck disable=SC1090
  [[ -s "${HOME}/.rvm/scripts/rvm" ]] && source "${HOME}/.rvm/scripts/rvm"
  zapenv
}

#-# TERMINAL FUNCTIONS
# writetitle - update xterm titlebar
function writetitle {
  # shellcheck disable=SC2145
  [ ${TERM_CAN_TITLE} == 1 ] && echo -ne "\\e]0;${@}\\a"
}

# setcolors - set xterm/rxvt background/foreground/highlight colors
# arguments (fgcolor bgcolor) <- arguments as colorstrings (termspecific)
function setcolors {
  # shellcheck disable=SC2145
  [ ${TERM_CAN_SETCOLOR} == 1 ] && {
    echo -ne "\\e]10;${1}\\a" # foreground
    echo -ne "\\e]17;${1}\\a" # highlight
    echo -ne "\\e]11;${2}\\a" # background
  }
}


# display functions
# pscount - return count of processes on this system (stub, returns -1. should be replaced by opsys-specific call.)
function pscount {
  echo -n "-255"
}

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

# overloaded commands
# (m)which - which with function expansion (when possible)
function mwhich {
  if [[ ${WSTR} == "0 1" ]]; then
    (alias; declare -f) | "${REAL_WHICH}" --tty-only --read-alias --read-functions --show-tilde --show-dot "${@}"
  else
    if [ "${BASH_MAJOR}" -gt "2" ]; then
      declare -f|grep -q "^${1}" && declare -f "${1}"
    else
      FUNCTION=$(declare -f|grep "^declare"|grep ' '"${1}"' ') && declare -f "$(echo "${FUNCTION}"|awk '{ print $3 }')"
    fi
    alias|grep "alias ${1}="
      "${REAL_WHICH}" "${1}"
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
      PMON_CAP=0
      # get total capacity
      case "${PMON_TYPE}" in
        lxsysfs)
          _SYSFSPATH="/sys/class/power_supply"
          for x in $PMON_BATTERIES; do
            # if we're reporting energy, use that first
            # FIXME: what happens when one battery reports in energy, the other in charge? (never seen!)
            if [ -f "$_SYSFSPATH/${x}/energy_full" ]; then
              read -r p < $_SYSFSPATH/${x}/energy_full
            elif [ -f "$_SYSFSPATH/${x}/charge_full" ]; then
              read -r p < $_SYSFSPATH/${x}/charge_full
            fi
            PMON_CAP=$((p + PMON_CAP))
          done
        ;;
        termux)
          # termux only returns percentage
          PMON_CAP=100
        ;;
      esac
      echo "${PMON_CAP}"
    ;;
    chrg)
      PMON_CHARGE=0
      case $PMON_TYPE in
        lxsysfs)
          _SYSFSPATH="/sys/class/power_supply"
          for x in $PMON_BATTERIES; do
            if [ -f "$_SYSFSPATH/${x}/energy_now" ]; then
              read -r p < $_SYSFSPATH/${x}/energy_now
            elif [ -f $_SYSFSPATH/${x}/charge_now ] ; then
              read -r p < $_SYSFSPATH/${x}/charge_now
            fi
            PMON_CHARGE=$((p + PMON_CHARGE))
          done
        ;;
        termux) PMON_CHARGE=$(jq .percentage < "$HOME/.termux-battery-status") ;;
      esac
      echo "${PMON_CHARGE}"
    ;;
    chgpct)
      _candidate=''
      case "${PMON_TYPE}" in
        lxsysfs)
          _SYSFSPATH="/sys/class/power_supply"
          for x in $PMON_BATTERIES; do
            [ -f $_SYSFSPATH/${x}/capacity ] && read -r _candidate < $_SYSFSPATH/${x}/capacity
          done
        ;;
      esac
      if [ -z "${_candidate}" ]; then
        echo $(($(battstat chrg)00 / $(battstat cap)))
      else
        echo "${_candidate}"
      fi
    ;;
    stat)
      # discahrge (v), idle (-), or charging (^)?
      # batteries at idle is the default state
      PMON_STAT="-"
      case "${PMON_TYPE}" in
        lxsysfs)
          for x in ${PMON_BATTERIES}; do
            read -r p < "/sys/class/power_supply/${x}/status"
            case "${p}" in
              Charging)    PMON_STAT="^" ;;
              Discharging) PMON_STAT="v" ;;
            esac
          done
        ;;
        termux)
          __plugged=$(jq -r .plugged < "$HOME/.termux-battery-status")
          __status=$(jq -r .status < "$HOME/.termux-battery-status")
          [ "${__status}" == "NOT_CHARGING" ] && [ "${__plugged}" == "UNPLUGGED" ] && PMON_STAT="v"
          [ "${__status}" == "CHARGING" ] && PMON_STAT="^"
        ;;
      esac
      echo "${PMON_STAT}"
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
    linux|Linux|android*)
      function pscount {
        local __psc __psf
        __psf=( /proc/[0-9]* )
        __psc=$(( ${#__psf[@]} - 1 ))
        echo "${__psc}"
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
  alias md='t_mkdir'
  alias rd='rm -rf'
  alias copy='cp'
  alias move='mv'
  alias tracert='traceroute'

  # override system which with our more flexible version...
  alias which='mwhich'

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

export PASSWORD_STORE_SIGNING_KEY=B1A086C36A2C52A79015F25C95B6669B9D085FA5
export PASSWORD_STORE_GPG_OPTS="--cipher-algo AES256 --digest-algo SHA512"
export PASSWORD_STORE_ENABLE_EXTENSIONS=true

# hook for extension.sh prompt text
function prompt_ext {
  echo -n ' '
}

# export the prompt
function setprompt {
  # shellcheck disable=SC2006
  # disable all backtick checks here because PS1 evaluation is "different"
  if [[ -n "${PS1}" ]]; then
    case "$1" in
      simple)
        PS1="${INVNAME}-${BASH_MAJOR}.${BASH_MINOR}${HD} "
      ;;
      classic)
        PROMPT_COMMAND="writetitle ${USER}@${HOST}:\`pwd\`"
        setprompt simple
      ;;
      old)
        PROMPT_COMMAND="writetitle ${USER}@${HOST}:\`pwd\`"
        PS1="${BC_LT_GRA}\\t ${BC_PR}[\\u@${HOST}] ${BC_BL}{${CURTTY}}${RS}"'`__git_ps1``prompt_ext`'"\\n${BC_RED}<"'$(pscount)'"> ${BC_GRN}(\\W) ${BC_BR}${HD}${RS} "
      ;;
      timely)
        PROMPT_COMMAND="writetitle ${USER}@${HOST}:\`pwd\`"
        case "${TERM_COLORSET}" in
          bold|bright)
            PS1="${BC_BR}#${RS} ${BC_CY}(\\t)${RS} ${BC_PR}?"'${?}'"${RS} ${BC_GRN}!\\!${RS} ${BC_LT_GRA}\\u${RS}${BC_GRN}@${RS}${BC_LT_GRA}${HOST}${RS} ${BC_GRN}"'`pscount`'" ${RS}${BC_PR}{\\W}${RS}"'`__git_ps1``prompt_ext`'"${BC_BR}${HD}${RS}\\n"
          ;;
          *)
            PS1="# (\\t) ?"'${?}'" !\\! \\u@${HOST} $(pscount) {\\W}`__git_ps1``prompt_ext` ${HD}\\n" # mono
          ;;
        esac
      ;;
      new_nocount)
        # like new, but hides the process count
        PROMPT_COMMAND="writetitle ${USER}@${HOST}:\`pwd\`"
        case ${TERM_COLORSET} in
          bold|bright)
            PS1="${BC_BR}#${RS} ${BC_PR}?"'${?}'"${RS} ${BC_GRN}!\\!${RS} ${BC_LT_GRA}\\u${RS}${BC_CY}@${RS}${BC_LT_GRA}${HOST}${RS} ${BC_PR}{\\W}${RS}"'`__git_ps1``prompt_ext`'"${BC_BR}${HD}${RS}\\n"
          ;;
          *)
            PS1="# ?"'${?}'" !\\! \\u@${HOST} {\\W}"'`__git_ps1``prompt_ext`'"${HD}\\n" # mono
          ;;
        esac
      ;;
      new_pmon)
        # new prompt with battery minder
        PROMPT_COMMAND="writetitle ${USER}@${HOST}:\`pwd\`;case $PMON_TYPE in termux) (flock -w 2 -xn $HOME/.termux-battery-status-lock bash -c 'termux-battery-status > $HOME/.termux-battery-status.new && mv $HOME/.termux-battery-status.new $HOME/.termux-battery-status' & ) ;; esac"
        case ${TERM_COLORSET} in
          bold|bright)
            PS1="${BC_BR}#${RS} ${BC_PR}?"'${?}'"${RS} ${BC_GRN}!\\!${RS} ${BC_LT_GRA}\\u${RS}${BC_CY}@${RS}${BC_LT_GRA}${HOST}${RS} ${BC_GRN}"'`pscount`'" ${RS}("'`battstat chgpct`'"%"'`battstat stat`'") ${RS}${BC_PR}{\\W}${RS}"'`__git_ps1``prompt_ext`'"${BC_BR}${HD}${RS}\\n"
          ;;
          *)
            PS1="# ?"'${?}'" !\\! \\u@${HOST} $(pscount) (`battstat chgpct`%`battstat stat`) {\\W}"'`__git_ps1``prompt_ext`'"${HD}\\n" # mono
          ;;
        esac
      ;;
      new|*)
        PROMPT_COMMAND="writetitle ${USER}@${HOST}:\`pwd\`"
        case ${TERM_COLORSET} in
          bold|bright)
            PS1="${BC_BR}#${RS} ${BC_PR}?"'${?}'"${RS} ${BC_GRN}!\\!${RS} ${BC_LT_GRA}${USER}${RS}${BC_CY}@${RS}${BC_LT_GRA}${HOST}${RS} ${BC_GRN}"'`pscount`'" ${RS}${BC_PR}{\\W}${RS}"'`__git_ps1``prompt_ext`'"${BC_BR}${HD}${RS}\\n"
          ;;
          *)
            PS1="# ?"'${?}'" !\\! ${USER}@${HOST} $(pscount) {\\W}"'`__git_ps1``prompt_ext`'"${HD}\\n" # mono
          ;;
        esac
      ;;
    esac
  fi
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

if [ "${OPSYS}" != "cygwin" ] && [ "${OPSYS}" != "win32" ]; then
  if [ "${PMON_BATTERIES}" ] ; then
    setprompt new_pmon
  else
    setprompt
  fi
else
  setprompt new_nocount
fi

monolith_cleanup
