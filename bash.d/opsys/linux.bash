#!/usr/bin/env bash

pscount () {
  local psc psf
  [ -d /proc ] && {
    psf=( /proc/[0-9]* )
    # shellcheck disable=SC2219
    let psc="${#psf[@]}"-1
  }
  [ "${psc}" ] && printf '%s' "${psc}"
}

____init_battstat () {
  local bfiles f p bpres
  bpres=()
  bfiles=(/sys/class/power_supply/BAT*/present
          /sys/class/power_supply/CMB*/present
          /sys/class/power_supply/battery/present)
  for f in "${bfiles[@]}" ; do
    [ -f "${f}" ] && read -r p < "${f}"
    [ "${p:-}" == 1 ] && bpres=("${bpres[@]}" "${f%/present}")
  done
  [ "${#bpres[@]}" != 0 ] && {
    _battstat () {
      local batts cmd res b c w
      res=0
      batts=("${bfiles[@]}")
      cmd="${1}"
      case "${cmd}" in
        cap)
          for b in "${batts[@]}" ; do
            for w in energy_full charge_full ; do
              [ -f "${b}/${w}" ] && read -r c < "${b}/${w}"
              [ -f "${b}/${w}" ] && read -r c < "${b}/${w}"
            done
            # shellcheck disable=SC2219
            let res=res+c
          done
          printf '%s\n' "${res}" ; return 0
        ;;
        chrg)
          for b in "${batts[@]}" ; do
            for w in energy_now charge_now ; do
              [ -f "${b}/${w}" ] && read -r c < "${b}/${w}"
              [ -f "${b}/${w}" ] && read -r c < "${b}/${w}"
            done
            # shellcheck disable=SC2219
            let res=res+c
          done
          printf '%s\n' "${res}" ; return 0
        ;;
        chgpct)
          :
        ;;
        stat)
          res='-'
          for b in "${batts[@]}" ; do
            read -r c < "${b}/status"
            case "${res}${c}" in
              -Charging)    res='^' ;;
              -Discharging) res='v' ;;
            esac
          done
          printf '%s\n' "${res}" ; return 0
        ;;
        *)
          ___error_msg "${FUNCNAME[0]}: cap|chrg|chgpct|stat|prompt" ; return 1
        ;;
      esac
    }
  }
  return 0
}
____init_battstat
unset -f ____init_battstat
