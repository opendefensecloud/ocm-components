# Include ODC common make targets
DEV_KIT_VERSION := v1.0.11
-include common.mk
common.mk:
	@[ -f .common.mk-download ] || \
		curl --fail -sSL https://raw.githubusercontent.com/opendefensecloud/dev-kit/$(DEV_KIT_VERSION)/common.mk \
		  -o .common.mk-download
	mv .common.mk-download $@
	printf '%s' '$(DEV_KIT_VERSION)' > .common.mk-version
	touch .common.mk-checked

.PHONY: setup
setup: $(OCM)
