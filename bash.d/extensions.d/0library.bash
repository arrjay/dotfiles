#!/usr/bin/env bash

# configure library paths
# check if set - if not, try loading from the cache directory
# ...should we have a .config directory?
[[ "${NO_LDPATH_EXTENSION:-}" ]] || mm_setenv NO_LDPATH_EXTENSION
[[ -z "${NO_LDPATH_EXTENSION:-}" ]] && {
  genappend LD_LIBRARY_PATH "${HOME%/}/Library"/*/lib
  cke LD_LIBRARY_PATH
}
