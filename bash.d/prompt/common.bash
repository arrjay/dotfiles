#!/usr/bin/env bash

___term_cset="${TERM_COLORSET:-}"

# helper function to make ansi colors
# colorsets are: std, bold, ul, bg, hi, bhi, hibg
_ac () {
  local color str set ; color="${1}" ; set="${2:-${___term_cset}}"
  [ -z "${color}" ] && { ___error_msg "${FUNCNAME[0]}: missing operand (needs: color: [rs,blk,red,grn.yel,blu,pur,cy,wh])" ; return 1; }
  case "${set}_${color}" in
    std_blk)  str='\e[0;30m'  ;;
    std_red)  str='\e[0;31m'  ;;
    std_grn)  str='\e[0;32m'  ;;
    std_yel)  str='\e[0;33m'  ;;
    std_blu)  str='\e[0;34m'  ;;
    std_pur)  str='\e[0;35m'  ;;
    std_cy)   str='\e[0;36m'  ;;
    std_wh)   str='\e[0;37m'  ;;
    bold_blk) str='\e[1;30m'  ;;
    bold_red) str='\e[1;31m'  ;;
    bold_grn) str='\e[1;32m'  ;;
    bold_yel) str='\e[1;33m'  ;;
    bold_blu) str='\e[1;34m'  ;;
    bold_pur) str='\e[1;35m'  ;;
    bold_cy)  str='\e[1;36m'  ;;
    bold_wh)  str='\e[1;37m'  ;;
    ul_blk)   str='\e[4;30m'  ;;
    ul_red)   str='\e[4;31m'  ;;
    ul_grn)   str='\e[4;32m'  ;;
    ul_yel)   str='\e[4;33m'  ;;
    ul_blu)   str='\e[4;34m'  ;;
    ul_pur)   str='\e[4;35m'  ;;
    ul_cy)    str='\e[4;36m'  ;;
    ul_wh)    str='\e[4;37m'  ;;
    bg_blk)   str='\e[40m'    ;;
    bg_red)   str='\e[41m'    ;;
    bg_grn)   str='\e[42m'    ;;
    bg_yel)   str='\e[43m'    ;;
    bg_blu)   str='\e[44m'    ;;
    bg_pur)   str='\e[45m'    ;;
    bg_cy)    str='\e[46m'    ;;
    bg_wh)    str='\e[47m'    ;;
    hi_blk)   str='\e[0;90m'  ;;
    hi_red)   str='\e[0;91m'  ;;
    hi_grn)   str='\e[0;92m'  ;;
    hi_yel)   str='\e[0;93m'  ;;
    hi_blu)   str='\e[0;94m'  ;;
    hi_pur)   str='\e[0;95m'  ;;
    hi_cy)    str='\e[0;96m'  ;;
    hi_wh)    str='\e[0;97m'  ;;
    bhi_blk)  str='\e[1;90m'  ;;
    bhi_red)  str='\e[1;91m'  ;;
    bhi_grn)  str='\e[1;92m'  ;;
    bhi_yel)  str='\e[1;93m'  ;;
    bhi_blu)  str='\e[1;94m'  ;;
    bhi_pur)  str='\e[1;95m'  ;;
    bhi_cy)   str='\e[1;96m'  ;;
    bhi_wh)   str='\e[1;97m'  ;;
    hibg_blk) str='\e[0;100m' ;;
    hibg_red) str='\e[0;101m' ;;
    hibg_grn) str='\e[0;102m' ;;
    hibg_yel) str='\e[0;103m' ;;
    hibg_blu) str='\e[0;104m' ;;
    hibg_pur) str='\e[0;105m' ;;
    hibg_cy)  str='\e[0;106m' ;;
    hibg_wh)  str='\e[0;107m' ;;
    *_rs)     str='\e[0m'     ;;
    *) : ;; # no colorset == no colors
  esac
  [ "${str}" ] && printf %b "${str}"
}
