.PHONY: all dist release lint check

all: dist

dist:
	./scripts/make-dist.sh

release:
	./scripts/make-release.sh

lint:
	sh -n installer/cybook_upgrade
	sh -n scripts/*.sh
	sh -n recovery/disable-koreader
	sh -n recovery/restore-stock
	@echo "shell syntax OK"

check:
	git diff --check
