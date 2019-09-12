#!/usr/bin/bash

set -e

script_name=$0

RHCOS_IMAGE_URL=""
PROVISIONING_INTERFACE="eno1"
PROVISIONING_ADDRESS="172.22.0.3"
CACHE_URL="http://172.22.0.1/images"

function usage {
    cat - <<EOF

$script_name [-h|-u URL [-i INTERFACE] [-a IPADDR] [-c CACHE_URL]]

    -h            Output this help text.

    -i INTERFACE  Specify the network interface on the provisioning net.
                  Defaults to "eno1".
    -u URL        Specify the RHCOS image URL to use to prime the cache.
    -c CACHE_URL  Specify a cache URL where the image can be downloaded
                  Defaults to http://172.22.0.1/images.

EOF
}

while getopts "hi:u:c:" opt; do
    case ${opt} in
        h)
            usage;
            exit 1
            ;;
        i)
            PROVISIONING_INTERFACE=$OPTARG
            ;;
        u)
            RHCOS_IMAGE_URL=$OPTARG
            ;;
        c)
            CACHE_URL=$OPTARG
            ;;
    esac
done

if [ -z "$RHCOS_IMAGE_URL" ]; then
    echo "ERROR: Missing RHCOS image URL" 1>&2
    usage
    exit 2
fi

if [ -z "$PROVISIONING_INTERFACE" ]; then
    echo "ERROR: Missing provisioning interface" 1>&2
    usage
    exit 2
fi

if [ -z "$CACHE_URL" ]; then
    echo "ERROR: Missing cache URL" 1>&2
    usage
    exit 2
fi

cat - <<EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: metal3-config
  namespace: openshift-machine-api
data:
  http_port: "6180"
  provisioning_interface: "${PROVISIONING_INTERFACE}"
  provisioning_ip: "${PROVISIONING_ADDRESS}/24"
  dhcp_range: "172.22.0.10,172.22.0.100"
  deploy_kernel_url: "http://${PROVISIONING_ADDRESS}:6180/images/ironic-python-agent.kernel"
  deploy_ramdisk_url: "http://${PROVISIONING_ADDRESS}:6180/images/ironic-python-agent.initramfs"
  ironic_endpoint: "http://${PROVISIONING_ADDRESS}:6385/v1/"
  ironic_inspector_endpoint: "http://${PROVISIONING_ADDRESS}:5050/v1/"
  cache_url: "${CACHE_URL}"
  rhcos_image_url: "${RHCOS_IMAGE_URL}"
EOF
