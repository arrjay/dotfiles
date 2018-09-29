#!/usr/bin/env bash

# placeholder
___chkdef _battstat || _battstat () {
  return 1
}

___chkdef pscount || pscount () {
  printf '%s' '-255'
}

# test which by capabilities and define a function around it.
____init_which () {
  local line which_func_support which_alias_support which_input which_flags
  which_alias_support=false ; which_func_support=true
  which_input="" ; which_flags=""

  # check if we have which and if not, just go away
  { chkcmd which && {
    while read -r line ; do
      case "${line}" in
        "FOO ()") which_func_support=true ;;
      esac
    done < <(printf 'FOO ()\n{\n    :\n}\n' | command which --read-functions FOO)
    while read -r line ; do
      case "${line}" in
        "alias FOO=':'") which_alias_support=true ;;
        *) echo "${line}" ;;
      esac
    done < <(printf "alias FOO=':'\\n" | command which --read-alias FOO)
  } ; } || return 1

  [ "${which_alias_support}" == true ] && {
    which_input="alias;" ; which_flags=("--read-alias")
  }
  [ "${which_func_support}" == true ] && {
    which_input="${which_input}declare -f;" ; which_flags=("${which_flags[@]}" "--read-functions")
  }

  # use eval here to escape local context (by embedding it)
  eval "which () { command which ${which_flags[*]} \"\${@}\" < <(${which_input}) ; }"
}
____init_which
unset -f ____init_which

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
