#!/bin/bash

set -ex

source ../common/logging.sh
source common.sh

# Either pull or build the ironic images
# To build the IRONIC image set
# IRONIC_IMAGE=https://github.com/metalkube/metalkube-ironic
for IMAGE_VAR in IRONIC_IMAGE COREOS_DOWNLOADER_IMAGE ; do
    IMAGE=${!IMAGE_VAR}
    sudo podman pull "$IMAGE"
done

for name in httpd coreos-downloader; do
    sudo podman ps | grep -w "$name$" && sudo podman kill $name
    sudo podman ps --all | grep -w "$name$" && sudo podman rm $name -f
done

# Remove existing pod
if  sudo podman pod exists ironic-pod ; then 
    sudo podman pod rm ironic-pod -f
fi

# Create pod
sudo podman pod create -n ironic-pod 

# We start only the httpd and *downloader containers so that we can provide
# cached images to the bootstrap VM
sudo podman run -d --net host --privileged --name httpd --pod ironic-pod \
     -v ${CACHED_IMAGE_DIR}:/shared --entrypoint /bin/runhttpd ${IRONIC_IMAGE}

sudo podman run -d --net host --privileged --name coreos-downloader --pod ironic-pod \
     -v ${CACHED_IMAGE_DIR}:/shared ${COREOS_DOWNLOADER_IMAGE} /usr/local/bin/get-resource.sh ${RHCOS_IMAGE_URL}

# Wait for the downloader containers to finish, if they are updating an existing cache
# the checks below will pass because old data exists
sudo podman wait -i 1000 coreos-downloader

# Wait for images to be downloaded/ready
while ! curl --fail http://localhost/images/rhcos-ootpa-latest.qcow2.md5sum ; do sleep 5 ; done
