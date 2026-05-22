Hello, i want you to read this file - which relate to the entire `master-oogway` project and to the `MASTER-OOGWAY-AUDIT.md` and `FEATURES.md` files.

this file was written by me. and i want you to go through this file and make the requested changes, answer my questions and give me explanations when i've asked for.
read one item at a time (some refer to other files, some just here) - and make the changes.

do not commit anything before i tell you to.

for each change:
* see the full explaination in the reffered file (or ask me if something isn't fully cleared).
* when the item is reffered to a file - after implementing or skipping an item - delete it from the file. i want each of the markdown files to contain only what is there left for us to do.
* delete the item from this TODO.md file as well.
* for every item - you can ask me up to 5 questions if you are not sure how i would want you to implement.
* if we finished a section but i didn't replay or reffered to some items in it - do tell me: 'hey, we finished with `MASTER-OOGWAY-AUDIT.md` file - but it seems you didnt give me instructions for Z, X, and Y. what would you want to do with these? skip it? implement?' 
* stop after each item. let me see the code and commit only when i tell you to.
* remember - the project root is here. `master-oogway` not any parent directory.

# FEATURES.md

## New Plugins
* `mkscript` - lets add it with only one arg: `mkscript /path/to/file` which creates it as a script then open it with $EDITOR.
* `clip` - i want a command that i could pipe a command output into, and it copies it into the clipboard. dont need those `clip`, `paste` or `clipfile` suggested. 
* `mo-secret-scan` dont need it.
* `mo-undo` dont need it.
* `mo-bench` dont need it.
* `mo-watch-files` dont need it.
* `mo-recipe` dont need it.
* `mo-bookmarks` dont need it.
* `mo-since` dont need it.
* `mo-context` dont need it.
* `mo-projects` - i think of better idea i want. if this plugin is loaded: every directory in `MO_PROJECTS_PROJ_DIR` (default to `~/projects/` (allow also with capital `P`)) gets its own alias. for example if i have directory `~/projects/foo` then `foo` would alias to `cd ~/projects/foo`. also - `p` would be run fzf search between all project directories allow me to choose which proj directory to enter. 
* `mo-emoji` dont need it.
* `mo-passphrase` dont need it.
* `mo-color` - great. lets add all the dragon colors by names to allow the user to print it. also - with piping into it, echo the text with the specified color. `color 0xff0080` prints `0xff0080` twice: once with BG color and one with FG color of the specified color (also works with dec colors and named colors!). `color palette` prints all 16 named colors (with their names), then all 256 colors with numbers (all with BG and FG). `color 0xff0080 0xf0f0f0` (or dec/named colors) would print the piped input with `0xff0080` fg and `0xf0f0f0` bg. if no pipe - prints `hello world`. if no bg is presented it should work with only fg.
* `mo-share` dont need it
* `mo-ssh-tunnel` - great idea. lets do it like this: `tunnel <host/ip>:<port> to <host/ip>:port`. using ssh -R or -L, depends on the sides: `tunnel momo:8989 to localhost:2020` would open 127.0.0.1:2020 and it would be tunneled into momo on port 8989. the host can be blank and it would be localhost. `tunnel 8080 to momo:9000` would open 9000 port on momo, tunneled to localhost 8080. `tunnel 9000 to 9001` and `tunnel momo:8700 to 0.0.0.0:9898` should work as well.
* `mo-vpn`: dont need it.
* `mo-pretty-curl`: dont need it.
* `mo-dnscheck`: dont need it.
* `mo-syslog`: dont need it.
* `mo-debug`: dont need it.
* `mo-trace`: dont need it.
* `mo-diff-dirs`: dont need it.
* `mo-largest/mo-disk`: dont need it.
* `mo-archive` with `compress` - great! if no archive-name given - create it with the directory name and create it in the pwd path.
* `mo-watch-cmd`: dont need it.
* `mo-pomodoro`: dont need it.

## Dragon Theme Features
* about 2.1 - explain better the plan.
* 2.8 - add new presets!
* 2.9 - lets do this
* 2.10 - lets do this

## Existing Plugins
* `groot` - cd to git root. if currently on git root - cd up to another root (it could be a submodule). i want another name `cdb=groot` (cdb = cd to base).
* `gtag` add it
* `gca` should be `git commit --amend` (without `--no-edit`).

# My new ideas

## `no-man`
another feature/plugin: `mo-man` for plugins that let the user view (less/batcat less) the README of the mo-plugin specified.
where can we add it? or create new plugin?

# Existing plugins

## zshrc
* comments aren't on the same TAB.
* make sure all comments are relevant. keep comments short which explains to the user what he need to know.
* add this in its place:
```zsh
typeset -A ZSH_HIGHLIGHT_PATTERNS
ZSH_HIGHLIGHT_PATTERNS+=(
    'sudo'             'fg=yellow,bold'
    '--force'          'fg=white,bg=yellow,bold'
    'rm -rf'           'fg=white,bg=red,bold'
    'rm -fr'           'fg=white,bg=red,bold'
    'shred'            'fg=white,bg=yellow,bold'
    'wipefs'           'fg=white,bg=yellow,bold'
    'git push --force' 'fg=white,bg=yellow,bold'
    'git reset --hard' 'fg=white,bg=yellow,bold'
)
```
* maybe there is a proper place for these? maybe in some plugin?
```zsh
# Resolve the actual binary name for bat and fd once at startup. Ubuntu's
# apt installs them as 'batcat' and 'fdfind' to avoid package conflicts;
# upstream and other distros use the short names. Unset at end of file.
typeset _mo_bat="" _mo_fd=""
if command -v bat    &>/dev/null; then _mo_bat="bat"
elif command -v batcat &>/dev/null; then _mo_bat="batcat"; fi
if command -v fd     &>/dev/null; then _mo_fd="fd"
elif command -v fdfind &>/dev/null; then _mo_fd="fdfind"; fi

# Use bat as the man-page renderer (col -bx strips overstrike chars).
[[ -n "$_mo_bat" ]] && export MANPAGER="sh -c \"col -bx | $_mo_bat -l man -p\""

export BAT_THEME='Coldark-Dark'   # `bat --list-themes` to see options

# ── tool initializations ───────────────────────────────────────────────────────
# Each block is guarded: if the tool isn't installed it is silently skipped.

# fzf options — tweak or remove to change fuzzy-finder appearance and behavior.
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
# Ctrl+T file picker: preview file contents with bat (falls back to cat if bat not installed).
if [[ -n "$_mo_bat" ]]; then
    export FZF_CTRL_T_OPTS="
  --preview '$_mo_bat --color=always --style=plain {} 2>/dev/null || cat {}'
  --preview-window=right:60%:wrap"
else
    export FZF_CTRL_T_OPTS="
  --preview 'cat {}'
  --preview-window=right:60%:wrap"
fi
# Use fd (or Ubuntu's fdfind) if installed — faster than find, respects .gitignore.
[[ -n "$_mo_fd" ]] && export FZF_DEFAULT_COMMAND="$_mo_fd --type f --hidden --strip-cwd-prefix --exclude .git"
unset _mo_bat _mo_fd
# Alt+C directory picker: eza tree preview, fallback to ls.
export FZF_ALT_C_OPTS="
  --preview 'eza --tree --color=always --level=2 {} 2>/dev/null || ls -la {}'
  --preview-window=right:50%:wrap"
```
* remove these, what are they even doing?
```zsh
# direnv: automatically loads/unloads .envrc files when you enter/leave a directory.
# Remove this line if you don't use direnv.
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# zoxide: a smarter cd that learns your most-used directories.
# Use 'z <partial-name>' instead of 'cd <full-path>'. Remove if not installed.
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
```

## mo-auto-ls
* the comments in the plugin file - consider write it in the readme.
* does `chpwd_functions` can contain the same function twice? if yes - is there a better way to make it unique?

## mo-bat-override
* there is a declaration of `_bat_cmd` in zshrc. is there something to do with this duplicated code?
* `--theme`: be dont need it, aren't we? there is `export BAT_THEME='Coldark-Dark'` in `zshrc`.
* lets make pless pretty and less like cat without the line-numbers.

## mo-build
* i want `m` to work with make arguments. like `m -C dir`, or `m all`.
* maybe we dont need to check of `nproc` every time we runs m. we can compute this on zsh loading, what do you say?
* if we have banner but no colormake..?

## mo-cli
* `master-oogway version` is the master-oogway version or dragon version?

## mo-dev
* i dont think that `calc`, `epoch`, `serve` and `md2pdf` actually should be placed together. think where to put each (in an existing plugin or new one.)

## mo-files
* some functions has `function` and some no. please to through the entire code and fix it.

## mo-git
* add `gac="git add ."`

## mo-navigation
* why navigation? if there is `mo-files`, shouldn't this be `mo-dirs`?
* `fcd` seems to not work. why?

## mo-shell-tools
* `vizsh` for some reason is allways red in zsh-syntax-highlighter
* what exactly is `zshtime`? it is not seems to work and always returns error code 1.

# Another Things
* for the plugins that override. does `r<command>` really needed? i think that the user would know to use `\<command>`. lets think about it.
* read the bash-scripting-conventions.md, then read the install and all bash scripts in this repo. dont make any changes - but write down to a file: are there anything to change on files in the repo? and - are there anything to change/add from the bash-scripting-conventions.md file itself?
* change the 'about' of this repo on GitHub to match the project.