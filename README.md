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
* 4x Dell PowerEdge R640 nodes, each with 2x Mellanox 25G NICs, and 2x
  Mellanox ethernet switches, all in a 12U rack. 1 node is used as a
  "provisioning host", while the other 3 nodes are OpenShift control
  plane machines.

The goal of this repository is to provide scripts and tooling to ease
the initial installation and validation of one of these clusters.

The current target is OpenShift 4.2, OCS 4.2, and CNV 2.1. The scripts
will need to support both published releases and [pre-release versions
(#12)](https://github.com/openshift-kni/install-scripts/issues/12) of
each of these.

### Preparation

To ease installation, a [prepared ISO](https://github.com/openshift-kni/install-scripts/issues/20)
can be used to install the "provisioning host".  Using the prepared ISO addresses
the following: 

1. [Creates an admin user
   (#21)](https://github.com/openshift-kni/install-scripts/issues/21)
   with passwordless sudo on the provisioning host.
1. Ensure the provisioning host has all [required software
   installed](https://github.com/openshift-kni/install-scripts/blob/master/01_install_requirements.sh). 
   (#22)](https://github.com/openshift-kni/install-scripts/issues/22) -
   the [bare metal IPI network
   requirements](https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md#network-requirements)
   are a good example of environment requirements.
1. Apply any [configuration changes to the provisioning
   host](https://github.com/openshift-kni/install-scripts/blob/master/02_configure_host.sh)
   that are required for the OpenShift installer. For example,
   creating the `default` libvirt storage pool and the `baremetal` and
   `provisioning` bridges.

Note:  Optional scripts that handle the above prerequisites may be executed 
if not using the prepared ISO that handle the above.


### Installation and Validation

The deployment process will use scripts to perform the following on the configuration:

1. [Validate any environment requirements
(#22)](https://github.com/openshift-kni/install-scripts/issues/22) -
   the [bare metal IPI network
   requirements](https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md#network-requirements)
   are a good example of environment requirements.
1. [Prepare the node information
   (#19)](https://github.com/openshift-kni/install-scripts/issues/19)
   required for the [bare metal IPI
   install-config](https://github.com/openshift/installer/blob/master/docs/user/metal/install_ipi.md#install-config).
1. Launch the OpenShift installer and wait for the cluster
   installation to complete.
1. Complete some post-install configuration - including [machine/node
   linkage
   (#14)](https://github.com/openshift-kni/install-scripts/issues/14),
   and [configuring a tagged storage VLAN on the interface connected to the `Internal` network on
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
   a bridge on the `External` interface on OpenShift nodes
   (#18)](https://github.com/openshift-kni/install-scripts/issues/18)
   to allow VMs access this network.
1. Temporarily install Ripsaw, carry out some performance tests, and
   capture the results.




The following environment-specific information will be required for
each installation.  On a properly configured and prepared cluster,
the following items will be discovered:

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
1. If detected that the provisioning host is not sync with a time source, configure the 25G switch as a source via the DHCP service  on the `Storage` network. An optional script to set a source for the switch, will be provided. 

## Provisioning Host Setup

The provisioning host must be a RHEL-8 machine.

### For a host not installed using the ISO:
In the OpenShift subdirectory, create a copy of `config_example.sh` using the existing
user as part of the file name. For example, `config_<username>.sh`. Once the file has
been created, set the required PULL_SECRET variable within the shell script

To install some required packages, configure `libvirt`, `provisioning` and `baremetal` bridges, from the top directory:

```sh
make prep
```

### For all nodes, Create the cluster 
```sh
make OpenShift
```

Note:  
In order to increase the log level ouput of `openshift-install`, a `LOGLEVEL` environment variable can be used as:
```
export LOGLEVEL="debug"
make OpenShift
```


## Continer Native Virtualization (CNV)
The installation of CNV related operators is managed by a *meta operator*
called the [HyperConverged Cluster Operator](https://github.com/kubevirt/hyperconverged-cluster-operator) (HCO).
Deploying with the *meta operator* will launch operators for KubeVirt,
Containerized Data Imported (CDI), Cluster Network Addons (CNA),
Common templates (SSP), Node Maintenance Operator (NMO) and Node Labeller Operator.

### Deploy OCS via operator

_Coming Soon_


### Deploy the HCO through the OperatorHub

The HyperConverged Cluster Operator is listed in the Red Hat registry,
so you can go the rest of the way using the UI by clicking the *OperatorHub* tab
and selecting the HyperConverged Cluster Operator.

If you want to use the CLI, we provide the a [script](CNV/deploy-cnv.sh)
that automates all the steps to the point of having a fully functional
CNV deployment.



