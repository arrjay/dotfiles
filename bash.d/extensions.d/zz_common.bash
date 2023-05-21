#!/usr/bin/env bash

# placeholder if functions have _not_ been defined yet.
___chkdef _battstat || _battstat () {
  return 1
}

___chkdef pscount || pscount () {
  printf '%s' '-255'
}

# if we don't have an editor defined yet, try...something.

# convenience fuction to call the $EDITOR
# note that $EDITOR can have flags in it, so call that w/o quotes
_ed () {
  ${EDITOR} "${@}"
}

# test which by capabilities and define a function around it.
____init_which () {
  local line which_input which_flags
  which_input="" ; which_flags=""

  # check if we have which and if not, just go away
  { chkcmd which && {
    mm_setenv ___which_func_support || {
      ___which_func_support=false
      printf 'FOO ()\n{\n    :\n}\n' | command which --read-functions FOO > /dev/null 2>&1 && ___which_func_support=true
      mm_putenv ___which_func_support
    }
    mm_setenv ___which_alias_support || {
      ___which_alias_support=false
      while read -r line ; do
        case "${line}" in
          "alias FOO=':'") ___which_alias_support=true ;;
        esac
      done < <(exec 2>&1 ; printf "alias FOO=':'\\n" | command which --read-alias FOO)
      mm_putenv ___which_alias_support
    } ; }
  } || return 1

  [ "${___which_alias_support}" == true ] && {
    which_input="alias;" ; which_flags=("--read-alias")
  }
  [ "${___which_func_support}" == true ] && {
    which_input="${which_input}declare -f;" ; which_flags=("${which_flags[@]}" "--read-functions")
  }

  # use eval here to escape local context (by embedding it)
  [ "${which_input}" ] && eval "which () { command which ${which_flags[*]} \"\${@}\" < <(${which_input}) ; }"
}
____init_which
unset -f ____init_which

# ls capabilities and define functions around that.
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
  { mm_setenv ___ls_supports_human_readable && mm_setenv ___ls_supports_almost_all ; } || {
    ___ls_supports_human_readable=no
    ___ls_supports_almost_all=no
    [ "${___ls_supports_help}" == 'yes' ] && {
      # if ls supports --help, check for --color flag
      while read -r line ; do
        case "${line}" in
          *--almost-all*)     ___ls_supports_almost_all=yes     ;;
          *--human-readable*) ___ls_supports_human_readable=yes ;;
        esac
      done < <(ls --help 2>&1)
    }
    mm_putenv ___ls_supports_human_readable
    mm_putenv ___ls_supports_almost_all
  }
  # if we already have a function defined, assume it's our gnu wrapper...
  case "${___ls_supports_human_readable}" in
    yes)  ___ls_global_opts=("${___ls_global_opts[@]}" '--human-readable') ;;
  esac

  # if we don't have a wrapper, install that now
  # shellcheck disable=SC2006
  case `type -t ls` in
    file) ls () { command ls "${___ls_global_opts[@]}" "${@}" ; } ;;
  esac
}
____init_ls
unset -f ____init_ls

# add ll convenience helper. options are POSIX for -a, GNU for -A.
___chkdef ls && {
  case "${___ls_supports_almost_all}" in
    yes) ll () { ls -FlA "${@}" ; } ;;
    *)   ll () { ls -Fla "${@}" ; } ;;
  esac
}

# add l convenience.
___chkdef ls && l () { ls "${@}" ; }

# add s convenience.
___chkdef sync && s () { sync ; }

# I just seem to lag _slightly_ on unshift.
chkcmd grep && Grep () { command grep "${@}" ; }

# if we have 'cmdwatch' alias 'watch' on top of it. we usually want the procps-ng watch, not BSD.
chkcmd cmdwatch && watch () { command cmdwatch "${@}" ; }

# if I have tmux, actually prefer that for 'scx'
chkcmd screen && scx () { command screen -x ; }
chkcmd tmux   && scx () { command tmux attach ; }

