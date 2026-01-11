#!/usr/bin/env bash
set -eux

sources=(
  dotfiles-static-base
  dotfiles-static-userspace-coreutils-8.32-native
  dotfiles-static-userspace-coreutils-9.9-native
  dotfiles-static-userspace-busybox
  dotfiles-static-userspace-toybox
  dotfiles-static-userspace-uutils
)

# prep dotfiles tar
scratch="$(mktemp -d)"
mkdir "${scratch}/root"
cp bashrc "${scratch}/root/.bashrc"
( cd "${scratch}/root" && tar cf "${scratch}/import.tar" --owner=0 --group=0 . ; )

for image in ${sources[@]} ; do
  container="$(buildah from "${image}")"
  buildah add "${container}" "${scratch}/import.tar" /
  buildah rmi "${image}-test" || true
  buildah commit "${container}" "${image}-test"
  buildah rm "${container}"
done

rm -rf "${scratch}"
