# OpenShift Container Storage Deployment

The manifests in this directory capture configuration choices for
deploying a Ceph cluster using OpenShift Container Storage (OCS).

NOTE: Rook assets will be deployed in the `openshift-storage` namespace in order to the dashboard to show graphs, and the cluster name shall be the same.

See https://github.com/rook/rook/issues/3344 for more information.

Execute `./deploy-ocs.sh`
