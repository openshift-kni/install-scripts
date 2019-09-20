#!/bin/bash

set -ex

TARGET_NAMESPACE="${TARGET_NAMESPACE:-openshift-cnv}"

oc get installplan -o yaml -n ${TARGET_NAMESPACE} $(oc get installplan -n ${TARGET_NAMESPACE} --no-headers | grep kubevirt-hyperconverged-operator.v2.1.0 | awk '{print $1}') | sed 's/approved: false/approved: true/' | oc apply -n openshift-cnv -f -

echo "Waiting until update finishes"
echo "This could take up some time..."
oc get hco -n ${TARGET_NAMESPACE} hyperconverged-cluster -o=jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.message}{"\n"}{end}'
while [ $(oc get hco -n ${TARGET_NAMESPACE} hyperconverged-cluster -o=jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.message}{"\n"}{end}' | grep -c 'Reconcile completed successfully') != "5"] ; then do
    echo "Waiting for HCO to upgrade ..."
    sleep 30
done
