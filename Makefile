
.PHONY: default all OpenShift OCS CNV prep

default: OpenShift bell

all: OpenShift OCS CNV bell

prep:
	pushd OpenShift; make requirements; make configure; popd

OpenShift:
	pushd OpenShift; make; popd

OCS: OpenShift
	pushd OCS; ./customize-ocs.sh; popd

CNV: OpenShift
	pushd CNV; ./deploy-cnv.sh; popd

bell:
	@echo "Done!" $$'\a'
