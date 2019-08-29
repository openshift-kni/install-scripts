.PHONY: default all requirements configure create
default: create

all: requirements configure

requirements:
	./01_install_requirements.sh

configure:
	./02_configure_host.sh

create:
	./03_create_cluster.sh

clean: host_cleanup

host_cleanup:
	./host_cleanup.sh

bell:
	@echo "Done!" $$'\a'
