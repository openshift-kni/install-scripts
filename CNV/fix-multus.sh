#!/bin/sh
cat << EOF > 80-openshift-network.conf
{ "name": "openshift-sdn", "type": "multus", "namespaceIsolation": true, "logLevel": "verbose", "kubeconfig": "/etc/kubernetes/cni/net.d/multus.d/multus.kubeconfig", "delegates": [ { "cniVersion": "0.3.1", "name": "openshift-sdn", "type": "openshift-sdn" } ] }
EOF

for node in $(oc get nodes -o jsonpath="{.items[*].metadata.name}"); do
  scp 80-openshift-network.conf core@$node:/tmp/
  ssh core@$node "sudo mv /tmp/80-openshift-network.conf /etc/kubernetes/cni/net.d/80-openshift-network.conf"
done

echo "The multus changes will be lost if the hosts are rebooted"
