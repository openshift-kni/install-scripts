#!/bin/bash

export bridge="${bridge:-brext}"

set -e

echo "Deploying Bridge ${bridge}..."
  
FIRST_MASTER=$(oc get node -o custom-columns=IP:.status.addresses[0].address --no-headers | head -1)
export interface=$(ssh -q core@$FIRST_MASTER "ip r | grep default | grep -Po '(?<=dev )(\S+)'")
if [ "$interface" == "" ] ; then
  echo "Issue detecting interface to use! Leaving..."
  exit 1
fi

if [ "$interface" != "$bridge" ] ; then
  echo "Using interface $interface"
  export interface_content=$(envsubst < ifcfg-interface | base64 -w0)
  export bridge_content=$(envsubst < ifcfg-bridge | base64 -w0)
  envsubst < 99-brext-master.yaml | oc create -f -
  echo "Waiting 30s for machine-config change to get applied..."
  # This sleep is required because the machine-config changes are not immediate
  sleep 30
  echo "Waiting for bridge to be deployed on all the nodes..."
  # The while is required because in the process of rebooting the hosts, the
  # oc wait connection is lost a few times, which is normal
  while ! oc wait mcp/master --for condition=updated --timeout 900s ; do sleep 1 ; done
  echo "Done installing Bridge!"
else
  echo "Bridge already there!"
fi
