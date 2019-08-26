#!/usr/bin/env bash
set -xe

source ../common/logging.sh
source common.sh

# FIXME: we don't generate a user SSH key - check for one?

# Restart libvirtd service to get the new group membership loaded
if ! id $USER | grep -q libvirt; then
  sudo usermod -a -G "libvirt" $USER
  sudo systemctl restart libvirtd
fi

# As per https://github.com/openshift/installer/blob/master/docs/dev/libvirt-howto.md#configure-default-libvirt-storage-pool
# Usually virt-manager/virt-install creates this: https://www.redhat.com/archives/libvir-list/2008-August/msg00179.html
if ! virsh pool-uuid default > /dev/null 2>&1 ; then
    virsh pool-define /dev/stdin <<EOF
<pool type='dir'>
  <name>default</name>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF
    virsh pool-start default
    virsh pool-autostart default
fi

# FIXME: is this needed?
ZONE="\nZONE=libvirt"

# Create the provisioning bridge
if ! virsh net-uuid provisioning > /dev/null 2>&1 ; then
    virsh net-define /dev/stdin <<EOF
<network>
  <name>provisioning</name>
  <bridge name='provisioning'/>
  <forward mode='bridge'/>
</network>
EOF
    virsh net-start provisioning
    virsh net-autostart provisioning
fi

# Adding an IP address in the libvirt definition for this network results in
# dnsmasq being run, we don't want that as we have our own dnsmasq, so set
# the IP address here
if [ ! -e /etc/sysconfig/network-scripts/ifcfg-provisioning ] ; then
    echo -e "DEVICE=provisioning\nTYPE=Bridge\nONBOOT=yes\nNM_CONTROLLED=no\nBOOTPROTO=static\nIPADDR=172.22.0.1\nNETMASK=255.255.255.0${ZONE}" | sudo dd of=/etc/sysconfig/network-scripts/ifcfg-provisioning
fi
sudo ifdown provisioning || true
sudo ifup provisioning

# Need to pass the provision interface for bare metal
if [ "$PRO_IF" ]; then
    echo -e "DEVICE=$PRO_IF\nTYPE=Ethernet\nONBOOT=yes\nNM_CONTROLLED=no\nBRIDGE=provisioning" | sudo dd of=/etc/sysconfig/network-scripts/ifcfg-$PRO_IF
    sudo ifdown $PRO_IF || true
    sudo ifup $PRO_IF
fi

# Create the baremetal bridge
if ! virsh net-uuid baremetal > /dev/null 2>&1 ; then
    virsh net-define /dev/stdin <<EOF
<network>
  <name>baremetal</name>
  <bridge name='baremetal'/>
  <forward mode='bridge'/>
</network>
EOF
    virsh net-start baremetal
    virsh net-autostart baremetal
fi

if [ ! -e /etc/sysconfig/network-scripts/ifcfg-baremetal ] ; then
    echo -e "DEVICE=baremetal\nTYPE=Bridge\nONBOOT=yes\nNM_CONTROLLED=no${ZONE}" | sudo dd of=/etc/sysconfig/network-scripts/ifcfg-baremetal
fi
sudo ifdown baremetal || true
sudo ifup baremetal

# Add the internal interface to it if requests, this may also be the interface providing
# external access so we need to make sure we maintain dhcp config if its available
if [ "$INT_IF" ]; then
    echo -e "DEVICE=$INT_IF\nTYPE=Ethernet\nONBOOT=yes\nNM_CONTROLLED=no\nBRIDGE=baremetal" | sudo dd of=/etc/sysconfig/network-scripts/ifcfg-$INT_IF
    if sudo nmap --script broadcast-dhcp-discover -e $INT_IF | grep "IP Offered" ; then
        grep -q BOOTPROTO /etc/sysconfig/network-scripts/ifcfg-baremetal || (echo -e "\nBOOTPROTO=dhcp\n" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-baremetal)
    fi
    sudo systemctl restart network
fi

# If there were modifications to the /etc/sysconfig/network-scripts/ifcfg-*
# files, it is required to enable the network service
sudo systemctl enable network
