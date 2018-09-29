#!/usr/bin/env bash

# we treat android as a superset/degenerate of linux, so go run that first. if we can.
sourcex ./linux.bash

# however, I'm not trying to support bash 2.x here so...that's something?
# in fact, the coproc here requires bash 4.0 or newer.

# if we have the pieces to run termux-api for battery status, do so.
chkcmd termux-battery-status && chkcmd jq && chkcmd flock && chkcmd sh && _battstat () {
  # and as you _should_ question - what?
  # termux-battery-status is actually VERY VERY slow.
  # so wrap it in flock, and mv, and cache that shit.
  # we simply ask for an update when we run the command, and carry on.
  # shellcheck disable=SC2086,SC2016
  coproc flock -w 2 -xn $HOME/.termux-battery-status-lock sh -c 'termux-battery-status > $HOME/.termux-battery-status.new && mv $HOME/.termux-battery-status.new $HOME/.termux-battery-status'
  local cmd pct sta plg ind
  cmd="${1}" ; ind='-'
  # preload jq, and we do want this split into three words tyvm
  # shellcheck disable=SC2046
  read -r pct sta plg <<<$(jq -r '. | "\(.percentage) \(.status) \(.plugged)"' "${HOME}/.termux-battery-status")
  case "${cmd}" in
    cap)         printf '%s\n' '100' ; return 0 ;;	# termux will always scale here
    chrg|chgpct) [ "${pct}" ] && printf '%s\n' "${pct}" ; return 0 ;;
    stat|prompt)
      case "${sta}${plg}" in
        NOT_CHARGINGUNPLUGGED) ind='v' ;;
        CHARGING*)             ind='^' ;;
      esac
      case "${cmd}" in
        stat)   printf '%s\n' "${ind}" ; return 0 ;;
        prompt) [ "${pct}" ] && printf '(%s%%%s) ' "${pct}" "${ind}" ; return 0 ;; 
      esac
    ;;
    *) ___error_msg "${FUNCNAME[0]}: cap|chrg|chgpct|stat|prompt" ; return 1 ;;
  esac
}
