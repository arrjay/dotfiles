#!/usr/bin/env bash

___init_hb () {
  local brew
  for brew in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew ; do
    [[ -x "${brew}" ]] && {
      eval "$("${brew}" shellenv)"
      return 0
    }
  done
}

___init_hb
unset -f ___init_hb
