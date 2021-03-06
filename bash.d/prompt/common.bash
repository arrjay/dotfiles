#!/usr/bin/env bash

___term_cset="${TERM_COLORSET:-}"
___term_titlecap="no"
___term_setcolor="no"

# helper function to make ansi colors
# colorsets are: std, bold, ul, bg, hi, bhi, hibg
_ac () {
  local color str set ; color="${1}" ; set="${2:-${___term_cset}}"
  [ -z "${color}" ] && { ___error_msg "${FUNCNAME[0]}: missing operand (needs: color: [rs,blk,red,grn.yel,blu,pur,cy,wh])" ; return 1; }
  # reset colorset to nothing if term cset is totally empty
  [ -z "${___term_cset}" ] && set=''
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

# walk through all the prompt command hooks...
___prompt_command () {
  local function
  [ "${___prompt_command_list[0]}" ] || return 0
  for function in "${___prompt_command_list[@]}" ; do
    ${function}
  done
}
PROMPT_COMMAND='___prompt_command'

# write a title to xterm or rxvt compate titlebars
_wt () {
  [ "${___term_titlecap}" == "yes" ] && echo -ne '\e]0;'"${*}"'\a'
}

# standard prompt command
___pc_standard () {
  _wt "${USER}@${___host}:${PWD}"
}

# set full fg/bg colors - this takes xparsecolor(3) format - rgb:hh/hh/hh is encouraged.
# channels are: fg bg cu hi
_sc () {
  local channel color
  channel="${1}" ; color="${2}"
  { [ "${channel}" ] && [ "${color}" ] ; } || { ___error_msg "${FUNCNAME[0]}: missing operands (needs: channel[fg,bg,cu,hi], color[xparsecolor])" ; return 1 ; }
  [ "${___term_setcolor}" == "yes" ] || return 0
  case "${channel}" in
    fg) str='\e]10' ;;
    bg) str='\e]11' ;;
    cu) str='\e]12' ;;
    hi) str='\e]17' ;;
    *) ___error_msg "${FUNCNAME[0]}: channel ${channel} invalid - pick [fg,bg,cu,hi]" ; return 1 ; ;;
  esac
  str="${str}${color}"'\a'
  printf %b "${str}"
}

# configure terminal capabilities from what we have
____termsetup () {
  case "${TERM}" in
    cygwin*)      ___term_titlecap='yes' ; ___term_setcolor='no'  ; ___term_cset="${TERM_COLORSET:-bright}" ;;
    xterm*|rxvt*) ___term_titlecap='yes' ; ___term_setcolor='yes' ; ___term_cset="${TERM_COLORSET:-bold}"   ;;
    putty*)       ___term_titlecap='yes' ; ___term_setcolor='yes' ; ___term_cset="${TERM_COLORSET:-bold}"   ;;
    linux*|ansi*) ___term_titlecap='no'  ; ___term_setcolor='no'  ; ___term_cset="${TERM_COLORSET:-bright}" ;;
    screen*)      ___term_titlecap='yes' ; ___term_setcolor='yes' ; ___term_cset="${TERM_COLORSET:-bold}"   ;;
  esac
}

[[ -n "${PS1}" ]] && ____termsetup
unset -f ____termsetup

# placeholder functions for the prompt
# if you redefine these, you need to pass along the previous rc
___pre_prompt_rc=0
___chkdef _prompt_right || _prompt_right () {
  printf '%s' ' '
  return "${___pre_prompt_rc}"
}

_prompt_left () {
  rc="${?}" ; ___pre_prompt_rc="${rc}"
  [ "${___prompt_left_string}" ] && printf '%s' "${___prompt_left_string[*]}"
  return "${___pre_prompt_rc}"
}

# shellcheck disable=SC2154,SC2006,SC2016
setprompt () {
  local name prompt_scheme prompt_command_add ; name="${1:-}" ; prompt_scheme="${2:-basic}" ; prompt_command_add='___pc_standard'
  [ -n "${PS1}" ] || return 0
  PS1="${___bash_invocation}-${___bashmaj}.${___bashmin}${hd} "
  local hd np_start lsta chn u at h pc wd clk pca wda ha ua pm
  local rs c_hd c_np_start c_lsta c_chn c_u c_at c_h c_pc c_wd c_clk c_pca c_wda c_ha c_ua c_pm
  rs=`_ac rs`
  case "${prompt_scheme}" in
    basic|*)
      c_hd=`_ac yel`
      c_np_start=`_ac yel std`
      c_lsta=`_ac pur std`
      c_chn=`_ac grn std`
      c_u=`_ac wh std`
      c_at=`_ac grn std`
      c_h="${c_u}"
      c_pc=`_ac grn std`
      c_wd=`_ac pur std`
      c_clk=`_ac cy`
      c_pca=`_ac red std`
      c_wda=`_ac grn`
      c_ha=`_ac pur std`
      c_ua="${c_ha}"
      c_pm="${c_pc}"
    ;;
  esac
  case "${___rootusr}" in
    yes) hd="${c_hd}#${rs}"  ;;
    *)   hd="${c_hd}\$${rs}" ;;
  esac
  np_start='`_prompt_left`'"${c_np_start}"'#'"${rs} "
  lsta="${c_lsta}?"'${?}'"${rs} "
  chn="${c_chn}!"'\!'"${rs} "
  u="${c_u}\\u${rs}"
  ua="${c_ua}[\\u${rs}"
  at="${c_at}@${rs}"
  h="${c_h}${___host}${rs}"
  ha="${c_ha}${___host}]${rs}"
  pc="${c_pc}"'`pscount`'"${rs} "
  pca="${c_pca}<"'`pscount`'">${rs} "
  wd="${c_wd}{\\W}${rs}"
  wda="${c_wda}{\\W}${rs}"
  clk="${c_clk}("'\t'")${rs} "
  pm="${c_pm}"'`_battstat prompt`'"${rs}"
  np_end='`_prompt_right`'"${hd}"'\n'
  ___chkdef __git_ps1 && np_end='`__git_ps1``_prompt_right`'"${hd}"'\n'
  case "${name}" in
    simple)      prompt_command_add='' ;;
    classic)     : ;;
    old)         PS1="`_prompt_left`${clk}${ua}${at}${ha}"'`__git_ps1``_prompt_right`'"\\n${pca}${wda} ${hd} " ;;
    timely)      PS1="${np_start}${clk}${lsta}${chn}${u}${at}${h} ${pc}${wd}${np_end}" ;;
    new_nocount) PS1="${np_start}${lsta}${chn}${u}${at}${h} ${wd}${np_end}" ;;
    new)         PS1="${np_start}${lsta}${chn}${u}${at}${h} ${pc}${wd}${np_end}" ;;
    new_pmon)    PS1="${np_start}${lsta}${chn}${u}${at}${h} ${pm}${wd}${np_end}" ;;
  esac
  ___prompt_command_list=("${___prompt_command_list[@]}" "${prompt_command_add}")
}
setprompt new_pmon
