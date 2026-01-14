#!/usr/bin/env bash

mm_setenv SystemDrive || {
  [[ "${SYSTEMDRIVE}" ]] && {
    { chkcmd cygpath && SystemDrive="$(cygpath "${SYSTEMDRIVE}")" ; } || SystemDrive="${SYSTEMDRIVE}"
    mm_putenv SystemDrive
  }
}
