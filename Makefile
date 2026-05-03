.PHONY: lint test check readme

PLUGIN_ZSH := $(wildcard omz-custom/plugins/mo-*/**.plugin.zsh)
THEME_ZSH  := omz-custom/themes/dragon.zsh-theme \
              $(wildcard omz-custom/themes/dragon/*.zsh) \
              $(wildcard omz-custom/themes/dragon/parts/*.zsh)
CONFIGURE  := omz-custom/themes/dragon/configure.zsh
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
