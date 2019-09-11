#!/bin/bash

OPERATORS_NAMESPACE="openshift-operators"
LINUX_BRIDGE_NAMESPACE="linux-bridge"

set -e

# Create a subscription
cat <<EOF | oc create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kubevirt-hyperconverged
  namespace: ${OPERATORS_NAMESPACE}
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: kubevirt-hyperconverged
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo "Give the HCO operators some time to start..."

while [ "x" == "x$(oc get pods -l name=hyperconverged-cluster-operator -n ${OPERATORS_NAMESPACE} 2> /dev/null)" ]; do
    sleep 10
done

oc wait --for condition=ready pod -l name=hyperconverged-cluster-operator -n ${OPERATORS_NAMESPACE} --timeout=2400s
oc wait --for condition=ready pod -l kubevirt.io=virt-operator -n ${OPERATORS_NAMESPACE} --timeout=2400s
oc wait --for condition=ready pod -l name=cdi-operator -n ${OPERATORS_NAMESPACE} --timeout=2400s
oc wait --for condition=ready pod -l name=cluster-network-addons-operator -n ${OPERATORS_NAMESPACE} --timeout=2400s
oc wait --for condition=ready pod -l name=kubevirt-ssp-operator -n ${OPERATORS_NAMESPACE} --timeout=2400s
oc wait --for condition=ready pod -l name=node-maintenance-operator -n ${OPERATORS_NAMESPACE} --timeout=2400s

echo "Launching CNV..."
cat <<EOF | oc create -f -
apiVersion: hco.kubevirt.io/v1alpha1
kind: HyperConverged
metadata:
  name: hyperconverged-cluster
  namespace: ${OPERATORS_NAMESPACE}
EOF

echo "Give the CNV operators some time to start..."
while [ "x" == "x$(oc get pods -l cdi.kubevirt.io -n ${OPERATORS_NAMESPACE} 2> /dev/null)" ]; do
    sleep 10
done

oc wait --for condition=ready pod -l cdi.kubevirt.io -n ${OPERATORS_NAMESPACE} --timeout=2400s

while [ "x" == "x$(oc get pods -l kubevirt.io=virt-api -n ${OPERATORS_NAMESPACE} 2> /dev/null)" ]; do
    sleep 10
done

oc wait --for condition=ready pod -l kubevirt.io=virt-api -n ${OPERATORS_NAMESPACE} --timeout=2400s

while [ "x" == "x$(oc get pods -l kubevirt.io=virt-controller -n ${OPERATORS_NAMESPACE} 2> /dev/null)" ]; do
    sleep 10
done

oc wait --for condition=ready pod -l kubevirt.io=virt-controller -n ${OPERATORS_NAMESPACE} --timeout=2400s

while [ "x" == "x$(oc get pods -l kubevirt.io=virt-handler -n ${OPERATORS_NAMESPACE} 2> /dev/null)" ]; do
    sleep 10
done

oc wait --for condition=ready pod -l kubevirt.io=virt-handler -n ${OPERATORS_NAMESPACE} --timeout=2400s

while [ "x" == "x$(oc get pods -l kubevirt.io=virt-template-validator -n ${OPERATORS_NAMESPACE} 2> /dev/null)" ]; do
    sleep 10
done

oc wait --for condition=ready pod -l kubevirt.io=virt-template-validator -n ${OPERATORS_NAMESPACE} --timeout=2400s 

while [ "x" == "x$(oc get pods -l app=bridge-marker -n ${LINUX_BRIDGE_NAMESPACE} 2> /dev/null)" ]; do
    sleep 10
done

oc wait --for condition=ready pod -l app=bridge-marker -n ${LINUX_BRIDGE_NAMESPACE} --timeout=2400s
oc wait --for condition=ready pod -l app=cni-plugins -n ${LINUX_BRIDGE_NAMESPACE} --timeout=2400s

while [ "x" == "x$(oc get pods -l app=kubevirt-node-labeller -n ${OPERATORS_NAMESPACE} 2> /dev/null)" ]; do
    sleep 10
done

oc wait --for condition=ready pod -l app=kubevirt-node-labeller -n ${OPERATORS_NAMESPACE} --timeout=2400s

echo "Done installing CNV!"
