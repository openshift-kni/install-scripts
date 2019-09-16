#!/bin/bash

set -e

# Optional file to set environment variable to non-default values instead of defining them on shell session level. File myenv.sh should be located in 
# current directory 
if [[ -f ./myenv.sh ]]; then 
  echo ">>> myenv.sh file is present, setting some of the variables to non-default values"
  . ./myenv.sh
fi

#Global namespace in OpenShift version 4.2 supposed to be openshift-marketplace 

##################
# Variables defining behavior of the script 
# CUSTOM_APPREGISTRY - if true will use quay registry as application registry
CUSTOM_APPREGISTRY=${CUSTOM_APPREGISTRY:-true}
# NAMESPACED_SUBSCR - if true will create operator group explicitely specifying target namespaces that will be managed by operator otherwise it will set 
#                     operator group globally 
NAMESPACED_SUBSCR=${NAMESPACED_SUBSCR:-false}
# WAIT_FOR_OBJECT_CREATION - Time in seconds for script to wait for some of the required objects to be created in Kubernetes. Time out will cause script to exit
WAIT_FOR_OBJECT_CREATION=${WAIT_FOR_OBJECT_CREATION:-60}



GLOBAL_NAMESPACE="${GLOBAL_NAMESPACE:-openshift-marketplace}"
APP_REGISTRY="${APP_REGISTRY:-rh-osbs-operators}"
PACKAGE="${PACKAGE:-kubevirt-hyperconverged}"
TARGET_NAMESPACE="${TARGET_NAMESPACE:-openshift-cnv}"
OPERATOR_NAME="${OPERATOR_NAME:-hco-operatorhub}"
CHANNEL_VERSION="${CHANNEL_VERSION:-2.1.0}"
SUBSCRIPTION_APPROVAL="${SUBSCRIPTION_APPROVAL:-Manual}"
export TARGET_NAMESPACE


