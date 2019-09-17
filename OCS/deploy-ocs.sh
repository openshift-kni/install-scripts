#!/bin/bash
ocs_version="${ocs_version:-release-4.2}"
NAMESPACE="openshift-storage"
LOCALNAMESPACE="local-storage"

if [ -z "${KUBECONFIG}" ]; then
  export KUBECONFIG=$(find ${HOME} -iname kubeconfig -type f)
  if [ ! -z "${KUBECONFIG}" ]; then
    echo "Loading kubeconfig from $KUBECONFIG"
  else
    echo "Could not find kubeconfig location"
    exit 1
  fi
else
  echo "Loading kubeconfig from $KUBECONFIG"
fi

# export is required for envsubst
export rook_override="${rook_override:-false}"

# Detect network subnets based on the deploy host addresses
# Do not do anything if env variables already set
if [[ -z "${public_network}" ]]; then
  export public_network="$(ip r | awk '/dev\ baremetal\ proto\ kernel\ scope\ link\ src/ {print $1}')"
fi

if [[ -z "${cluster_network}" ]]; then
  export cluster_network="$(ip r | awk '/dev\ provisioning\ proto\ kernel\ scope\ link\ src/ {print $1}')"
fi

# Provide disks to use for mon and osd pvcs
export cluster="${cluster:-openshift-storage}"
# Size number for mon pvcs
export mon_size="${mon_size:-5}"
# List of /dev/* disks to use for osd, separated by comma
# If environment var not set autogenerate the list with all disks detected on
# the deploy host except the first one which is used for OS
if [[ -z "${osd_devices}" ]]; then
  export osd_devices="$(lsblk -p -d -n -o name -I8,259 | tail -n +2 | paste -s -d ',')"
fi

if [ "${osd_devices}" == "" ]; then
  echo You need to define osd_devices
  exit 1
fi

# Size number for osd pvcs
# If osd_size var not found calculate it based on the first osd disk size found on deploy host
if [[ -z "${osd_size}" ]]; then
  first_osd_size_bytes=$(lsblk -p -d -n -o size -b $(echo $osd_devices | cut -d , -f1))
  export osd_size="$(( $first_osd_size_bytes/1024/1024/1024 ))"
fi

if [ "${osd_size}" == "" ]; then
  echo You need to define osd_size
  exit 1
fi

echo Using osd_devices ${osd_devices} of size ${osd_size}

oc create -f https://raw.githubusercontent.com/openshift/ocs-operator/${ocs_version}/deploy/deploy-with-olm.yaml

while ! oc wait --for condition=ready pod -l name=ocs-operator -n ${NAMESPACE} --timeout=2400s; do sleep 10 ; done
while ! oc wait --for condition=ready pod -l app=rook-ceph-operator -n ${NAMESPACE} --timeout=2400s; do sleep 10 ; done
while ! oc wait --for condition=ready pod -l app=noobaa -n ${NAMESPACE} --timeout=2400s; do sleep 10 ; done
while ! oc wait --for condition=ready pod -l name=local-storage-operator -n ${NAMESPACE} --timeout=2400s; do sleep 10 ; done

# This should be done by the ocs operator
oc adm policy add-cluster-role-to-user cluster-admin -z ocs-operator -n openshift-storage
oc adm policy add-cluster-role-to-user cluster-admin -z local-storage-operator -n openshift-storage

# Gather list of master nodes
export masters=$(oc get node -o custom-columns=NAME:.metadata.name --no-headers | tr '\n' ',' | sed 's/.$//')
master_count=$(echo $(IFS=,; set -f; set -- $masters; echo $#))
# Calculate number of osd to create
osd_count=$(echo $(IFS=,; set -f; set -- $osd_devices; echo $#))
export osd_count=$(( $osd_count * $master_count ))

oc create -f mon_sc.yml
export counter=0
for node in $(oc get node -o custom-columns=IP:.status.addresses[0].address --no-headers); do
    ssh -o StrictHostKeyChecking=no core@$node "sudo mkdir /mnt/mon"
    envsubst < hostpath.yml | oc create -f -
    export counter=$(( $counter + 1 )) 
done
envsubst < cr_osd.yaml | oc create -f -

if [ "$rook_override" == "true" ] ; then
  envsubst < rook-config-override.yaml | oc create -f -
fi

# Mark masters as storage nodes
for master in $( echo $masters | sed 's/,/ /g') ; do 
    oc label nodes $master cluster.ocs.openshift.io/openshift-storage=''
done

envsubst < storagecluster.yaml | oc create -f -

while ! oc wait --for condition=ready pod -l app=rook-ceph-mgr -n ${NAMESPACE} --timeout=2400s; do sleep 10 ; done

oc patch storageclass ${cluster}-ceph-rbd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Wait for OSD prepare jobs to be completed
echo "Waiting for the OSD jobs to be run..."

while ! oc wait --for condition=complete job -n ${NAMESPACE} -l app=rook-ceph-osd-prepare --timeout=2400s; do sleep 10 ; done
