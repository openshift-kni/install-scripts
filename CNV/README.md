# Container Native Virtualization Deployment

## Access to Developer & QE Content
To get access to downstream bundles, you need to be granted permission in quay.
If you see "Application not found" from this [quay application registry](https://quay.io/application/rh-osbs-operators/kubevirt-hyperconverged),
then fill out [this form](https://docs.google.com/spreadsheets/d/1OyUtbu9aiAi3rfkappz5gcq5FjUbMQtJG4jZCNqVT20/edit#gid=0) to get access.

## CNV 2.1 for HTB
`cnv-2.1.0.sh` is a clone of `https://pkgs.devel.redhat.com/cgit/containers/hco-bundle-registry/tree/marketplace-qe-testing.sh?h=cnv-2.1-rhel-8`.

Variables:
```bash
# The Namespace and Version of CNV
TARGET_NAMESPACE="${TARGET_NAMESPACE:-openshift-cnv}"
CNV_VERSION="${CNV_VERSION:-2.1.0}"

RETRIES="${RETRIES:-10}"

# Registry Auth
#
# Get your pull secret from: https://cloud.redhat.com/openshift/install#pull-secret
#   $ export TOKEN=$(cat <pull-secret-file> | jq -r .auths.\"quay.io\".auth)
# You can also get the token with a user and password
#   $ curl https://raw.githubusercontent.com/kubevirt/hyperconverged-cluster-operator/master/tools/token.sh | bash
TOKEN=$TOKEN
```

## Running vms with bridges

**IMPORTANT:** Due to https://bugzilla.redhat.com/show_bug.cgi?id=1732598 and https://github.com/intel/multus-cni/issues/325, it is required to replace the content on the file `/etc/kubernetes/cni/net.d/80-openshift-network.conf` with the following content:

```
{ "name": "openshift-sdn", "type": "multus", "namespaceIsolation": true, "logLevel": "verbose", "kubeconfig": "/etc/kubernetes/cni/net.d/multus.d/multus.kubeconfig", "delegates": [ { "cniVersion": "0.3.1", "name": "openshift-sdn", "type": "openshift-sdn" } ] }
```

This cannot be done via a machine-config because it is created by the `openshift-cni` pod and if the hosts are rebooted, the changes are lost.

The [fix-multus.sh](fix-multus.sh) script can be used as a temporary workaround

## Upgrade
`cnv-upgrade.sh` is a clone of `curl -k https://pkgs.devel.redhat.com/cgit/containers/hco-bundle-registry/plain/qe-upgrade.sh?h=cnv-2.1-rhel-8`.

Variables:
```bash
OLD_CNV_VERSION="${CNV_VERSION:-2.1.0}"
CNV_VERSION="${CNV_VERSION:-2.1.0}"

# The Namespace and Version of CNV
TARGET_NAMESPACE="${TARGET_NAMESPACE:-openshift-cnv}"
```
The expectation is that the $CNV_VERSION CSV file `replaces` the $OLD_CNV_VERSION's
CSV file.

## Debugging
```bash
# CNV pod status
oc get pods -n openshift-cnv
oc get hco -n openshift-cnv hyperconverged-cluster -o=jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.message}{"\n"}{end}'

# Marketplace Resources
oc get operatorsource -n openshift-marketplace
oc get catalogsourceconfig -n openshift-marketplace
oc get packagemanifest -n openshift-cnv
oc get pods -n openshift-marketplace

# OLM Resources
oc get sub -n openshift-cnv -o yaml
oc get catalogsource --all-namespaces
oc get installplan -n openshift-cnv

# Cluster
oc get clusterversion
```
