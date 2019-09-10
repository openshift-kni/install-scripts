
.PHONY: default all OpenShift OCS CNV prep preflight appliance rhel deploy

default: appliance

appliance: preflight OpenShift OCS CNV bell

rhel: prep OpenShift OCS CNV bell

deploy: OpenShift OCS CNV bell

prep:
	set -e; pushd OpenShift; make pre_install; popd

preflight:
	set -e; pushd preflight; sudo ./preflight.sh -d; ../common/ask.sh "Continue with displayed values" ; cp config_${USER}.sh install-config.yaml ../OpenShift/; popd

OpenShift:
	set -e; pushd OpenShift; make; popd

OCS:
	set -e; pushd OCS; make; popd

CNV:
	set -e; pushd CNV; make; popd

bell:
	@echo "Done!" $$'\a'
