#!/usr/bin/env bash

# env set up in top-level bashrc
[[ "${___host}" ]] || ___host="undef"

___term_cset="${TERM_COLORSET:-}"
___term_titlecap="no"
___term_setcolor="no"

# helper functions to make ansi colors
# colorsets are: std, bold, ul, bg, hi, bhi, hibg
_get_ansicolor () {
  local color set ; color="${1}" ; set="${2:-${___term_cset}}"
  local r1 r2 # we need to return _two_ values to work around passing in PS1 shenanigans.
  [ -z "${color}" ] && { ___error_msg "${FUNCNAME[0]}: missing operand (needs: color: [rs,blk,red,grn.yel,blu,pur,cy,wh])" ; return 1; }
  # reset colorset to nothing if term cset is totally empty
  [ -z "${___term_cset}" ] && set=''
  case "${set}_${color}" in
    std_blk)  r1='0' r2='30'  ;;
    std_red)  r1='0' r2='31'  ;;
    std_grn)  r1='0' r2='32'  ;;
    std_yel)  r1='0' r2='33'  ;;
    std_blu)  r1='0' r2='34'  ;;
    std_pur)  r1='0' r2='35'  ;;
    std_cy)   r1='0' r2='36'  ;;
    std_wh)   r1='0' r2='37'  ;;
    bold_blk) r1='1' r2='30'  ;;
    bold_red) r1='1' r2='31'  ;;
    bold_grn) r1='1' r2='32'  ;;
    bold_yel) r1='1' r2='33'  ;;
    bold_blu) r1='1' r2='34'  ;;
    bold_pur) r1='1' r2='35'  ;;
    bold_cy)  r1='1' r2='36'  ;;
    bold_wh)  r1='1' r2='37'  ;;
    ul_blk)   r1='4' r2='30'  ;;
    ul_red)   r1='4' r2='31'  ;;
    ul_grn)   r1='4' r2='32'  ;;
    ul_yel)   r1='4' r2='33'  ;;
    ul_blu)   r1='4' r2='34'  ;;
    ul_pur)   r1='4' r2='35'  ;;
    ul_cy)    r1='4' r2='36'  ;;
    ul_wh)    r1='4' r2='37'  ;;
    bg_blk)   r1='40'    ;;
    bg_red)   r1='41'    ;;
    bg_grn)   r1='42'    ;;
    bg_yel)   r1='43'    ;;
    bg_blu)   r1='44'    ;;
    bg_pur)   r1='45'    ;;
    bg_cy)    r1='46'    ;;
    bg_wh)    r1='47'    ;;
    hi_blk)   r1='0' r2='90'  ;;
    hi_red)   r1='0' r2='91'  ;;
    hi_grn)   r1='0' r2='92'  ;;
    hi_yel)   r1='0' r2='93'  ;;
    hi_blu)   r1='0' r2='94'  ;;
    hi_pur)   r1='0' r2='95'  ;;
    hi_cy)    r1='0' r2='96'  ;;
    hi_wh)    r1='0' r2='97'  ;;
    bhi_blk)  r1='1' r2='90'  ;;
    bhi_red)  r1='1' r2='91'  ;;
    bhi_grn)  r1='1' r2='92'  ;;
    bhi_yel)  r1='1' r2='93'  ;;
    bhi_blu)  r1='1' r2='94'  ;;
    bhi_pur)  r1='1' r2='95'  ;;
    bhi_cy)   r1='1' r2='96'  ;;
    bhi_wh)   r1='1' r2='97'  ;;
    hibg_blk) r1='0' r2='100' ;;
    hibg_red) r1='0' r2='101' ;;
    hibg_grn) r1='0' r2='102' ;;
    hibg_yel) r1='0' r2='103' ;;
    hibg_blu) r1='0' r2='104' ;;
    hibg_pur) r1='0' r2='105' ;;
    hibg_cy)  r1='0' r2='106' ;;
    hibg_wh)  r1='0' r2='107' ;;
    *_rs)     r1='0'     ;;
    *) : ;; # no colorset == no colors
  esac
  # color as string
  printf '%s:%s' "${r1}" "${r2}"
}

