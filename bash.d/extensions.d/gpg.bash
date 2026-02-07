#!/usr/bin/env bash

chkcmd gpg2 && gpg () { command gpg2 "${@}" ; }
