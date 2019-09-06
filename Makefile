
.PHONY: default all OpenShift OCS CNV prep

default: OpenShift OCS CNV bell

prep:
	set -e; pushd OpenShift; make pre_install; popd

OpenShift:
	set -e; pushd OpenShift; make; popd

OCS: OpenShift
	set -e; pushd OCS; make; popd

CNV: OpenShift
	set -e; pushd CNV; make; popd

bell:
	@echo "Done!" $$'\a'
