#!/bin/bash

set -ex

if [[ -e ../common/logging.sh ]]; then
    source ../common/logging.sh
fi

MACHINE_CIDR=$(grep 'machineCIDR' ../OpenShift/install-config.yaml | sed 's/\(.*\): *\(.*\)/\2/')
BRIDGE_NAME=brext

export KUBECONFIG=${KUBECONFIG:-../OpenShift/ocp/auth/kubeconfig}

nodes=$(oc get nodes -o jsonpath='{range .items[*]}{.metadata.name} {end}')

echo "Configuring networks on nodes"
for node in $nodes; do
    echo "Detecting the default interface"
    while ! default_iface=$(oc get nodenetworkstate ${node} -o jsonpath="{.status.currentState.routes.running[?(@.destination==\"${MACHINE_CIDR}\")].next-hop-interface}" | cut -d " " -f 1); do
        sleep 10
    done

    if [ "${default_iface}" == "${BRIDGE_NAME}" ]; then
        echo "Bridge ${BRIDGE_NAME} seems to be already configured as the default interface on node ${node}, skipping the rest of network setup"
        continue
    fi

    echo "Detecting MAC address of the default interface"
    default_iface_mac=$(oc get nodenetworkstate ${node} -o jsonpath="{.status.currentState.interfaces[?(@.name==\"${default_iface}\")].mac-address}")

    echo "Applying node network configuration policy"
    cat <<EOF | oc apply -f -
apiVersion: nmstate.io/v1alpha1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: kni-${node}
spec:
  nodeSelector:
    kubernetes.io/hostname: ${node}
  desiredState:
    interfaces:
    - name: ${BRIDGE_NAME}
      type: linux-bridge
      state: up
      mac-address: ${default_iface_mac}
      ipv4:
        dhcp: true
        enabled: true
      ipv6:
        dhcp: true
        enabled: true
      bridge:
        options:
          stp:
            enabled: false
        port:
        - name: ${default_iface}
EOF
done

echo "Waiting until the configuration is done, it may take up to 5 minutes until keepalived gets reconfigured"
for node in $nodes; do
    until [ "$(oc get nodenetworkstate ${node} -o jsonpath="{.status.currentState.routes.running[?(@.destination==\"${MACHINE_CIDR}\")].next-hop-interface}")" == "${BRIDGE_NAME}" ]; do sleep 10; done
    oc wait node ${node} --for condition=Ready --timeout=10m
done
