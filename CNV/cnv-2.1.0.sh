#!/bin/bash

set -ex

export KUBECONFIG=${KUBECONFIG:-../OpenShift/ocp/auth/kubeconfig}

globalNamespace=`oc -n openshift-operator-lifecycle-manager get deployments catalog-operator -o jsonpath='{.spec.template.spec.containers[].args[1]}'`
echo "Global Namespace: ${globalNamespace}"

APP_REGISTRY="${APP_REGISTRY:-rh-osbs-operators}"
PACKAGE="${PACKAGE:-kubevirt-hyperconverged}"
CSC_SOURCE="${CSC_SOURCE:-hco-catalogsource-config}"
TARGET_NAMESPACE="${TARGET_NAMESPACE:-openshift-cnv}"
CLUSTER="${CLUSTER:-OPENSHIFT}"
MARKETPLACE_NAMESPACE="${MARKETPLACE_NAMESPACE:-openshift-marketplace}"
GLOBAL_NAMESPACE="${GLOBAL_NAMESPACE:-$globalNamespace}"
CNV_VERSION="${CNV_VERSION:-2.1.0}"
CNV_CHANNEL="${CNV_VERSION:0:3}"
QUAY_TOKEN="${QUAY_TOKEN:-}"
APPROVAL="${APPROVAL:-Manual}"

RETRIES="${RETRIES:-10}"

oc create ns $TARGET_NAMESPACE || true

QUAY_USERNAME="${QUAY_USERNAME:-}"
QUAY_PASSWORD="${QUAY_PASSWORD:-}"

if [ "${CLUSTER}" == "KUBERNETES" ]; then
    MARKETPLACE_NAMESPACE="marketplace"
fi

if [ -z "${QUAY_TOKEN}" ]; then
    if [ -z "${QUAY_USERNAME}" ]; then
	echo "QUAY_USERNAME is unset"
	exit 1
    fi

    if [ -z "${QUAY_PASSWORD}" ]; then
	echo "QUAY_PASSWORD is unset"
	exit 1
    fi

    QUAY_TOKEN=$(curl -sH "Content-Type: application/json" -XPOST https://quay.io/cnr/api/v1/users/login -d '
{
    "user": {
        "username": "'"${QUAY_USERNAME}"'",
        "password": "'"${QUAY_PASSWORD}"'"
    }
}' | jq -r '.token')

    echo $QUAY_TOKEN
    if [ "${QUAY_TOKEN}" == "null" ]; then
	echo "QUAY_TOKEN was 'null'.  Did you enter the correct quay Username & Password?"
	exit 1
    fi
fi

echo "Creating registry secret"
cat <<EOF | oc create -f -
apiVersion: v1
kind: Secret
metadata:
  name: "quay-registry-${APP_REGISTRY}"
  namespace: "${MARKETPLACE_NAMESPACE}"
type: Opaque
stringData:
      token: "$QUAY_TOKEN"
EOF

echo "Creating OperatorGroup"
cat <<EOF | oc create -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: "${TARGET_NAMESPACE}-group"
  namespace: "${TARGET_NAMESPACE}"
spec: {}
EOF

echo "Creating OperatorSource"
cat <<EOF | oc create -f -
apiVersion: operators.coreos.com/v1
kind: OperatorSource
metadata:
  name: "${APP_REGISTRY}"
  namespace: "${MARKETPLACE_NAMESPACE}"
spec:
  type: appregistry
  endpoint: https://quay.io/cnr
  registryNamespace: "${APP_REGISTRY}"
  displayName: "${APP_REGISTRY}"
  publisher: "Red Hat"
  authorizationToken:
    secretName: "quay-registry-${APP_REGISTRY}"
EOF

echo "Give the cluster 30 seconds to create the catalogSourceConfig..."
sleep 30

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: CatalogSourceConfig
metadata:
  name: "${CSC_SOURCE}"
  namespace: "${MARKETPLACE_NAMESPACE}"
spec:
  source: "${APP_REGISTRY}"
  targetNamespace: "${GLOBAL_NAMESPACE}"
  packages: "${PACKAGE}"
  csDisplayName: "CNV Operators"
  csPublisher: "Red Hat"
EOF

echo "Give the cluster 30 seconds to process catalogSourceConfig..."
sleep 30
oc wait deploy $CSC_SOURCE --for condition=available -n $MARKETPLACE_NAMESPACE --timeout="360s"

for i in $(seq 1 $RETRIES); do
    echo "Waiting for packagemanifest '${PACKAGE}' to be created in namespace '${TARGET_NAMESPACE}'..."
    oc get packagemanifest -n "${TARGET_NAMESPACE}" "${PACKAGE}" && break
    sleep $i
    if [ "$i" -eq "${RETRIES}" ]; then
	    echo "packagemanifest '${PACKAGE}' was never created in namespace '${TARGET_NAMESPACE}'"
	    exit 1
    fi
done

echo "Creating Subscription"
cat <<EOF | oc create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hco-operatorhub
  namespace: "${TARGET_NAMESPACE}"
spec:
  source: "${CSC_SOURCE}"
  sourceNamespace: "${GLOBAL_NAMESPACE}"
  name: kubevirt-hyperconverged
  startingCSV: "kubevirt-hyperconverged-operator.v${CNV_VERSION}"
  channel: "${CNV_CHANNEL}"
  installPlanApproval: "${APPROVAL}"
EOF

echo "Give OLM 60 seconds to process the subscription..."
sleep 60

oc get installplan -o yaml -n "${TARGET_NAMESPACE}" $(oc get installplan -n "${TARGET_NAMESPACE}" --no-headers | grep "kubevirt-hyperconverged-operator.v${CNV_VERSION}" | awk '{print $1}') | sed 's/approved: false/approved: true/' | oc apply -n "${TARGET_NAMESPACE}" -f -

echo "Give OLM 60 seconds to process the installplan..."
sleep 60

oc wait pod $(oc get pods -n ${TARGET_NAMESPACE} | grep hco-operator | head -1 | awk '{ print $1 }') --for condition=Ready -n ${TARGET_NAMESPACE} --timeout="360s"

echo "Creating the HCO's Custom Resource"
cat <<EOF | oc create -f -
apiVersion: hco.kubevirt.io/v1alpha1
kind: HyperConverged
metadata:
  name: hyperconverged-cluster
  namespace: "${TARGET_NAMESPACE}"
spec:
  BareMetalPlatform: true
EOF
