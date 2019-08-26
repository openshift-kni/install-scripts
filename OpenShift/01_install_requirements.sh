#!/usr/bin/env bash
set -ex

source ../common/logging.sh

# FIXME: include checks from common.sh, see https://github.com/openshift-metal3/dev-scripts/issues/727

# Update to latest packages first
sudo yum -y update

# Note: we're leaving SELinux in enforcing mode
# Note: we're not enabling EPEL

# Install required packages
sudo yum -y install \
  curl \
  nmap \
  jq \
  wget

# FIXME: using deprecated network-scripts needed for NM_CONTROLLED=no
# interfaces on RHEL-8
sudo yum install -y network-scripts

sudo yum -y install \
  libvirt \
  libvirt-daemon-kvm

# Install oc client
oc_version=4.2
oc_tools_dir=$HOME/oc-${oc_version}
oc_tools_local_file=openshift-client-${oc_version}.tar.gz
oc_date=0
if which oc 2>&1 >/dev/null ; then
    oc_date=$(date -d $(oc version -o json  | jq -r '.clientVersion.buildDate') +%s)
fi
if [ ! -f ${oc_tools_dir}/${oc_tools_local_file} ] || [ $oc_date -lt 1559308936 ]; then
  mkdir -p ${oc_tools_dir}
  cd ${oc_tools_dir}
  wget https://mirror.openshift.com/pub/openshift-v4/clients/oc/${oc_version}/linux/oc.tar.gz -O ${oc_tools_local_file}
  tar xvzf ${oc_tools_local_file}
  sudo cp oc /usr/local/bin/
fi
