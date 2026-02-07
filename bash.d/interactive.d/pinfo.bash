#!/usr/bin/env bash

# if we have pinfo, prefer that to man
chkcmd pinfo && man() { command pinfo -m "${@}" ; }
