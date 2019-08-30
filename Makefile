.PHONY: default all OpenShift OCS CNV
default: OpenShift bell

all: OpenShift OCS CNV bell

OpenShift:
	pushd OpenShift; make; popd

OCS: OpenShift
	pushd OCS; ./customize-ocs.sh; popd

CNV: OpenShift
	pushd CNV; ./deploy-cnv.sh; popd

bell:
	@echo "Done!" $$'\a'