if [[ ${CUSTOM_APPREGISTRY} ]]; then

  QUAY_TOKEN="${QUAY_TOKEN:-}"

  if [ -z "${QUAY_TOKEN}" ]; then 

    # If application registry authentication token hasn't been provided check for username/password
    QUAY_USERNAME="${QUAY_USERNAME:-}"
    QUAY_PASSWORD="${QUAY_PASSWORD:-}"

    if [ -z "${QUAY_USERNAME}" ]; then
        echo ">>> QUAY_USERNAME is not set "
        exit 1
    fi

    if [ -z "${QUAY_PASSWORD}" ]; then
        echo ">>> QUAY_PASSWORD is not set "
        exit 1
    fi

  else

    echo ">>> Token for Quay registry has been provided. Validating access ..."

    # To validate that token is correct and credentials are valid we will extract username and password from token. This step may look somewhat redundant but
    # unfortunately at this point Quay doesn't seem to provide alternative API to validate access 

    QUAY_USERNAME=$(echo ${QUAY_TOKEN}|cut -d' '  -f2|base64 -d |cut -d : -f1)
    QUAY_PASSWORD=$(echo ${QUAY_TOKEN}|cut -d' '  -f2|base64 -d |cut -d : -f2)

  fi

  QUAY_TOKEN=$(curl -sH "Content-Type: application/json" -XPOST https://quay.io/cnr/api/v1/users/login -d '
  {
      "user": {
          "username": "'"${QUAY_USERNAME}"'",
          "password": "'"${QUAY_PASSWORD}"'"
      }
  }' | jq -r '.token')

    if [ "${QUAY_TOKEN}" == "null" ]; then
        echo "TOKEN was 'null'.  Did you enter the correct quay Username & Password?"
        exit 1
    fi

    echo ">>> Creating registry secret"
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: "quay-registry-${APP_REGISTRY}"
  namespace: "${GLOBAL_NAMESPACE}"
type: Opaque
stringData:
      token: "${QUAY_TOKEN}"
EOF

fi

# 1. Create namespace for new operator 
echo ">>> Create target namespace ${TARGET_NAMESPACE}"
if ! `oc get project ${TARGET_NAMESPACE} &>/dev/null`;then
    oc create ns ${TARGET_NAMESPACE}
fi

# 2. Create OperatorGroup defining namespaces that OLM will be monitoring  
echo ">>> Creating operatorgroup ${TARGET_NAMESPACE}-group"
if ! `oc get operatorgroup ${TARGET_NAMESPACE}-group -n ${TARGET_NAMESPACE} &>/dev/null` ; then
  if [[ ${NAMESPACED_SUBSCR} ]]; then

    echo "Creating OperatorGroup"
    cat <<EOF | oc create -f - || true
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: "${TARGET_NAMESPACE}-group"
  namespace: "${TARGET_NAMESPACE}"
spec:
  targetNamespaces:
  - ${TARGET_NAMESPACE}
EOF
else
    cat <<EOF | oc create -f - || true
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: "${TARGET_NAMESPACE}-group"
  namespace: "${TARGET_NAMESPACE}"
spec: {}
EOF
  fi
fi

# 3. Create OperatorSource defining the source of operator catalog and creating CatalogSource. 
echo ">>> Creating OperatorSource and CatalogSource..."
if ! `oc get operatorsource ${APP_REGISTRY} -n ${GLOBAL_NAMESPACE} &>/dev/null`  && [ ${CUSTOM_APPREGISTRY} ]; then

  echo "OperatorSource ${APP_REGISTRY} doesn't exist, creating ..."
  cat <<EOF | oc create -f -
apiVersion: operators.coreos.com/v1
kind: OperatorSource
metadata:
  name: "${APP_REGISTRY}"
  namespace: "${GLOBAL_NAMESPACE}"
spec:
  type: appregistry
  endpoint: https://quay.io/cnr
  registryNamespace: "${APP_REGISTRY}"
  displayName: "${APP_REGISTRY}"
  publisher: "Red Hat"
  authorizationToken:
    secretName: "quay-registry-${APP_REGISTRY}"
EOF
  tempCounter=0
  while [[ `oc get operatorsource ${APP_REGISTRY} -n ${GLOBAL_NAMESPACE} -o jsonpath='{.status.currentPhase.phase.name}'` != "Succeeded" ]] \
  && \
  [ ${tempCounter} -lt $((WAIT_FOR_OBJECT_CREATION/5)) ];do
    sleep 5
    echo "Waiting for all objects defined by subscription to be created ..." 
    let tempCounter=${tempCounter}+1
  done
  if [[ ${tempCounter} -eq $((WAIT_FOR_OBJECT_CREATION/5)) ]]; then 
     echo "OperatorSource creation has timed out..."
     exit 1
  fi
fi

# 4. Verifying and potentially waiting for all package manifests to be loaded from the bundle 
echo ">>> Waiting for packagemanifest ${PACKAGE} to be created ..."
tempCounter=0
while [[ `oc get packagemanifest  -l catalog=${APP_REGISTRY} --field-selector metadata.name=${PACKAGE} --no-headers -o custom-columns=name:metadata.name` != "${PACKAGE}" ]]  \
&& \
[ ${tempCounter} -lt $((WAIT_FOR_OBJECT_CREATION/5)) ];do
  sleep 5
  echo "Waiting for packagemanifest to be created ..." 
  let tempCounter=${tempCounter}+1
done
if [[ ${tempCounter} -eq $((WAIT_FOR_OBJECT_CREATION/5)) ]]; then 
    echo "Package manifest ${PACKAGE} doesn't exist or packagemanifest creation has timed out..."
    exit 1
fi

# 5. Adding subscription for the selected operator with manual install plan 
echo ">>> Creating Subscription ${OPERATOR_NAME} ..."
if [[ "`oc get subscription ${OPERATOR_NAME} -n ${TARGET_NAMESPACE} -o jsonpath='{.spec.channel}'`" == "${CHANNEL_VERSION}" ]]; then
  echo "Subscrition ${OPERATOR_NAME} already exist, skipping creation..."
else
    cat <<EOF | oc create -f - 
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: "${OPERATOR_NAME}"
  namespace: "${TARGET_NAMESPACE}"
spec:
  source: "${APP_REGISTRY}"
  sourceNamespace: "${GLOBAL_NAMESPACE}"
  name: ${PACKAGE}
  channel: "${CHANNEL_VERSION}"
  installPlanApproval: "${SUBSCRIPTION_APPROVAL}"
EOF
  oc wait subscription ${OPERATOR_NAME} -n ${TARGET_NAMESPACE} --for=condition=InstallPlanPending --timeout="${WAIT_FOR_OBJECT_CREATION}s"
fi 


# 6. Approve install plan for subscription 
echo ">>> Approving installPlan for subscription ${OPERATOR_NAME}"
if [[ `oc get subscription ${OPERATOR_NAME} -n ${TARGET_NAMESPACE} -o jsonpath='{.spec.installPlanApproval}'` == "Manual" ]]; then 
    oc patch installplan `oc get subscription ${OPERATOR_NAME} -n ${TARGET_NAMESPACE} -o jsonpath='{.status.installplan.name}'` -n ${TARGET_NAMESPACE} --type=json -p='[{"op":"replace", "path":"/spec/approved","value":true}]'
fi

# Unfortunately CSV object doesn't set status.conditions correctly for kubectl or oc wait command to work correctly. Replaced with while 
echo ">>> Creating all required objects for subscription ${OPERATOR_NAME} ..."
tempCounter=0
while [[ `oc get csv $(oc get subscription ${OPERATOR_NAME} -n ${TARGET_NAMESPACE} -o jsonpath='{.status.installedCSV}') -n ${TARGET_NAMESPACE} -o jsonpath='{.status.phase}'` != "Succeeded" ]] \
&& \
[ ${tempCounter} -lt $((WAIT_FOR_OBJECT_CREATION/5)) ];do
  sleep 5
  echo "Waiting for all objects defined by subscription to be created ..." 
  let tempCounter=${tempCounter}+1
done
if [[ ${tempCounter} -eq $((WAIT_FOR_OBJECT_CREATION/5)) ]]; then 
    echo "OperatorSource creation has timed out..."
    exit 1
fi
echo ">>> **** Operator ${OPERATOR_NAME} has been installed ****"

# Experimental 
# Trigger Operator to install application resources. 
# Considering that complexity of Custom Resources and installation sequence can vary between different operators we will rely on kustomize functionality
# that is part kubectl client starting from Kubernetes 1.14. Note: As oc kustomize doesn't have edit subcommand we will have to update tokens in kustomization.yaml
#file . Use https://github.com/kubernetes-sigs/kustomize documentation for details on kustomize syntax and implementation details

# Trigger 
if [[ -d ./kustomize ]]; then 
  #if template kustomization.yaml file template is present replace all variables with actual values set in this script
  if [[ -f ./kustomize/${OPERATOR_NAME}/kustomization.yaml.templ ]]; then 
    cat ./kustomize/${OPERATOR_NAME}/kustomization.yaml.templ|envsubst '${TARGET_NAMESPACE} ${OPERATOR_NAME} {CHANNEL_VERSION}' > ./kustomize/${OPERATOR_NAME}/kustomization.yaml
  fi 
  if [[ ! -f ./kustomize/${OPERATOR_NAME}/kustomization.yaml ]]; then
    echo ">>> kustomization.yaml file is not present. Something went wrong processing template or directory is empty. Skiping executions of operator kustomize sequence"
    exit 1
  fi 
  echo ">>> Triggering ${OPERATOR_NAME} as defined in kustomization.yaml file"
  echo ">>> Following objects are defined and will be applied: "
  oc kustomize ./kustomize/${OPERATOR_NAME}
  oc apply -k ./kustomize/${OPERATOR_NAME}
else
  echo ">>> Directory kustomize is not present , skipping trigering operator. Manually apply required CRs"
fi