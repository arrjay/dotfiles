#!/bin/bash

virt-install -ndnc -r128 --os-variant=openbsd5.8 --disk /var/lib/libvirt/images/dnc.qcow2,device=disk,bus=virtio --vcpus=1 --import -w bridge=dmz,model=virtio --noautoconsole
