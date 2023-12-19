#!/usr/bin/env bash

# we are assuming bash 4, how else did you get flatpak?
[[ "${___bashmaj}" -ge 4 ]] || return 0

# prefer flatpak-wrapped components if we have them installed
____flatpak_setup () {
  local id alias
  local -a commands
  # Application ID - command name aliases
  # command name aliases is a : delimited stringy array
  local -A flatpaks
  flatpaks["com.visualstudio.code"]="code"
  flatpaks["com.google.Chrome"]="chrome"

  # do I have flatpak?
  chkcmd flatpak || return 0
  # loop through the app ids and override if we get one
  for id in "${!flatpaks[@]}" ; do
    flatpak info "${id}" > /dev/null 2>&1 && {
      IFS=: read -r -a commands <<<"${flatpaks[${id}]}"
      for alias in "${commands[@]}" ; do
        # I mean, we're our only input data, so this is the easiest to do.
        eval 'function '"${alias}"' { flatpak run '"${id}"' "${@}" ; }'
      done
    }
  done
}
____flatpak_setup
unset -f ____flatpak_setup