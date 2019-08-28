.PHONY: default all deploy upgrade

default: deploy

all: deploy

deploy:
	./cnv-2.1.0.sh
	./configure-network.sh

upgrade:
	./cnv-upgrade.sh
