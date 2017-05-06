#!/bin/sh

virt-install -nefw -r128 --os-variant=openbsd5.8 --disk /var/lib/libvirt/images/efw.qcow2,device=disk,bus=virtio --vcpus=1 --import -w bridge=uplink,model=virtio -w bridge=transit,model=virtio -w bridge=transit,model=virtio --noautoconsole