_render_ansicolor () {
  # color as escaped
  _render_raw "$(_get_ansicolor "${@}")"
}

_render_raw () {
  # handed two parameters and do _something_
  local r1 r2
  IFS=: read -r r1 r2 <<< "${1}"
  [[ "${r2}" ]] && { printf '%b' "\e[${r1};${r2}m" ; return 0 ; }
  printf '%b' "\e[${r1}m"
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

# write a title to xterm or rxvt compatible titlebars
_wt () {
  [ "${___term_titlecap}" == "yes" ] && echo -ne '\e]0;'"${*}"'\a'
}

# standard prompt command - write the user@host:directory to window title
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

# I _really_ don't want to think about how this used $? too hard.
___prompt_colorerror () {
  local rc="${?:-0}"
  local string="${1:-?}"
  local color_success="${2:-}"
  local color_fail="${3:-}"
  local reset='0'
  case "${rc}" in
    0) _render_raw "${color_success}" ;;
    *) _render_raw "${color_fail}" ;;
  esac
  printf '%s' "${string}${rc}"
  _render_ansicolor "${reset}"
  printf '%s' ' '
}

_prompt_left () {
  rc="${?}" ; ___pre_prompt_rc="${rc}"
  [ "${___prompt_left_string}" ] && printf '%s' "${___prompt_left_string[*]}"
  return "${___pre_prompt_rc}"
}

