
.PHONY: default all OpenShift OCS CNV prep preflight appliance rhel deploy

default: appliance

appliance: preflight OpenShift CNV OCS bell

rhel: prep OpenShift CNV OCS bell

deploy: OpenShift CNV OCS bell

prep:
	set -e; pushd OpenShift; make pre_install; popd

preflight:
	set -e; pushd preflight; sudo ./preflight.sh -d -o; cp config_${USER}.sh install-config.yaml ../OpenShift/; popd

OpenShift:
	set -e; pushd OpenShift; make; popd

OCS:
	set -e; pushd OCS; make; popd

CNV:
	set -e; pushd CNV; make; popd

bell:
	@echo "Done!" $$'\a'
