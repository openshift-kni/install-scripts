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
