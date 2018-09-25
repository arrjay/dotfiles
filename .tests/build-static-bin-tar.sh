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
rootdir="${ROOT_IMPORT_DIR:-${workdir}/root}"

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

build_bash () {
  local version patchver i s
  version="${1}" ; patchver="${2}"
  ndot_ver="${version/.}"

  [ -f "${builddir}/bash-${version}/bash" ] || {
    dl_gpg_file "${BASH_MIRROR}/bash-${version}.tar.gz" "bash-${version}.tgz"

    for ((i=1 ; i<=${patchver} ; ++i)) ; do
      s="$(printf '%03d' $i)"
      dl_gpg_file "${BASH_MIRROR}/bash-${version}-patches/bash${ndot_ver}-${s}" "bash-${ndot_ver}-patch-${s}"
    done

    rm -rf "${builddir}/bash-${version}" ; mkdir -p "${builddir}/bash-${version}" ; pushd "${builddir}/bash-${version}"
      # unpack and patch
      extract_l1_tarball "bash-${version}.tgz"
      for ((i=1 ; i<=${patchver} ; ++i)) ; do
        s="$(printf '%03d' $i)"
        patch -p0 < "${dldir}/bash-${ndot_ver}-patch-${s}"
      done

      # build
      export CC="${devdir}/musl/bin/musl-gcc"
      export CFLAGS="-static -Os"
      export LOCAL_CFLAGS="${CFLAGS}"
      ./configure --without-bash-malloc
      make
    popd
  }

  mkdir -p "${rootdir}/Applications/bash-${version}/bin"
  cp "${builddir}/bash-${version}/bash" "${rootdir}/Applications/bash-${version}/bin"
}


# musl-libc
[ -f "${devdir}/musl/bin/musl-gcc" ] || {
 dl_gpg_file "https://www.musl-libc.org/releases/musl-1.1.20.tar.gz" "musl.tgz"

 rm -rf "${builddir}/musl" ; mkdir "${builddir}/musl" ; pushd "${builddir}/musl"
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

 rm -rf "${builddir}/bash-2.05b" ; mkdir "${builddir}/bash-2.05b" ; pushd "${builddir}/bash-2.05b"
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

mkdir -p "${rootdir}/Applications/bash-2.05b/bin"
cp "${builddir}/bash-2.05b/bash" "${rootdir}/Applications/bash-2.05b/bin"

# bash - 3.0
build_bash 3.0 22

# bash - 3.1
build_bash 3.1 23

# bash - 3.2
build_bash 3.2 57

# bash - 4.0
build_bash 4.0 44

# bash - 4.1
build_bash 4.1 17

# bash - 4.2
build_bash 4.2 53

# bash - 4.3
build_bash 4.3 48

# bash - 4.4
build_bash 4.4 23

# twiddle permissions, make tarball
pushd "${rootdir}"
find ./ -type d -exec chmod a+rx {} \;
find ./Applications/*/bin -type f -exec chmod a+rx {} \;
tar cf "${topdir}/import.tar" --owner=0 --group=0 .
popd

rm -rf "${workdir}"
