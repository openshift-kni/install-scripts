# Container Native Virtualization Deployment

## CNV 2.1 for HTB
`cnv-2.1.0.sh` is a clone of `https://pkgs.devel.redhat.com/cgit/containers/hco-bundle-registry/tree/marketplace-qe-testing.sh?h=cnv-2.1-rhel-8`.

Variables:
```bash
# The Namespace and Version of CNV
TARGET_NAMESPACE="${TARGET_NAMESPACE:-openshift-cnv}"
CNV_VERSION="${CNV_VERSION:-2.1.0}"

RETRIES="${RETRIES:-10}"

# Registry Auth
QUAY_USERNAME
QUAY_PASSWORD
```

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
