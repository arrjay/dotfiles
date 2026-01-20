#!/usr/bin/env bash

[[ -d "${HOME}/Library/perl5" ]] && {
  export PERL_MB_OPT="--install_base ${HOME}/Library/perl5"
  export PERL_MM_OPT="INSTALL_BASE=${HOME}/Library/perl5"
  export PERL_LOCAL_LIB_ROOT="${HOME}/Library/perl5"
  genappend PERL5LIB \
    "${HOME}/Library/perl5" \
    "${HOME}/Library/perl5/lib/perl5" \
    "${HOME}/Library/perl5/lib/perl5/${___cpu}-${___os}-gnu-thread-multi"
}
