.PHONY: lint test check readme

PLUGIN_ZSH := $(wildcard zsh-custom.d/plugins/mo-*/**.plugin.zsh)
THEME_ZSH  := zsh-custom.d/themes/dragon.zsh-theme \
              $(wildcard zsh-custom.d/themes/*.zsh) \
              $(wildcard zsh-custom.d/themes/parts/*.zsh)
CONFIGURE  := zsh-custom.d/dragon-configure.zsh
NOTIFIER   := dragon-notifier.zsh

lint:
	bash -n install.sh
	zsh -n $(PLUGIN_ZSH) $(THEME_ZSH) $(CONFIGURE) $(NOTIFIER)
	shellcheck install.sh tests/check_schema.sh

test:
	bash tests/check_schema.sh

check: lint test

readme:
	bash scripts/gen_readme.sh
