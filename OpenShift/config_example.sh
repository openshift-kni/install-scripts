#!/bin/bash

# Get a valid pull secret (json string) from
# You can get this secret from https://cloud.openshift.com/clusters/install#pull-secret
set +x
export PULL_SECRET=''
set -x

# Set to the interface used by the provisioning bridge
#PRO_IF="em1"

# Set to the interface used by the baremetal bridge
#INT_IF="em2"

# Add extra registry (as insecure) if needed, such as
#EXTRA_REGISTRY=registry.example.com

# Set loglevel for OpenShift installation
#LOGLEVEL=debug

# Avoid caching of the RHCOS image
#CACHE_IMAGES=false

# Configure custom ntp servers if needed
#NTP_SERVERS="00.my.internal.ntp.server.com;01.other.ntp.server.com"
