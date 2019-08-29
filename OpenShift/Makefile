.PHONY: default all requirements configure create clean host_cleanup bell post_install
default: create bell

all: requirements configure create bell

requirements:
	./01_install_requirements.sh

configure:
	./02_configure_host.sh

create:
	./03_create_cluster.sh

post_install:
	./99_post_install.sh

clean: host_cleanup

host_cleanup:
	./host_cleanup.sh

bell:
	@echo "Done!" $$'\a'
