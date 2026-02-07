#!/usr/bin/env bash

chkcmd pass || return 0

[[ "${___bashmaj}${___bashmin:0:1}" -gt 31 ]] && ___sourcef "${___bashrc_dir}/vendor/pass-completion.sh"
