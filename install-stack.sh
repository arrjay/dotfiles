#!/bin/bash

set -eux

set -o pipefail

chroot_ag() {
  chroot /mnt/target env LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get "${@}"
}

# install libvirt, firewalld
chroot_ag install -y libvirt-bin firewalld dnsmasq

# enable systemd-networkd
ln -s /lib/systemd/system/systemd-networkd.service /mnt/target/etc/systemd/system/multi-user.target.wants/systemd-networkd.service
ln -s /lib/systemd/system/systemd-networkd.socket /mnt/target/etc/systemd/system/sockets.target.wants/systemd-networkd.service
#ln -s /lib/systemd/system/systemd-networkd-wait-online.service /mnt/target/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service

mkdir -p /mnt/taret/etc/systemd/network

# disable ipv6 for most things
printf 'net.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 0\n' > /mnt/target/etc/sysctl.d/40-ipv6.conf

# create vmm
printf '[NetDev]\nName=vmm\nKind=bridge\n' > "/mnt/target/etc/systemd/network/vmm.netdev"
printf '[Match]\nName=vmm\n[Network]\nLinkLocalAddressing=no\nLLMNR=false\nIPv6AcceptRA=no\nAddress=192.168.128.129/25\n' > "/mnt/target/etc/systemd/network/vmm.network"

# update firewalld for vmm
chroot /mnt/target /usr/bin/firewall-offline-cmd --new-zone vmm
chroot /mnt/target /usr/bin/firewall-offline-cmd --zone vmm --add-interface vmm
chroot /mnt/target /usr/bin/firewall-offline-cmd --direct --add-rule eb filter FORWARD 0 --logical-in vmm -j DROP
chroot /mnt/target /usr/bin/firewall-offline-cmd --direct --add-rule eb filter FORWARD 1 --logical-out vmm -j DROP
chroot /mnt/target /usr/bin/firewall-offline-cmd --zone vmm --add-service dhcp
chroot /mnt/target /usr/bin/firewall-offline-cmd --zone vmm --add-service ntp
chroot /mnt/target /usr/bin/firewall-offline-cmd --zone vmm --add-port 3493/tcp

# configure dnsmasq
{
  printf 'port=0\ninterface=vmm\nbind-interfaces\nno-hosts\n'
  printf 'dhcp-range=192.168.128.130,192.168.128.254,30m\n'
  printf 'dhcp-option=3\ndhcp-option=6\ndhcp-option=12\ndhcp-option=42,0.0.0.0\n'
  printf 'dhcp-option=vendor:BBXN,1,0.0.0.0\n'
  printf 'dhcp-authoritative\n'
} > /mnt/sysimage/etc/dnsmasq.conf
ln -s /lib/systemd/system/dnsmasq.service /mnt/target/etc/systemd/system/multi-user.target.wants/dnsmasq.service
mkdir -p /mnt/target/etc/systemd/system/dnsmasq.service.d
printf '[Service]\nRestartSec=1s\nRestart=on-failure\n' > /mnt/target/etc/systemd/system/dnsmasq.service.d/local.conf
