
.PHONY: default all OpenShift OCS CNV prep preflight appliance rhel deploy

default: appliance

appliance: preflight OpenShift OCS CNV bell

rhel: prep OpenShift OCS CNV bell

deploy: OpenShift OCS CNV bell

prep:
	set -e; pushd OpenShift; make pre_install; popd

preflight:
	pushd preflight
	sudo ./preflight -d
	cp config_${USERNAME}.sh install-config.yaml ../OpenShift/
	popd

OpenShift:
	set -e; pushd OpenShift; make; popd

OCS:
	set -e; pushd OCS; make; popd

CNV:
	set -e; pushd CNV; make; popd

bell:
	@echo "Done!" $$'\a'
