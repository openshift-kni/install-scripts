.PHONY: default all requirements configure
default: requirements configure

all: default

requirements:
	./01_install_requirements.sh

configure:
	./02_configure_host.sh

clean: host_cleanup

host_cleanup:
	./host_cleanup.sh

bell:
	@echo "Done!" $$'\a'
