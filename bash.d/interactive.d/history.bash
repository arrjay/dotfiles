#!/usr/bin/env bash

# configure the shell history for interactive sessions.
HISTCONTROL=ignoreboth

# construct the most specific thing to ignore OTP keys in history
___mhex_otp_glob () {
  local c=44
  printf '%s' '*'
  while [ $c != 0 ] ; do
    printf '%s' '[b-l,n,r,t-v]'
    # shellcheck disable=SC2219
    let c=$c-1 || true
  done
  printf '%s' '*'
}
HISTIGNORE=$(___mhex_otp_glob)
unset -f ___mhex_otp_glob

# set up the rest of shell history
# we don't use genappend/prepend because those currently check for directoy existence
HISTIGNORE="${HISTIGNORE}"':pass *:ls:ll:l:pwd:uptime:history:history *:dmesg:s:sync:scx:cls:clear:*AWS_*_KEY*'
