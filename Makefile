# Include ODC common make targets
DEV_KIT_VERSION := v1.0.6
-include common.mk
common.mk:
	curl --fail -sSL https://raw.githubusercontent.com/opendefensecloud/dev-kit/$(DEV_KIT_VERSION)/common.mk -o common.mk.download && \
	mv common.mk.download $@

.PHONY: setup
setup: $(OCM)
