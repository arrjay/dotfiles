#!/usr/bin/env bash

# if we have an aws_completer, resolve and wire up complete now.
___aws_completer_init () {
  local awscomp
  chkcmd aws && chkcmd aws_completer && {
    awscomp="$(type aws_completer)"
    awscomp="${awscomp#* is }"
    complete -C "${awscomp}" aws
  }
  return 0
}
___aws_completer_init
unset -f ___aws_completer_init
