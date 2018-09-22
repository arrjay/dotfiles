#!/usr/bin/env bash

set -ex

# adapted from https://github.com/robxu9/bash-static/
BASH_MIRROR="https://ftp.gnu.org/gnu/bash"

topdir="${PWD}"
workdir="$(mktemp -d)"
mkdir "${workdir}/"{build,dev,dl,gpg-keyring,root}
dldir="${DOWNLOAD_DIR:-${workdir}/dl}"
builddir="${BUILD_DIR:-${workdir}/build}"
devdir="${DEV_DIR:-${workdir}/dev}"

export GNUPGHOME="${workdir}/gpg-keyring"
for f in "${topdir}/.keys"/* ; do
  gpg2 --import "${f}"
done

dl_sha512_file () {
  local file url known_sha512 test_sha512
  url="${1}" ; file="${2}"
  [ -f "${dldir}/${file}" ] || curl -L -o "${dldir}/${file}" "${url}"
  test_sha512="$(sha512sum "${dldir}/${file}")"
  test_sha512="${test_sha512%% *}"
  read -r known_sha512 < "${topdir}/.signatures/${file}.sha512sum"
  [ "${known_sha512}" == "${test_sha512}" ]
}

dl_gpg_file () {
  local file url
  url="${1}" ; file="${2}"
  [ -f "${dldir}/${file}" ] || curl -L -o "${dldir}/${file}" "${url}"
  gpg2 --verify "${topdir}/.signatures/${file}" "${dldir}/${file}"
}

extract_l1_tarball () {
  local file ; file="${1}"
  tar xf "${dldir}/${file}" --strip-components=1 -C .
}

# musl-libc
[ -f "${devdir}/musl/bin/musl-gcc" ] || {
 dl_gpg_file "https://www.musl-libc.org/releases/musl-1.1.20.tar.gz" "musl.tgz"

 mkdir "${builddir}/musl" ; pushd "${builddir}/musl"
  extract_l1_tarball "musl.tgz"

  ./configure --prefix="${devdir}/musl"
  make -j 4
  make install
 popd
}

# bash - 2.05b
[ -f "${builddir}/bash-2.05b/bash" ] || {
 # no gpg sig here...
 dl_sha512_file "${BASH_MIRROR}/bash-2.05b.tar.gz" "bash-2.05b.tgz"

 # patches!
 # older patches have no gpg signature, use sha512
 for i in {1..7} ; do
   i="$(printf '%03d' $i)"
  dl_sha512_file "${BASH_MIRROR}/bash-2.05b-patches/bash205b-${i}" "bash-2.05b-patch-${i}"
 done

 # newer patches do have a gpg sig so switch to that
 for i in {8..13} ; do
   i="$(printf '%03d' $i)"
   dl_gpg_file "${BASH_MIRROR}/bash-2.05b-patches/bash205b-${i}" "bash-2.05b-patch-${i}"
 done

 mkdir "${builddir}/bash-2.05b" ; pushd "${builddir}/bash-2.05b"
  # unpack and patch
  extract_l1_tarball "bash-2.05b.tgz"
  for i in {1..13} ; do
   i="$(printf '%03d' $i)"
   patch -p0 < "${dldir}/bash-2.05b-patch-${i}"
  done

  # build
  export CC="${devdir}/musl/bin/musl-gcc"
  export CFLAGS="-static -Os"
  export LOCAL_CFLAGS="${CFLAGS}"
  ./configure --without-bash-malloc
  make
 popd
}

mkdir -p "${workdir}/Applications/bash-2.05b/bin"
cp "${builddir}/bash-2.05b/bash" "${workdir}/Applications/bash-2.05b/bin"

# bash - 3.0
[ -f "${builddir}/bash-3.0/bash" ] || {
 dl_gpg_file "${BASH_MIRROR}/bash-3.0.tar.gz" "bash-3.0.tgz"

 for i in {1..22} ; do
  i="$(printf '%03d' $i)"
  dl_gpg_file "${BASH_MIRROR}/bash-3.0-patches/bash30-${i}" "bash-30-patch-${i}"
 done

 mkdir "${builddir}/bash-3.0" ; pushd "${builddir}/bash-3.0"
  # unpack and patch
  extract_l1_tarball "bash-3.0.tgz"
  for i in {1..22} ; do
   i="$(printf '%03d' $i)"
   patch -p0 < "${dldir}/bash-30-patch-${i}"
  done

  # build
  export CC="${devdir}/musl/bin/musl-gcc"
  export CFLAGS="-static -Os"
  export LOCAL_CFLAGS="${CFLAGS}"
  ./configure --without-bash-malloc
  make
 popd
}

mkdir -p "${workdir}/Applications/bash-3.0/bin"
cp "${builddir}/bash-3.0/bash" "${workdir}/Applications/bash-3.0/bin"

# bash - 3.1
[ -f "${builddir}/bash-3.1/bash" ] || {
 dl_gpg_file "${BASH_MIRROR}/bash-3.1.tar.gz" "bash-3.1.tgz"

 for i in {1..23} ; do
  i="$(printf '%03d' $i)"
  dl_gpg_file "${BASH_MIRROR}/bash-3.1-patches/bash31-${i}" "bash-31-patch-${i}"
 done

 mkdir "${builddir}/bash-3.1" ; pushd "${builddir}/bash-3.1"
  # unpack and patch
  extract_l1_tarball "bash-3.1.tgz"
  for i in {1..23} ; do
   i="$(printf '%03d' $i)"
   patch -p0 < "${dldir}/bash-31-patch-${i}"
  done

  # build
  export CC="${devdir}/musl/bin/musl-gcc"
  export CFLAGS="-static -Os"
  export LOCAL_CFLAGS="${CFLAGS}"
  ./configure --without-bash-malloc
  make
 popd
}

mkdir -p "${workdir}/Applications/bash-3.1/bin"
cp "${builddir}/bash-3.1/bash" "${workdir}/Applications/bash-3.1/bin"

# bash - 3.2
[ -f "${builddir}/bash-3.2/bash" ] || {
 dl_gpg_file "${BASH_MIRROR}/bash-3.2.tar.gz" "bash-3.2.tgz"

 for i in {1..57} ; do
  i="$(printf '%03d' $i)"
  dl_gpg_file "${BASH_MIRROR}/bash-3.2-patches/bash32-${i}" "bash-32-patch-${i}"
 done

 mkdir "${builddir}/bash-3.2" ; pushd "${builddir}/bash-3.2"
  # unpack and patch
  extract_l1_tarball "bash-3.2.tgz"
  for i in {1..57} ; do
   i="$(printf '%03d' $i)"
   patch -p0 < "${dldir}/bash-32-patch-${i}"
  done

  # build
  export CC="${devdir}/musl/bin/musl-gcc"
  export CFLAGS="-static -Os"
  export LOCAL_CFLAGS="${CFLAGS}"
  ./configure --without-bash-malloc
  make
 popd
}

mkdir -p "${workdir}/Applications/bash-3.2/bin"
cp "${builddir}/bash-3.2/bash" "${workdir}/Applications/bash-3.2/bin"

# bash - 4.0

# bash - 4.1

# bash - 4.2

# bash - 4.3

# bash - 4.4

rm -rf "${workdir}"
