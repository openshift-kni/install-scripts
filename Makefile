
.PHONY: default all OpenShift OCS CNV prep

default: OpenShift OCS CNV bell

prep:
	set -e; pushd OpenShift; make pre_install; popd

OpenShift:
	set -e; pushd OpenShift; make; popd

OCS:
	set -e; pushd OCS; make; popd

CNV:
	set -e; pushd CNV; make; popd

bell:
	@echo "Done!" $$'\a'
