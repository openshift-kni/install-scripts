
.PHONY: default all OpenShift OCS CNV prep

default: OpenShift OCS CNV bell

prep:
	pushd OpenShift; make pre_install; popd

OpenShift:
	pushd OpenShift; make; popd

OCS: OpenShift
	pushd OCS; make; popd

CNV: OpenShift
	pushd CNV; make; popd

bell:
	@echo "Done!" $$'\a'
