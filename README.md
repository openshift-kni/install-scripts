# install-scripts
Installation scripts for OpenShift KNI clusters

## KubeVirt
The installation of KubeVirt related operators is managed by a 'meta operator'
called the [HyperConverged Cluster Operator](https://github.com/kubevirt/hyperconverged-cluster-operator) (HCO).
Deploying with the 'meta operator' will launch operators for KubeVirt,
Containerized Data Imported (CDI), Cluster Network Addons (CNA),
Common templates (SSP), KubeVirt Web UI, and Node Maintenance Operator (NMO).

#### Deploy the HCO through Marketplace
The HyperConverged Cluster Operator is listed in the Community Marketplace,
so you can go the rest of the way using the UI by clicking the 'OperatorHub' tab
and selecting the HyperConverged Cluster Operator.

If you want to use the CLI, run the following commands:
```bash
$ curl https://raw.githubusercontent.com/kubevirt/hyperconverged-cluster-operator/master/deploy/hco.yaml | kubectl create -f -
```

(Optional) The HCO's pod and API may not appear immediately.  If you want a
command to wait for the pod to be ready, run:
```bash
$ kubectl wait pod $(kubectl get pods -n kubevirt-hyperconverged | grep hyperconverged-cluster-operator | head -1 | awk '{ print $1 }') --for condition=Ready -n kubevirt-hyperconverged --timeout="360s"
```

Create the HCO's CR launching kubevirt and component operators:
```
$ kubectl create -f https://raw.githubusercontent.com/kubevirt/hyperconverged-cluster-operator/master/deploy/converged/crds/hco.cr.yaml
```
