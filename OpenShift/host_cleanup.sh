#!/usr/bin/env bash
set -x

source ../common/logging.sh
source common.sh

LOGLEVEL="${LOGLEVEL:-info}"

ocp/openshift-baremetal-install destroy cluster --log-level ${LOGLEVEL} --dir ocp/

BOOTSTRAPVM=$(sudo virsh list | awk '/bootstrap/ { print $2 }')
if [[ "${BOOTSTRAPVM}" != "" ]]; then
  sudo virsh destroy ${BOOTSTRAPVM}
  sudo virsh undefine ${BOOTSTRAPVM} --remove-all-storage
  sudo rm -Rf /var/lib/libvirt/images/${BOOTSTRAPVM}.ign
fi

rm -Rf ./ocp/ ~/.cache/openshift-install/
ssh-keygen -R 172.22.0.2