# I'd really like this part to keep working under bash 2 so we're not gonna do any fancy datastructures.
# shellcheck disable=SC2154,SC2006,SC2016
setprompt () {
  local name prompt_scheme prompt_command_add ; name="${1:-new_pmon}" ; prompt_scheme="${2:-pride}" ; prompt_command_add='___pc_standard'
  [ -n "${PS1}" ] || return 0
  # hash_or dollar gets assigned a _character_ dynamically, so it gets initialized to exist here.
  local hash_or_dollar # generally prompt ending - hash (#) for root, otherwise dollar ($)
  local color_hash_or_dollar

  # all the rest of these should be just the color variables.
  local color_prompt_start # initial prompt commands (left side),

  # last_status is actually a command so we can recolorize if it failed.
  # that means we are supplying stringy colors, not rendered ones.
  local last_status='`___prompt_colorerror ?`' #NOTE: we added an ending quote so this is robust if edited.
  local color_last_status_success
  local color_last_status_failure

  local color_historynumber
  local color_user
  local color_atsign
  local color_host

  local color_batterystat
  local color_processcount
  local color_processcount_alt

  local color_workingdir
  local color_workingdir_alt

  local color_bracket_user
  local color_host_bracket
  # configure prompt colors - we need them before assemblig the prompt strings.
  local reset='\e[0m' # reset never changes with color sets
  case "${prompt_scheme}" in
    pride)
      color_hash_or_dollar=`_render_ansicolor cy`
      color_prompt_start=`_render_ansicolor cy`
      color_last_status_failure=`_get_ansicolor red bold`
      color_last_status_success=`_get_ansicolor cy`
      color_historynumber=`_render_ansicolor pur`
      color_user=`_render_ansicolor wh`
      color_atsign=`_render_ansicolor wh`
      color_host=`_render_ansicolor wh`
      color_workingdir=`_render_ansicolor pur`
      color_gitprompt=`_render_ansicolor pur bold`
    ;;
    basic)
      color_hash_or_dollar=`_render_ansicolor yel`
      color_prompt_start=`_render_ansicolor yel std`
      color_last_status_failure=`_get_ansicolor pur std`
      color_last_status_success="${color_last_status_failure}"
      color_historynumber=`_render_ansicolor grn std`
      color_user=`_render_ansicolor wh std`
      color_atsign=`_render_ansicolor grn std`
      color_host="${color_user}"
      color_processcount=`_render_ansicolor grn std`
      color_workingdir=`_render_ansicolor pur std`
      color_clock=`_render_ansicolor cy`
      color_batterystat="${color_processcount}"
      # used in the 'old' style prompt
      color_workingdir_alt=`_render_ansicolor grn`
      color_processcount_alt=`_render_ansicolor red std`
      color_bracket_user=`_render_ansicolor pur std`
      color_host_bracket="${color_bracket_user}"
    ;;
  esac

  # we replace the character string here and add color now
  case "${___rootusr}" in
    yes) hash_or_dollar="${color_hash_or_dollar}#${reset}"  ;;
    *)   hash_or_dollar="${color_hash_or_dollar}\$${reset}" ;;
  esac

  # assemble the rest of colorerror string - note that we chopped off, readded backtick
  last_status="${last_status::${#last_status}-1} ${color_last_status_success} ${color_last_status_failure}"'`'

  # render the other prompt parts - we use backticks to run programs because that's the most compatible ;)
  local prompt_start='`_prompt_left`'"${color_prompt_start}"'#'"${reset} "
  local historynumber="${color_historynumber}!"'\!'"${reset} "
  local prompt_user="${color_user}\\u${reset}"
  local atsign="${color_atsign}@${reset}"
  local prompt_host="${color_host}${___host}${reset}"
  local processcount="${color_processcount}"'`pscount`'"${reset} "
  local workingdir="${color_workingdir}{\\W}${reset}"
  local clock="${color_clock}("'\t'")${reset} "
  local batterystat="${color_batterystat}"'`_battstat prompt`'"${reset}"
  local prompt_end='`_prompt_right`'"${hash_or_dollar}"'\n'

  local workingdir_alt="${color_workingdir_alt}{\\W}${reset}"
  local processcount_alt="${color_processcount_alt}<"'`pscount`'">${reset} "
  local bracket_user="${color_bracket_user}[\\u${reset}"
  local host_bracket="${color_host_bracket}${___host}]${reset}"
  ___chkdef __git_ps1 && prompt_end="${color_gitprompt}"'`__git_ps1`'"${reset}"'`_prompt_right`'"${hash_or_dollar}"'\n'
  case "${name}" in
    # the classic prompt can leak in the hash_or_dollar color, but I think that's just funny.
    classic)     PS1="${reset}${___bash_invocation##*/}-${___bashmaj}.${___bashmin}${hash_or_dollar} " ;;
    old)         PS1="`_prompt_left`${clock}${bracket_user}${atsign}${host_bracket}"'`__git_ps1``_prompt_right`'"\\n${processcount_alt}${workingdir_alt} ${hash_or_dollar} " ;;
    timely)      PS1="${prompt_start}${clock}${last_status}${historynumber}${prompt_user}${atsign}${prompt_host} ${processcount}${workingdir}${prompt_end}" ;;
    new_nocount) PS1="${prompt_start}${last_status}${lsta}${historynumber}${prompt_user}${atsign}${prompt_host} ${workingdir}${prompt_end}" ;;
    new)         PS1="${prompt_start}${last_status}${historynumber}${prompt_user}${atsign}${prompt_host} ${processcount}${workingdir}${prompt_end}" ;;
    new_pmon)    PS1="${prompt_start}${last_status}${historynumber}${prompt_user}${atsign}${prompt_host} ${batterystat}${workingdir}${prompt_end}" ;;
  esac
  # only add pc_standard if we didn't have it already...
  case " ${___prompt_command_list[*]} " in
    *" ${prompt_command_add} "*) : ;;
    *) ___prompt_command_list=("${___prompt_command_list[@]}" "${prompt_command_add}")
  esac
}
setprompt "${name}"
