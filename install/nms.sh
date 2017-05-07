#!/bin/bash

virt-install -nnms -r512 --os-variant=centos7.0 --disk /var/lib/libvirt/images/nms.qcow2,device=disk,bus=virtio --vcpus=1 --import -w bridge=dmz,model=virtio -w bridge=vmm,model=virtio --noautoconsole
