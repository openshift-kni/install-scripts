#!/bin/sh
NAMESPACE="openshift-storage"

oc create -f cluster.yaml
sleep 10

oc wait --for condition=ready pod -l app=rook-ceph-agent -n ${NAMESPACE} --timeout=2400s

oc create -f toolbox.yaml

oc wait --for condition=ready pod -l app=rook-ceph-tools -n ${NAMESPACE} --timeout=2400s

tools_pod=$(oc get pod -n ${NAMESPACE} -l app=openshift-storage-tools -o custom-columns=NAME:.metadata.name --no-headers)

while [ "x" == "x$(oc exec -ti -n ${NAMESPACE} ${tools_pod} -- bash -c 'echo \$ROOK_ADMIN_SECRET')" ]; do
  sleep 5
done

admin_key=$(oc exec -ti -n ${NAMESPACE} ${tools_pod} -- bash -c "echo -n \$ROOK_ADMIN_SECRET" | base64)
admin_id=$(echo -n admin|base64)

envsubst < secret.yaml | oc create -f -

oc create -f cephblockpool.yaml

oc create -f storageclass.yaml

oc create -f rook-config-override.yaml

oc create -f monitoring.yaml
