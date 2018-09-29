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
    while read line ; do
      case "${line}" in
        "FOO ()") which_func_support=true ;;
      esac
    done < <(printf 'FOO ()\n{\n    :\n}\n' | command which --read-functions FOO)
    while read line ; do
      case "${line}" in
        "alias FOO=':'") which_alias_support=true ;;
        *) echo "${line}" ;;
      esac
    done < <(printf "alias FOO=':'\n" | command which --read-alias FOO)
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
