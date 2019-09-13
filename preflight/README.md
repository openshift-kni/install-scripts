**Purpose:**

The Preflight script is designed to validate some environment settings on the appliance provisioning node before the cluster deployment is actually executed.  By pre-checking certain requirements the use of this script can mitigate the need to spend time on a deployment that might ultimate fail and need to be rerun.  Further the script produces a usable ironic\_hosts.json, install-config.yaml and config\_user.sh consumed by current methods of deployment: dev-scripts or install-scripts.

Dev-scripts: [https://github.com/openshift-metal3/dev-scripts](https://github.com/openshift-metal3/dev-scripts)

Install-scripts: [https://github.com/openshift-kni/install-scripts](https://github.com/openshift-kni/install-scripts)

**What Preflight Requires:**

The script requires that you feed it the Dell iDRAC IP addresses and the iDRAC username and password for the 3 master nodes and 1 worker node (the provisioning node is considered a worker node).   There is also a -d switch which allows for the use of the default idrac information the current appliance ships with in a standard configuration.   The script should be run from the provisioning node as a regular user with sudo.

**What Preflight Does:**

The script has multiple components and can be broken down into the following sections in order of execution:

- Discovers the long hostname and short hostname from the provisioning node
- Derives the cluster name and domain from the long hostname
- Builds an initial Ansible inventory file from the iDRAC information provided or using defaults
- Connects to each iDRAC via RedFISH and retrieves the MAC address information
- Connects to the master nodes iDRAC via RedFish and ensures they are powered off
- Validates that DNS records exist for (api|\*.apps|ns1).clustername.domain
- Adds MAC address information to Ansible inventory file
- Validates that DNS records for master nodes exist
- Uses Ansible to generate ironic\_hosts.json, config\_user.sh and install-config.yaml
- Insert pullsecret into install-config.yaml and config\_user.sh
- Inserts sshkey into install-config.yaml and config\_user.sh

**Future Preflight:**

The script might be altered in the future depending on what is required from the real OCP installer.

**Impediments:**

Currently the script relies on using whatever Dell hardware we have as official hardware is not yet in place.

