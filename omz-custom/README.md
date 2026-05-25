# omz-custom — `$ZSH_CUSTOM` directory

This directory is master-oogway's `$ZSH_CUSTOM`. oh-my-zsh sources files
from here at shell startup. There is no need to interact with this
directory directly — everything is wired up by [`zshrc.master-oogway`](../zshrc.master-oogway).

## Layout

```text
themes/
  dragon.zsh-theme       OMZ entry point (one-line shim sourced by oh-my-zsh)
  dragon/                all dragon theme code
    dragon.zsh             theme entry — defaults loop, hook registration
    schema.zsh             _DRAGON_DEFAULTS — single source of truth for vars
    configure.zsh          interactive wizard (`dragon-configure`)
    aliases.zsh            rezsh, reset_theme_variables
    parts/                 segment renderers, prompt assembly, gitstatus glue
plugins/
  mo-*/                  25 master-oogway plugins (6 overrides + 19 additive)
  gitstatus/             vendored: gitstatus (submodule)
  you-should-use/        vendored: you-should-use (submodule)
  zsh-autosuggestions/   vendored: zsh-autosuggestions (submodule)
  zsh-syntax-highlighting/  vendored: zsh-syntax-highlighting (submodule)
```

## See also

- User-facing reference: [../README.md](../README.md) — every command, every flag,
  every theme variable.
- Contributor guide: [../CONTRIBUTING.md](../CONTRIBUTING.md) — how to add a
  plugin, a theme variable, or modify the prompt.
- Theme configuration: `dragon-configure --help` — all subcommands.
