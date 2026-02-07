#!/usr/bin/env bash

chkcmd pass || return 0

[[ "${___bashmaj}${___bashmin:0:1}" -gt 31 ]] && ___sourcef "${___bashrc_dir}/vendor/pass-completion.sh"

# make bootstrapping pass easier...
____pass_bootstrap () {
  local passdir
  # if we have gitsync, we already have Our Special Store, nope out
  passdir="${PASSWORD_STORE_DIR:-${HOME}/.password-store}"
  [[ -e "${passdir}/.extensions/gitsync.bash" ]] && return 0

  # OVERRIDE THE PASS COMMAND!
  pass () {
    errmsg "password store not initialized at start of session - shell function in play"
    local passdir
    passdir="${PASSWORD_STORE_DIR:-${HOME}/.password-store}"
    if [[ "${1}" == "gitsync" ]] ; then
      git clone ssh://pass/v1/repos/rj.produxi.net-pass "${passdir}" || return 1
      [[ -e "${passdir}/.metadata/public-keys.asc" ]] && {
        gpg --import "${passdir}/.metadata/public-keys.asc" || return 1
      }
      command pass git submodule update --init
      command pass git submodule foreach git checkout mainline
      unset -f pass
    else
      command pass "${@}"
    fi
  }
}

____pass_bootstrap
unset -f ____pass_bootstrap
