.PHONY: lint test check readme update-submodules

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

# Pull each submodule to its upstream HEAD, run make check, then stage the
# updated commit pointers for a manual commit.  Keeps submodules at a tested
# known-good state rather than silently drifting on the next git pull.
update-submodules:
	git submodule update --remote --merge
	$(MAKE) check
	git add master-oogway-omz-custom/plugins/gitstatus \
	         master-oogway-omz-custom/plugins/you-should-use \
	         master-oogway-omz-custom/plugins/zsh-autosuggestions \
	         master-oogway-omz-custom/plugins/zsh-syntax-highlighting
	@echo ""
	@echo "Submodules updated and make check passed."
	@echo "Review the diff, then: git commit -m 'chore: pin submodules to latest tested versions'"
