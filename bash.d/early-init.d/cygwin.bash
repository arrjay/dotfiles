#!/usr/bin/env bash

# convenient references to windows system bits in mixed-case (like you're used to in cmd)
mm_setenv SystemDrive || {
  [[ "${SYSTEMDRIVE}" ]] && {
    { chkcmd cygpath && SystemDrive="$(cygpath "${SYSTEMDRIVE}")" ; } || SystemDrive="${SYSTEMDRIVE}"
    mm_putenv SystemDrive
  }
}

# shellcheck disable=SC2034
mm_setenv SystemRoot || {
  [[ "${SYSTEMROOT}" ]] && {
    { chkcmd cygpath && SystemRoot="$(cygpath "${SYSTEMROOT}")" ; } || SystemRoot="${SYSTEMROOT}"
    mm_putenv SystemRoot
  }
}

mm_setenv ProgramFiles || {
  [[ "${PROGRAMFILES}" ]] && {
    { chkcmd cygpath && ProgramFiles="$(cygpath "${PROGRAMFILES}")" ; } || ProgramFiles="${PROGRAMFILES}"
    mm_putenv ProgramFiles
  }
}

mm_setenv ProgramFilesX86 || {
  # cygwin 1.5 (at least) could not support -F
  { chkcmd cygpath && ProgramFilesX86="$(cygpath -F 0x2a 2>/dev/null)" ; } || ProgramFilesX86="${ProgramFiles} (x86)"
  # could be on a 32-bit system ;)
  [[ -d "${ProgramFilesX86}" ]] || ProgramFilesX86=''
  mm_putenv ProgramFilesX86
}

# more PATH niceties
genappend PATH "${SystemDrive}/bin"

# GPG binaries - prefer GnuPG over Gpg4win (remember this is prepending)
[[ "${ProgramFilesX86}" != "" ]] && genprepend PATH "${ProgramFilesX86}/Gpg4win/bin"
genprepend PATH "${ProgramFiles}/Gpg4win/bin"
[[ "${ProgramFilesX86}" != "" ]] && genprepend PATH "${ProgramFilesX86}/GnuPG/bin"
genprepend PATH "${ProgramFiles}/GnuPG/bin"

# if HOME and USERPROFILE are different places, append USERPROFILE/Applications
[[ "${USERPROFILE}" ]] && [[ "${USERPROFILE}" != "${HOME}" ]] && {
  genappend PATH "${USERPROFILE}/Applications"/*/bin
}

# shellcheck disable=SC2164
cdw () {
  cd "${USERPROFILE}"
}
