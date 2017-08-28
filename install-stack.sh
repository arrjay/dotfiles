#!/bin/bash

set -eux

set -o pipefail

chroot_ag() {
  chroot /mnt/target env LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get "${@}"
}

# install libvirt, firewalld
chroot_ag install -y libvirt-bin firewalld

# enable systemd-networkd
ln -s /lib/systemd/system/systemd-networkd.service /mnt/target/etc/systemd/system/multi-user.target.wants/systemd-networkd.service
ln -s /lib/systemd/system/systemd-networkd.socket /mnt/target/etc/systemd/system/sockets.target.wants/systemd-networkd.service
ln -s /lib/systemd/system/systemd-networkd-wait-online.service /mnt/target/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service

mkdir -p /mnt/taret/etc/systemd/network

# disable ipv6 for most things
printf 'net.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 0\n' > /mnt/target/etc/sysctl.d/40-ipv6.conf

# create vmm
printf '[NetDev]\nName=vmm\nKind=bridge\n' > "/mnt/target/etc/systemd/network/vmm.netdev"
printf '[Match]\nName=vmm\n[Network]\nLinkLocalAddressing=no\nLLMNR=false\nIPv6AcceptRA=no\nAddress=192.168.128.129/25\n' > "/mnt/target/etc/systemd/network/vmm.network"

