virt-install --location http://192.168.128.129/bootstrap/centos7/ --name netmgmt --memory 1536 --disk size=12 --graphics none --extra-args="console=ttyS0,115200n8" --network bridge=vmm
