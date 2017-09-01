#!/bin/bash

set -eux

set -o pipefail

chroot_ag() {
  chroot /mnt/target env LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get "${@}"
}

# install libvirt, firewalld
chroot_ag install -y libvirt-bin firewalld dnsmasq dhcpcd5 virtinst

# enable systemd-networkd
ln -s /lib/systemd/system/systemd-networkd.service /mnt/target/etc/systemd/system/multi-user.target.wants/systemd-networkd.service
ln -s /lib/systemd/system/systemd-networkd.socket /mnt/target/etc/systemd/system/sockets.target.wants/systemd-networkd.service
#ln -s /lib/systemd/system/systemd-networkd-wait-online.service /mnt/target/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service

chroot /mnt/target systemctl disable dhcpcd

mkdir -p /mnt/taret/etc/systemd/network

# disable ipv6 for most things
printf 'net.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 0\n' > /mnt/target/etc/sysctl.d/40-ipv6.conf

# create vmm
printf '[NetDev]\nName=vmm\nKind=bridge\n' > "/mnt/target/etc/systemd/network/vmm.netdev"
printf '[Match]\nName=vmm\n[Network]\nLinkLocalAddressing=no\nLLMNR=false\nIPv6AcceptRA=no\nAddress=192.168.128.129/25\n' > "/mnt/target/etc/systemd/network/vmm.network"

# update firewalld for vmm
mkdir /mnt/target/run/firewalld
chroot /mnt/target /usr/bin/firewall-offline-cmd --new-zone vmm
chroot /mnt/target /usr/bin/firewall-offline-cmd --zone vmm --add-interface vmm
chroot /mnt/target /usr/bin/firewall-offline-cmd --direct --add-rule eb filter FORWARD 0 --logical-in vmm -j DROP
chroot /mnt/target /usr/bin/firewall-offline-cmd --direct --add-rule eb filter FORWARD 1 --logical-out vmm -j DROP
chroot /mnt/target /usr/bin/firewall-offline-cmd --zone vmm --add-service dhcp
chroot /mnt/target /usr/bin/firewall-offline-cmd --zone vmm --add-service ntp
chroot /mnt/target /usr/bin/firewall-offline-cmd --zone vmm --add-port 3493/tcp

# libvirtd/firewalld act poorly here, shoot filtering on bridges
{
  printf 'install xt_physdev /bin/false'
  printf 'install br_netfilter /bin/false'
} > /mnt/target/etc/modprobe.d/blacklist-xt_physdev.conf

# configure dnsmasq
{
  printf 'port=0\ninterface=vmm\nbind-interfaces\nno-hosts\n'
  printf 'dhcp-range=192.168.128.130,192.168.128.254,30m\n'
  printf 'dhcp-option=3\ndhcp-option=6\ndhcp-option=12\ndhcp-option=42,0.0.0.0\n'
  printf 'dhcp-option=vendor:BBXN,1,0.0.0.0\n'
  printf 'dhcp-authoritative\n'
} > /mnt/target/etc/dnsmasq.conf
ln -sf /lib/systemd/system/dnsmasq.service /mnt/target/etc/systemd/system/multi-user.target.wants/dnsmasq.service
mkdir -p /mnt/target/etc/systemd/system/dnsmasq.service.d
printf '[Service]\nRestartSec=1s\nRestart=on-failure\n' > /mnt/target/etc/systemd/system/dnsmasq.service.d/local.conf

# configure hostname, mgmt ip
if [ -f /sys/class/dmi/id/chassis_serial ] ; then
  read cha_ser < /sys/class/dmi/id/chassis_serial
  case $cha_ser in
    GHXLTL1)
      echo 'xn--l3h' > /mnt/target/etc/hostname
      printf '[NetDev]\nName=mgmt\nKind=bridge\n'                                                    > /mnt/target/etc/systemd/network/mgmt.netdev
      printf '[Match]\nName=mgmt\n[Network]\nLinkLocalAddressing=no\nLLMNR=false\nIPv6AcceptRA=no\n' > /mnt/target/etc/systemd/network/mgmt.network
      printf '[Match]\nName=%s\n[Network]\nBridge=mgmt\nLinkLocalAddressing=no\nLLMNR=false\nIPv6AcceptRA=no\n' enp8s4 > /mnt/target/etc/systemd/network/enp8s4.network
      # configure mgmt to use dhcpcd, with a fallback managed via systemd...
      mkdir -p /mnt/target/usr/local/libexec
      {
        printf '[Unit]\nDescription=dhcpcd on %%I\nWants=network.target\nBefore=network.target\nOnFailure=dhclient-fallback@%%i.service\n'
        printf '[Service]\n'
        printf 'ExecStart=/sbin/dhcpcd -4 -A -d -1 -w %%i\nRestart=on-success\n'
      } > "/mnt/target/etc/systemd/system/dhcpcd@.service"
      printf '[Unit]\nDescription=dhcpcd watchdog for %%I\n[Timer]\nOnBootSec=5min\nOnUnitActiveSec=30min\nUnit=dhcpcd@%%i.service\n[Install]\nWantedBy=timers.target\n' > "/mnt/target/etc/systemd/system/dhcpcd@.timer"
      printf '[Unit]\nDescription=dhclient fallback for %%I\n[Service]\nType=oneshot\nExecStart=/usr/local/libexec/dhclient-fallback.sh %%i\n' > "/mnt/target/etc/systemd/system/dhclient-fallback@.service"

      printf '[Match]\nName=%s\n[Network]\nLinkLocalAddressing=no\nLLMNR=false\nIPv6AcceptRA=no\n' enp8s5 > /mnt/target/etc/systemd/network/enp8s5.network
      {
        printf '#!/usr/bin/env bash\nif [ -f "/usr/local/etc/dhclient-fallback/${1}.conf" ] ; then\n'
        printf ' source "/usr/local/etc/dhclient-fallback/${1}.conf"\nelse\n exit 0\nfi\n'
        printf 'ip addr add "${IPADDR0}" dev "${1}"\n'
        printf 'if [ ! -z "${GATEWAY}" ]; then\n ip route add default via "${GATEWAY}"\nfi\n'
      } > /mnt/target/usr/local/libexec/dhclient-fallback.sh
      chmod +x /mnt/target/usr/local/libexec/dhclient-fallback.sh

      ln -s /etc/systemd/system/dhcpcd@.timer /mnt/target/etc/systemd/system/timers.target.wants/dhcpcd@mgmt.timer

      mkdir -p /mnt/target/usr/local/etc/dhclient-fallback
      printf 'IPADDR0=192.168.129.30/24\n' > /mnt/target/usr/local/etc/dhclient-fallback/mgmt.conf
      ;;
  esac
fi
