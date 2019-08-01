# install-scripts
Installation scripts for OpenShift KNI clusters

## Continer Native Virtualization (CNV)
The installation of CNV related operators is managed by a *meta operator*
called the [HyperConverged Cluster Operator](https://github.com/kubevirt/hyperconverged-cluster-operator) (HCO).
Deploying with the *meta operator* will launch operators for KubeVirt,
Containerized Data Imported (CDI), Cluster Network Addons (CNA),
Common templates (SSP), Node Maintenance Operator (NMO) and Node Labeller Operator.

### Deploy the HCO through the OperatorHub

The HyperConverged Cluster Operator is listed in the Red Hat registry,
so you can go the rest of the way using the UI by clicking the *OperatorHub* tab
and selecting the HyperConverged Cluster Operator.

If you want to use the CLI, we provide the a [script](CNV/deploy-cnv.sh)
that automates all the steps to the point of having a fully functional
CNV deployment.
