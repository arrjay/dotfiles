#!/usr/bin/env bash

# if we have mise, actually prefer *that*... in shim mode....
type mise >/dev/null 2>&1 && eval "$(mise activate --shims)"
