# install-scripts
Installation scripts for OpenShift KNI clusters

## What's going on here?

KNI clusters consist of:

* OpenShift deployed on physical hardware using OpenShift's [bare
  metal
  IPI](https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md)
  platform based on [Metal³](http://metal3.io/).
* OpenShift Container Storage (OCS) based on [Ceph
  Rook](https://rook.io/) and using the [OCS
  Operator](https://github.com/openshift/ocs-operator).
* Container Native Virtualization (CNV) based on
  [KubeVirt](https://kubevirt.io/) and using the [Hyperconverged
  Cluster Operator
  (HCO)](https://github.com/kubevirt/hyperconverged-cluster-operator).
* 4x Dell PowerEdge R640 nodes, each with 2x Mellanox NICs, and 2x
  Mellanox ethernet switches, all in a 12U rack. 1 node is used as a
  "provisioning host", while the other 3 nodes are OpenShift control
  plane machines.

The goal of this repository is to provide scripts and tooling to ease
the initial installation and validation of one of these clusters.

The current target is OpenShift 4.2, OCS 4.2, and CNV 2.1. The scripts
will need to support both published releases and [pre-release versions
(#12)](https://github.com/openshift-kni/install-scripts/issues/12) of
each of these.

The scripts will:

1. [Creates an admin user
   (#21)](https://github.com/openshift-kni/install-scripts/issues/21)
   with passwordless sudo on the provisioning host.
1. Ensure the provisioning host has all [required software
   installed](https://github.com/openshift-kni/install-scripts/blob/master/01_install_requirements.sh). This
   script will also be used to [prepare an ISO image
   (#20)](https://github.com/openshift-kni/install-scripts/issues/20)
   to speed up this part of the installation process.
1. [Validate any environment requirements
   (#22)](https://github.com/openshift-kni/install-scripts/issues/22) -
   the [bare metal IPI network
   requirements](https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md#network-requirements)
   are a good example of environment requirements.
1. Apply any [configuration changes to the provisioning
   host](https://github.com/openshift-kni/install-scripts/blob/master/02_configure_host.sh)
   that are required for the OpenShift installer - for example,
   creating the `default` libvirt storage pool and the `baremetal` and
   `provisioning` bridges.
1. [Prepare the node information
   (#19)](https://github.com/openshift-kni/install-scripts/issues/19)
   required for the [bare metal IPI
   install-config](https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md#install-config).
1. Launch the OpenShift installer and wait for the cluster
   installation to complete.
1. Complete some post-install configuration - including [machine/node
   linkage
   (#14)](https://github.com/openshift-kni/install-scripts/issues/14),
   and [configuring a storage VLAN on the `provisioning` interface on
   the OpenShift nodes
   (#4)](https://github.com/openshift-kni/install-scripts/issues/4).
1. [Deploy OCS
   (#7)](https://github.com/openshift-kni/install-scripts/issues/7)
   and [configure a Ceph cluster and
   StorageClass](https://github.com/openshift-kni/install-scripts/blob/master/OCS/customize-ocs.sh). [Configure
   the image registry to use an OCS PVC
   (#5)](https://github.com/openshift-kni/install-scripts/issues/5)
   for image storage.
1. [Deploy
   CNV](https://github.com/openshift-kni/install-scripts/blob/master/CNV/deploy-cnv.sh). [Configure
   a bridge on the `baremetal` interface on OpenShift nodes
   (#18)](https://github.com/openshift-kni/install-scripts/issues/18)
   to allow VMs access this network.
1. Temporarily install Ripsaw, carry out some performance tests, and
   capture the results.

The following environment-specific information will be required for
each installation:

1. A pull secret - used to access OpenShift content - and an SSH key
   that will be used to authenticate SSH access to the control plane
   machines.
1. The cluster name and the domain name under which it will be
   available.
1. The network CIDR in which the machines will be allocated IPs on the
   `baremetal` network interface.
1. The [3 IP addresses
   reserved](https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md#network-requirements)
   for API, Ingress, and DNS access.
1. The BMC IPMI addresses and credentials for the 3 control plane
   machines.
1. Optionally, a Network Time Protocol (NTP) server where the default
   public server is not accessible

## Provisioning Host Setup

The provisioning host must be a RHEL-8 machine.

Make a copy of `config_example.sh` and set the required variables in
there.

To install some required packages and the `oc` client:

```sh
make requirements
```

Note:

1. This ensures that a recent 4.2 build of `oc` is installed. The
   minimum required version is hardcoded in the script.

To configure libvirt, and prepare the `provisioning` and `baremetal`
bridges:

```sh
make configure
```

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
