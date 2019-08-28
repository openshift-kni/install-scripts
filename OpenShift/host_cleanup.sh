#!/usr/bin/env bash
set -x

source ../common/logging.sh
source common.sh

if virsh net-uuid baremetal > /dev/null 2>&1 ; then
    virsh net-destroy baremetal
    virsh net-undefine baremetal
fi

sudo ifdown baremetal || true
sudo ip link delete baremetal || true
sudo rm -f /etc/sysconfig/network-scripts/ifcfg-baremetal

if virsh net-uuid provisioning > /dev/null 2>&1 ; then
    virsh net-destroy provisioning
    virsh net-undefine provisioning
fi

sudo ifdown provisioning || true
sudo ip link delete provisioning || true
sudo rm -f /etc/sysconfig/network-scripts/ifcfg-provisioning
