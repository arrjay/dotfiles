#!/usr/bin/env bash

# go unpacked in a separate go dist folder
[[ -f "${HOME}/Library/go-dist/bin/go" ]] && {
  export GOROOT="${HOME}/Library/go-dist"
}

# go maybe? unpacked in the build folder?
[[ -d "${HOME}/Library/go" ]] && {
  # found a compiler
  [[ -x "${HOME}/Library/go/bin/go" ]] && {
    [[ -n "${GOROOT:-}" ]] && \
     [[ "${GOROOT}" != "${HOME}/Library/go" ]] && \
       [[ "${PS1}" ]] && errmsg "WARNING: resetting GOROOT to ${HOME}/Library/go when GOROOT was already set."
    export GOROOT="${HOME}/Library/go"
  }
  # preferr building in the GOPATH so set that up
  genprepend GOPATH "${HOME}/Library/go"
}
