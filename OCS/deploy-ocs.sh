#!/bin/bash
NAMESPACE="openshift-storage"
LOCALNAMESPACE="local-storage"

# export is required for envsubst
export rook_override="${rook_override:-false}"
export public_network="${public_network:-1.1.1.1/24}"
export cluster_network="${cluster_network:-1.1.1.1/24}"

# Provide disks to use for mon and osd pvcs
export cluster="${cluster:-mycluster}"
# Size number for mon pvcs
export mon_size="${mon_size:-5}"
# List of /dev/* disks to use for osd, separated by comma
export osd_devices="${osd_devices:-}"
# Size number for osd pvcs
export osd_size="${osd_size:-55}"

if [ "${osd_devices}" == "" ]; then
  echo You need to define osd_devices
  exit 1
else
 echo Using osd_devices ${osd_devices}
fi

oc create -f https://raw.githubusercontent.com/openshift/ocs-operator/master/deploy/deploy-with-olm.yaml

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

curl -s https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/toolbox.yaml | sed "s/namespace: rook-ceph/namespace: ${NAMESPACE}/" | oc create -f -

while ! oc wait --for condition=ready pod -l app=rook-ceph-tools -n ${NAMESPACE} --timeout=2400s; do sleep 10 ; done

oc create -f cephblockpool.yaml
oc create -f storageclass.yaml
oc create -f monitoring.yaml
oc create -f prometheus.yaml

# Wait for OSD prepare jobs to be completed
echo "Waiting for the OSD jobs to be run..."

while ! oc wait --for condition=complete job -n ${NAMESPACE} -l app=rook-ceph-osd-prepare --timeout=2400s; do sleep 10 ; done
