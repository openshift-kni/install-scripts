.PHONY: default all requirements configure
default: requirements configure

all: cluster post_install

requirements:
	./01_install_requirements.sh

configure:
	./02_configure_host.sh

pre_install: requirements configure

cluster:
	./03_create_cluster.sh

post_install:
	./99_post_install.sh

clean: host_cleanup

host_cleanup:
	./host_cleanup.sh

bell:
	@echo "Done!" $$'\a'
