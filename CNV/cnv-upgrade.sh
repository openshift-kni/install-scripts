#!/bin/bash

set -ex

OLD_CNV_VERSION="${OLD_CNV_VERSION:-2.0.0}"
CNV_VERSION="${CNV_VERSION:-2.1.0}"
OLD_CNV_CHANNEL="${OLD_CNV_VERSION:0:3}"
CNV_CHANNEL="${CNV_VERSION:0:3}"
TARGET_NAMESPACE="${TARGET_NAMESPACE:-openshift-cnv}"

oc get sub hco-subscription -o yaml -n "${TARGET_NAMESPACE}" | sed "s/channel: ${OLD_CNV_CHANNEL}/channel: ${CNV_CHANNEL}/" | oc apply -n "${TARGET_NAMESPACE}" -f -

oc get installplan -o yaml -n "${TARGET_NAMESPACE}" $(oc get installplan -n "${TARGET_NAMESPACE}" --no-headers | grep kubevirt-hyperconverged-operator.v"${CNV_VERSION}" | awk '{print $1}') | sed 's/approved: false/approved: true/' | oc apply -n "${TARGET_NAMESPACE}" -f -

echo "Waiting until OLM replaces the ${OLD_CNV_VERSION} CSV"
echo "This could take up to 10 minutes..."
while [ -z "$(oc get csv -o'custom-columns=status:status.conditions[-1].phase,metadata:metadata.name' --no-headers | grep kubevirt-hyperconverged-operator.v${CNV_VERSION} | grep Succeeded)" ]; do
    echo "Waiting for ${CNV_VERSION} CSV to be in 'Succeeded'..."
    oc get csv -o'custom-columns=status:status.conditions[-1].phase,metadata:metadata.name' --no-headers | grep kubevirt-hyperconverged-operator
    sleep 30
done