# dos-like things
___chkdef path || path () { echo "${PATH}" ; }
chkcmd copy || { ___chkdef cp && copy () { cp "${@}" ; } ; }
chkcmd move || { ___chkdef mv && move () { mv "${@}" ; } ; }
chkcmd rd   || { ___chkdef rm && rd   () { rm -rf "${@}" ; } ; }
___chkdef mem  || { chkcmd free     && mem () { command free -m ; } ; }
___chkdef cls  || { ___chkdef clear && cls () { clear ; } ; }
chkcmd tracert || { chkcmd traceroute && tracert () { command traceroute "${@}" ; } ; }

# web browsing
chkcmd lynx      || { chkcmd elinks && lynx   () { command elinks "${@}" ; } ; }
___chkdef lynx   || { chkcmd links  && lynx   () { command links  "${@}" ; } ; }
chkcmd links     || { chkcmd elinks && links  () { command links  "${@}" ; } ; }
___chkdef links  || { chkcmd lynk   && links  () { command lynx   "${@}" ; } ; }
chkcmd elinks    || { chkcmd links  && elinks () { command links  "${@}" ; } ; }
___chkdef elinks || { chkcmd lynx   && elinks () { command lynx   "${@}" ; } ; }

# media playback
chkcmd mpg123    || { chkcmd mpg321  && mpg123 () { command mpg321  "${@}" ; } ; }
___chkdef mpg123 || { chkcmd mplayer && mpg123 () { command mplayer "${@}" ; } ; }
chkcmd mpg321    || { chkcmd mpg123  && mpg321 () { command mpg123  "${@}" ; } ; }
___chkdef mpg321 || { chkcmd mplayer && mpg321 () { command mplayer "${@}" ; } ; }

# docker convenience functions
chkcmd docker && {
  __docker_sh () {
    # run bash in a docker container, overriding entrypoint. optionally, mount some volumes, too.
    local opt volume image OPTARG OPTIND xauthority dt env xsockdir rc
    volume=() ; env=() ; xauthority="" ; image="" ; xsockdir=""
    while getopts "v:xi:" opt "${@}" ; do case "${opt}" in
      i) image="${OPTARG}" ;;
      v) volume=("${volume[@]}" '-v' "${OPTARG}") ;;
      x)
         xauthority=$(__docker_xauth) || { ___error_msg "unable to manipulate X security settings" ; return 1 ; }
         chkcmd socat || { ___error_msg "socat needed for X11 socket handling" ; return 1 ; }
         xsockdir=$(mktemp -d) || { ___error_msg "unable to create container transient X socket dir"  ; return 1 ; }
         chcon -t sandbox_file_t "${xsockdir}"
         dt=${DISPLAY/:/} ; dt=${dt%.*}
         case "${DISPLAY}" in
           # local X
           :*) [ -e "/tmp/.X11-unix/X${dt}" ] && {
             # this works via the socat-x.te file also in the dotfiles repo :/ install if needed doing this:
             # checkmodule -M -m -o socat-x.mod socat-x.te && semodule_package -o socat-x.pp -m socat-x.mod
             # sudo semodule -i socat-x.pp
             ( env LD_LIBRARY_PATH='' runcon -t sandbox_x_t socat "UNIX-LISTEN:${xsockdir}/X0,fork" "UNIX:/tmp/.X11-unix/X${dt}" & )
             volume=("${volume[@]}" '-v' "${xsockdir}/X0:/tmp/.X11-unix/X0:Z") ; } ;;
         esac
         volume=("${volume[@]}" '-v' "${xauthority}:/.Xauthority:Z")
         env=("${env[@]}" '--env' 'XAUTHORITY=/.Xauthority')
         env=("${env[@]}" '--env' 'DISPLAY=:0')
      ;;
      *) ___error_msg "${BASH_FUNCTION[0]} [-i][-v][-x]" ; return 2 ;;
    esac ; done
    shift $((OPTIND-1))
    command docker run --rm=true -it "${env[@]}" "${volume[@]}" --entrypoint bash "${image}" -i ; rc=$?
    [ -e "${xauthority}" ] && rm "${xauthority}"
    [ -e "${xsockdir}" ] && { fuser -k "${xsockdir}/X0" 2>/dev/null 1>&2 ; rm -rf "${xsockdir}" ; }
    return "${rc}"
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
