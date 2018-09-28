#!/usr/bin/env bash

pscount () {
  local psc psf
  [ -d /proc ] && {
    psf=( /proc/[0-9]* )
    # shellcheck disable=SC2219
    let psc="${#psf[@]}"-1
  }
  [ "${psc}" ] && printf '%s' "${psc}"
}
