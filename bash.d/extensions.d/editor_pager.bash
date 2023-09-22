#!/usr/bin/env bash

# (re)-configure EDITOR / PAGER dependent on programs installed.

# if I have vim, alias vi to it
chkcmd vim && vi () { command vim "${@}" ; }

# check if we already have EDITOR defined to vim or...editplus ;)
case "${EDITOR}" in
  *vim*|*editplus*) : ;;
  *)
    # well...let's try vi first.
    chkcmd vi  && export EDITOR='vi'
    chkcmd vim && export EDITOR='vim'
    [ "${___x11_environment:-}" == 'yes' ] && {
      chkcmd gvim && export EDITOR='gvim -f'
    }
  ;;
esac

# configure a pager, more or less
chkcmd more && export PAGER='more'
chkcmd less && export PAGER='less'
