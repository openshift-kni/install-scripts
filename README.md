# install-scripts
Installation scripts for OpenShift KNI clusters

## CNV
The CNV installation is managed by a 'meta operator' called the [HyperConverged
Cluster Operator](https://github.com/kubevirt/hyperconverged-cluster-operator) (HCO).
Deploying with the 'meta operator' will launch operators for KubeVirt,
Containerized Data Imported (CDI), Cluster Network Addons (CNA),
Common templates (SSP), KubeVirt Web UI, and Node Maintenance Operator (NMO).

#### Deploy without OLM
```bash
$ curl https://raw.githubusercontent.com/kubevirt/hyperconverged-cluster-operator/master/deploy/deploy.sh | bash
```

#### Deploy CNV through Marketplace
```bash
$ curl https://raw.githubusercontent.com/kubevirt/hyperconverged-cluster-operator/master/tools/quay-registry.sh | CLUSTER=OPENSHIFT bash -s $QUAY_USERNAME $QUAY_PASSWORD
```

After pointing Marketplace at the new app registry, you can go the rest of the
way using the UI by finding KubeVirt Hyperconverged Cluster Operator in the
OperatorHub tab.

If you want to use the CLI, run the following commands:

```bash
# Create a namespace for CNV
kubectl create ns kubevirt-hyperconverged

# Switch to the HCO namespace.
kubectl config set-context $(kubectl config current-context) --namespace=kubevirt-hyperconverged

# Create an OperatorGroup
cat <<EOF | kubectl create -f -
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: hco-operatorgroup
  namespace: kubevirt-hyperconverged
EOF

# Subscribe to the HCO
cat <<EOF | kubectl create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hco-subscription
  namespace: kubevirt-hyperconverged
spec:
  channel: alpha
  name: kubevirt-hyperconverged
  source: hco-catalogsource
  sourceNamespace: openshift-operator-lifecycle-manager
EOF

# Wait for the HCO to appear
oc wait pod $(oc get pods -n kubevirt-hyperconverged | grep hyperconverged-cluster-operator | head -1 | awk '{ print $1 }') --for condition=Ready -n kubevirt-hyperconverged --timeout="${POD_TIMEOUT}"

# Create HCO's CR
kubectl create -f https://raw.githubusercontent.com/kubevirt/hyperconverged-cluster-operator/master/deploy/converged/crds/hco.cr.yaml
```
