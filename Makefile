.PHONY: lint test check readme

PLUGIN_ZSH := $(wildcard master-oogway-omz-custom/plugins/mo-*/**.plugin.zsh)
THEME_ZSH  := master-oogway-omz-custom/themes/dragon.zsh-theme \
              $(wildcard master-oogway-omz-custom/dragon/*.zsh) \
              $(wildcard master-oogway-omz-custom/dragon/parts/*.zsh)
CONFIGURE  := master-oogway-omz-custom/dragon/configure.zsh
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
