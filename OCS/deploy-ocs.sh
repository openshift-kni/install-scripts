#!/bin/bash

# This is required to be able to see the dashboard
NAMESPACE="openshift-storage"

# Pending https://github.com/openshift-metal3/dev-scripts/pull/710 to be merged
# to allow the rook cluster to use an arbitrary name
ROOK_CLUSTER="rook-ceph"
DIRNAME=$(dirname $0)

# It is required to enable tech preview because it is required for CSI until OCP 4.3 (see prerequisites here https://rook.io/docs/rook/v1.0/ceph-csi-drivers.html 'a Kubernetes v1.13+ is needed in order to support CSI Spec 1.0') :
oc patch featureGate cluster --type merge -p '{"spec":{"featureSet":"TechPreviewNoUpgrade"}}'

if [ ! -d ~/git/rook ]; then
    git clone https://github.com/rook/rook ~/git/rook
fi

pushd .
cd ~/git/rook/cluster/examples/kubernetes/ceph

if [ ! -f common-modified.yaml ]; then
    sed -e "s/name: rook-ceph$/name: ${NAMESPACE}/" common.yaml > common-modified.yaml
    sed -ie "s/namespace: rook-ceph/namespace: ${NAMESPACE}/" common-modified.yaml
fi

oc create -f common-modified.yaml
oc label namespace ${NAMESPACE} "openshift.io/cluster-monitoring=true"

for folder in rbd cephfs; do
    for file in csi-node-plugin-psp csi-nodeplugin-rbac csi-provisioner-psp csi-provisioner-rbac; do
        if [ ! -f csi/rbac/${folder}/${file}-modified.yaml ]; then
            sed -e "s/namespace: rook-ceph/namespace: ${NAMESPACE}/" \
                csi/rbac/${folder}/${file}.yaml > csi/rbac/${folder}/${file}-modified.yaml
        fi
        oc apply -f csi/rbac/${folder}/${file}-modified.yaml
    done
done

if [ ! -f operator-openshift-with-csi-modified.yaml ]; then
    sed -e "s/namespace: rook-ceph/namespace: ${NAMESPACE}/" \
        operator-openshift-with-csi.yaml > operator-openshift-with-csi-modified.yaml
    sed -ie "s/:rook-ceph:/:${NAMESPACE}:/" operator-openshift-with-csi-modified.yaml
fi

oc create -f operator-openshift-with-csi-modified.yaml
sleep 20

oc wait --for condition=ready pod -l app=rook-ceph-operator -n ${NAMESPACE} --timeout=2400s
oc wait --for condition=ready pod -l app=rook-discover -n ${NAMESPACE} --timeout=2400s

if [ ! -f cluster-modified.yaml ]; then
    sed -e "s/namespace: rook-ceph/namespace: ${NAMESPACE}/" cluster.yaml > cluster-modified.yaml
    sed -ie "s/name: rook-ceph/name: ${ROOK_CLUSTER}/" cluster-modified.yaml
fi

oc create -f cluster-modified.yaml
sleep 10
oc wait --for condition=ready pod -l app=rook-ceph-agent -n ${NAMESPACE} --timeout=2400s

if [ ! -f toolbox-modified.yaml ]; then
    sed -e "s/namespace: rook-ceph/namespace: ${NAMESPACE}/" toolbox.yaml > toolbox-modified.yaml
fi

oc create -f toolbox-modified.yaml
oc wait --for condition=ready pod -l app=rook-ceph-tools -n ${NAMESPACE} --timeout=2400s
tools_pod=$(oc get pod -n ${NAMESPACE} -l app=rook-ceph-tools -o custom-columns=NAME:.metadata.name --no-headers)

while [ "x" == "x$(oc exec -ti -n ${NAMESPACE} ${tools_pod} -- bash -c 'echo \$ROOK_ADMIN_SECRET')" ]; do
  sleep 5
done

# In my case, the PGs where wrong so the cluster wasn't healthy:
# oc exec -it $(oc get pod -n ${NAMESPACE} -l app=rook-ceph-tools -o jsonpath="{.items[0].metadata.name}") -n ${NAMESPACE} -- ceph osd pool set rbd pg_num 512
# oc exec -it $(oc get pod -n ${NAMESPACE} -l app=rook-ceph-tools -o jsonpath="{.items[0].metadata.name}") -n ${NAMESPACE} -- ceph status

admin_key=$(oc exec -ti -n ${NAMESPACE} ${tools_pod} -- bash -c "echo -n \$ROOK_ADMIN_SECRET" | base64)
admin_id=$(echo -n admin|base64)

cat <<EOF | oc create -f -
{
  "apiVersion": "v1",
  "kind": "Secret",
  "metadata": {
    "name": "csi-rbd-secret",
    "namespace": "default"
  },
  "data": {
    "userID": "${admin_id}",
    "userKey": "${admin_key}"
  }
}
EOF

cat <<EOF | oc create -f -
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: rbd
  namespace: ${NAMESPACE}
spec:
  failureDomain: host
  replicated:
    size: 2
EOF

cat <<EOF | oc create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-rbd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rbd.csi.ceph.com
parameters:
  clusterID: ${ROOK_CLUSTER}
  pool: rbd
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
  csi.storage.k8s.io/provisioner-secret-namespace: default
  csi.storage.k8s.io/node-stage-secret-name: csi-rbd-secret
  csi.storage.k8s.io/node-stage-secret-namespace: default
  adminid: admin
reclaimPolicy: Delete
EOF

# Enable monitoring
cat <<EOF | oc create -f -
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: prometheus
  namespace: ${NAMESPACE}
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.ceph.rook.io/aggregate-to-prometheus: "true"
rules: []
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: prometheus-rules
  namespace: ${NAMESPACE}
  labels:
    rbac.ceph.rook.io/aggregate-to-prometheus: "true"
rules:
- apiGroups: [""]
  resources:
  - nodes
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: prometheus
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus-k8s
  namespace: openshift-monitoring
EOF

cat <<EOF | oc create -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rook-ceph-mgr
  namespace: ${NAMESPACE}
  labels:
    team: rook
spec:
  namespaceSelector:
    matchNames:
      - ${NAMESPACE}
  selector:
    matchLabels:
      app: rook-ceph-mgr
      rook_cluster: ${ROOK_CLUSTER}
  endpoints:
  - port: http-metrics
    path: /metrics
    interval: 5s
EOF

# Wait for OSD prepare jobs to be completed
echo "Waiting for the OSD jobs to be run..."

while [ "x" == "x$(oc get jobs -n ${NAMESPACE} 2>/dev/null)" ]; do
    sleep 10
done
oc wait --for condition=complete job -n ${NAMESPACE} -l app=rook-ceph-osd-prepare --timeout=2400s
