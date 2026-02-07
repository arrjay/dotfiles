#!/usr/bin/env bash

# prefer ncfp for interactive use
chkcmd ncftp && ftp () { command ncftp "${@}" ; }
