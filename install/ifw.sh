#!/bin/sh

virt-install -nifw -r128 --os-variant=openbsd5.8 --disk /var/lib/libvirt/images/ifw.qcow2,device=disk,bus=virtio --vcpus=1 --import -w bridge=transit,model=virtio -w bridge=vmm,model=virtio -w bridge=dmz,model=virtio -w bridge=virthost,model=virtio -w bridge=netmgmt,model=virtio -w bridge=standard,model=virtio -w bridge=restricted,model=virtio --noautoconsole
