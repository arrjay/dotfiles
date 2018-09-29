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

___sysfs_batt=()
____init_battstat () {
  local bfiles f p bpres
  bpres=()
  bfiles=(/sys/class/power_supply/BAT*/present
          /sys/class/power_supply/CMB*/present
          /sys/class/power_supply/battery/present)
  for f in "${bfiles[@]}" ; do
    p=0
    [ -f "${f}" ] && read -r p < "${f}"
    [ "${p:-}" == 1 ] && ___sysfs_batt=("${___sysfs_batt[@]}" "${f%/present}")
  done
  [ "${#___sysfs_batt[@]}" != 0 ] && {
    _battstat () {
      local cmd res b c w
      res=0
      cmd="${1}"
      case "${cmd}" in
        cap)
          for b in "${___sysfs_batt[@]}" ; do
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
          for b in "${___sysfs_batt[@]}" ; do
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
          let res=`_battstat chrg`00/`_battstat cap`
          printf '%s\n' "${res}" ; return 0
        ;;
        stat)
          res='-'
          for b in "${___sysfs_batt[@]}" ; do
            read -r c < "${b}/status"
            case "${res}${c}" in
              -Charging)    res='^' ;;
              -Discharging) res='v' ;;
            esac
          done
          printf '%s\n' "${res}" ; return 0
        ;;
        prompt)
          printf '%s%%%s' "`_battstat chgpct`" "`_battstat stat`" ; return 0
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
