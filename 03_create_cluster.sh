#!/bin/bash
set -xe

source logging.sh
source common.sh

export OPENSHIFT_RELEASE_IMAGE="${OPENSHIFT_RELEASE_IMAGE:-registry.svc.ci.openshift.org/ocp/release:4.2}"

function extract_installer() {
    local release_image
    local outdir

    release_image="$1"
    outdir="$2"

    extract_dir=$(mktemp -d "installer--XXXXXXXXXX")
    pullsecret_file=$(mktemp "pullsecret--XXXXXXXXXX")

    echo "${PULL_SECRET}" > "${pullsecret_file}"
    # FIXME: Find the pullspec for baremetal-installer image and extract the image, until
    # https://github.com/openshift/oc/pull/57 is merged
    baremetal_image=$(oc adm release info --registry-config "${pullsecret_file}" $OPENSHIFT_RELEASE_IMAGE -o json | jq -r '.references.spec.tags[] | select(.name == "baremetal-installer") | .from.name')
    oc image extract --registry-config "${pullsecret_file}" $baremetal_image --path usr/bin/openshift-install:${extract_dir}

    chmod 755 "${extract_dir}/openshift-install"
    mv "${extract_dir}/openshift-install" "${outdir}"
    export OPENSHIFT_INSTALLER="${outdir}/openshift-install"

    rm -rf "${extract_dir}"
    rm -rf "${pullsecret_file}"
}

# TODO - Provide scripting to help generate install-config.yaml.
#  - https://github.com/openshift-kni/install-scripts/issues/19
if [ ! -f install-config.yaml ] ; then
    echo "Please create install-config.yaml"
    exit 1
fi

# Do some PULL_SECRET sanity checking
if [[ "${OPENSHIFT_RELEASE_IMAGE}" == *"registry.svc.ci.openshift.org"* ]]; then
    if [[ "${PULL_SECRET}" != *"registry.svc.ci.openshift.org"* ]]; then
        echo "Please get a valid pull secret for registry.svc.ci.openshift.org."
        exit 1
    fi
fi
if [[ "${PULL_SECRET}" != *"cloud.openshift.com"* ]]; then
    echo "Please get a valid pull secret for cloud.openshift.com."
    exit 1
fi

mkdir -p ocp
extract_installer "${OPENSHIFT_RELEASE_IMAGE}" ocp/
cp install-config.yaml ocp/
# FIXME: remove OPENSHIFT_INSTALL_RELASE_IMAGE_OVERRIDE when openshift/oc#57 merges
OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=$OPENSHIFT_RELEASE_IMAGE ${OPENSHIFT_INSTALLER} --dir ocp create cluster
