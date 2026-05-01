.PHONY: lint test check

PLUGIN_ZSH := $(wildcard zsh-custom.d/plugins/af-*/**.plugin.zsh)
THEME_ZSH  := $(wildcard zsh-custom.d/themes/*.zsh)
CONFIGURE  := zsh-custom.d/appa-fino-configure.zsh

lint:
	bash -n install.sh
	zsh -n $(PLUGIN_ZSH) $(THEME_ZSH) $(CONFIGURE)
	shellcheck install.sh tests/check_schema.sh

test:
	bash tests/check_schema.sh

check: lint test
