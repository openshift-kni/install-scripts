#!/bin/bash

set -ex

MACHINE_CIDR=$(grep 'machineCIDR' ../OpenShift/install-config.yaml | sed 's/\(.*\): *\(.*\)/\2/')
BRIDGE_NAME=brext

export KUBECONFIG=${KUBECONFIG:-../OpenShift/ocp/auth/kubeconfig}

echo "Configuring networks on nodes"

echo "Detecting the default interface"
while ! default_iface=$(oc get nodenetworkstate ${node} -o jsonpath="{.items[0].status.currentState.routes.running[?(@.destination==\"${MACHINE_CIDR}\")].next-hop-interface}" | cut -d " " -f 1); do
    sleep 10
done

if [ "${default_iface}" == "${BRIDGE_NAME}" ]; then
    echo "Bridge ${BRIDGE_NAME} seems to be already configured as the default interface, skipping the rest of network setup"
    exit 0
fi

echo "Applying node network configuration policy"
cat <<EOF | oc apply -f -
apiVersion: nmstate.io/v1alpha1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: kni-policy
spec:
  desiredState:
    interfaces:
    - name: ${BRIDGE_NAME}
      type: linux-bridge
      state: up
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

echo "Waiting until the configuration is done, it may take up to 5 minutes until keepalived gets reconfigured"
nodes=$(oc get nodes -o jsonpath='{range .items[*]}{.metadata.name} {end}')
for node in $nodes; do
    until [ "$(oc get nodenetworkstate ${node} -o jsonpath="{.status.currentState.routes.running[?(@.destination==\"${MACHINE_CIDR}\")].next-hop-interface}")" == "${BRIDGE_NAME}" ]; do sleep 10; done
done
oc wait node --all --for condition=Ready --timeout=10m
