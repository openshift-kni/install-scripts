.PHONY: default all OpenShift OCS CNV
default: OpenShift bell

all: OpenShift OCS CNV bell

OpenShift:
	pushd OpenShift; make; popd

OpenShift-virt:
	pushd OpenShift; make pre_install; make all; popd

OCS: OpenShift
	pushd OCS; make; popd

CNV: OpenShift
	pushd CNV; make; popd

bell:
	@echo "Done!" $$'\a'
