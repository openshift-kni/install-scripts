.PHONY: default all OpenShift OCS CNV
default: OpenShift bell

all: OpenShift OCS CNV bell

OpenShift:
	pushd OpenShift; make; popd

OCS: OpenShift
	pushd OCS; make; popd

CNV: OpenShift
	pushd CNV; make; popd

bell:
	@echo "Done!" $$'\a'
