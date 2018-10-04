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
  strip "${rootdir}/Applications/bash-${version}/bin/bash"
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

[ -f "${devdir}/musl/bin/musl-ar" ] || {
  ln -s "$(which ar)" "${devdir}/musl/bin/musl-ar"
}

[ -f "${devdir}/musl/bin/musl-strip" ] || {
  ln -s "$(which strip)" "${devdir}/musl/bin/musl-strip"
}

mkdir -p "${devdir}/musl/include"

for d in linux asm asm-generic mtd ; do
  [ -e "${devdir}/musl/include/${d}" ] || {
    ln -s "/usr/include/${d}" "${devdir}/musl/include/${d}"
  }
done

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
strip "${rootdir}/Applications/bash-2.05b/bin/bash"

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

# busybox
[ -f "${builddir}/busybox/busybox" ] || {
 dl_gpg_file "https://busybox.net/downloads/busybox-1.29.3.tar.bz2" "busybox.tbz"

 rm -rf "${builddir}/busybox" ; mkdir "${builddir}/busybox" ; pushd "${builddir}/busybox"
  # unpack and patch
  extract_l1_tarball "busybox.tbz"

  # build
  export CC="${devdir}/musl/bin/musl-gcc"
  export CFLAGS="-static -Os"
  export LOCAL_CFLAGS="${CFLAGS}"
  cp "${topdir}/.tests/busybox.config" .config
  make silentoldconfig
  PATH="${devdir}/musl/bin:${PATH}" make
 popd
}

mkdir -p "${rootdir}/Applications/busybox/bin"
cp "${builddir}/busybox/busybox" "${rootdir}/Applications/busybox/bin"

# we should be able to just run busybox _now_ and ask it what to link ;)
while read cmdlet ; do
  ln -s "/Applications/busybox/bin/busybox" "${rootdir}/Applications/busybox/bin/${cmdlet}"
done < <("${rootdir}/Applications/busybox/bin/busybox" --list)

# rust uutils (coreutils) static build needs rustup...
[ -f "${builddir}/uutils/target/x86_64-unknown-linux-musl/release/uutils" ] || {
  rustup target add x86_64-unknown-linux-musl
  rm -rf "${builddir}/uutils"
  git clone https://github.com/uutils/coreutils "${builddir}/uutils"
  pushd "${builddir}/uutils"
    # build the list of features by seeing what sourcedirs exist
    cd src ; features=(*) ; cd ..
    features=("${features[@]/uucore}")
    # the below features require utmpx, which musl doesn't give here.
    features=("${features[@]/uutils}")
    features=("${features[@]/pinky}")
    features=("${features[@]/uptime}")
    features=("${features[@]/users}")
    # hack due to the way bash handles array deletions - delete masked match, readd it.
    features=("${features[@]/whoami}")
    features=("${features[@]/who}")
    features+=("whoami")
    cargo build --release --target=x86_64-unknown-linux-musl --no-default-features --features "${features[*]}"
  popd
}

mkdir -p "${rootdir}/Applications/uutils/bin"
cp "${builddir}/uutils/target/x86_64-unknown-linux-musl/release/uutils" "${rootdir}/Applications/uutils/bin/uutils"

while read cmdlet ; do
  ln -s "/Applications/uutils/bin/uutils" "${rootdir}/Applications/uutils/bin/${cmdlet}"
done < <("${rootdir}/Applications/uutils/bin/uutils" | awk 'BEGIN{k=0}/Currently defined functions:/{k=1;next}{if (k==1) {print}}')

# GNU coreutils
exp=("${builddir}/coreutils/src"/*.o)
[ -f "${exp[0]}" ] || {
 dl_gpg_file "https://ftp.gnu.org/gnu/coreutils/coreutils-8.30.tar.xz" "coreutils.txz"

 rm -rf "${builddir}/coreutils" ; mkdir "${builddir}/coreutils" ; pushd "${builddir}/coreutils"
  # unpack and patch
  extract_l1_tarball "coreutils.txz"
  export CC="${devdir}/musl/bin/musl-gcc"
  export LDFLAGS="-static"
  export CFLAGS="-static -Os -fPIC"
  export LOCAL_CFLAGS="${CFLAGS}"
  ./configure --enable-no-install-program=stdbuf --program-prefix=g --prefix="${rootdir}/Applications/coreutils" #--enable-single-binary=symlinks
  make
 popd
}

pushd "${builddir}/coreutils"
 make install-exec
popd

# twiddle permissions, make tarball
pushd "${rootdir}"
find ./ -type d -exec chmod a+rx {} \;
find ./Applications/*/bin -type f -exec chmod a+rx {} \;
tar cf "${topdir}/import.tar" --owner=0 --group=0 .
popd

rm -rf "${workdir}"
