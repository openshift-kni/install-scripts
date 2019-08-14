# Container Native Virtualization Deployment

## What does it do

The script [deploy-cnv.sh](deploy-cnv.sh) deploys *CNV 2.0* through [OLM](https://github.com/operator-framework/operator-lifecycle-manager), meaning that:

* It creates a resource *Subscription* which triggers the deployment of all the operators that are required for CNV to work
* Waits for the operator pods to be ready
* Creates the custom resource *HyperConverged*, which makes the operators to deploy all their components and register the provided resources for them to be available (apiservices, CRDs, ...)
* Finally, waits for the new pods to be ready and CNV to be ready to be used
