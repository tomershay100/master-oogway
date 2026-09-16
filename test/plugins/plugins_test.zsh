# Every plugin loads, parses, and its commands behave. Assertions that depend
# on the OS are branched, so this suite is meaningful on Linux and macOS alike.

_mo_t() {
	local plug="$1"; shift
	zsh -c "
		setopt EXTENDED_GLOB
		export ZSH_CUSTOM='$MO_ROOT/omz-custom'
		for f in '$MO_ROOT'/omz-custom/lib/*.zsh(#qN); do source \$f; done
		source '$MO_ROOT/omz-custom/plugins/$plug/$plug.plugin.zsh' 2>/dev/null
		$*
	" 2>&1
}

source "$MO_ROOT/omz-custom/lib/platform.zsh"

# ── every plugin parses and documents itself ─────────────────────────────────
local d n
for d in "$MO_ROOT"/omz-custom/plugins/mo-*(N/); do
	n="${d:t}"
	assert_ok "$n parses"     zsh -n "$d/$n.plugin.zsh"
	assert_ok "$n has README" test -f "$d/README.md"
done

# ── the platform-sensitive behaviour ─────────────────────────────────────────
assert_eq "1024" "$(_mo_t mo-shell-tools 'calc "2^10"')" "calc works"

assert_contains "$(_mo_t mo-shell-tools 'epoch --utc 1700000000')" "2023-11-14 22:13:20" \
	"epoch renders an epoch in UTC"
assert_eq "1700000000" "$(TZ=Asia/Jerusalem _mo_t mo-shell-tools "epoch --utc '2023-11-14 22:13:20'")" \
	"epoch parses an ISO datetime as UTC when asked"
assert_eq "1699992800" "$(TZ=Asia/Jerusalem _mo_t mo-shell-tools "epoch '2023-11-14 22:13:20'")" \
	"epoch parses a bare ISO datetime as local time"

# clip must actually reach the clipboard, not fall through to printing.
# Save and restore it: running the suite should not cost the tester whatever
# they had copied.
if _mo_clip_tool >/dev/null 2>&1; then
	local _saved_clip
	_saved_clip=$(_mo_paste 2>/dev/null)
	_mo_t mo-shell-tools "print -- clip-probe-$$ | clip" >/dev/null 2>&1
	assert_eq "clip-probe-$$" "$(_mo_paste)" "clip writes to the system clipboard"
	[[ -n "$_saved_clip" ]] && _mo_clip "$_saved_clip"
else
	t_skip "clip writes to the system clipboard" "no clipboard tool"
fi

assert_match "$(_mo_t mo-build '_mo_build_jobs_value')" '^[0-9]+$' "build job count is numeric"
assert_true "build uses more than one core" "$(_mo_t mo-build '_mo_build_jobs_value') > 1"

# extract, for both a GNU-flag-sensitive and a compressed-variant archive.
local td=$(mktemp -d); command mkdir -p "$td/s" "$td/o"; print -- hi > "$td/s/f.txt"
tar -czf "$td/a.tar.gz" -C "$td/s" f.txt
_mo_t mo-files "cd '$td/o' && extract '$td/a.tar.gz'" >/dev/null
assert_eq "hi" "$(command cat "$td/o/f.txt" 2>/dev/null)" "extract handles .tar.gz"
command rm -rf "$td"

# Search for a process this test starts, not for "zsh": a CI runner executing
# the suite non-interactively may have no other zsh alive, and pgrep would
# correctly find nothing.
() {
	local marker="mo-psgrep-probe-$$"
	sleep 30 &
	local probe=$!
	# pgrep matches the command line, so give it one we control.
	assert_contains "$(_mo_t mo-process "psgrep sleep")" "sleep" \
		"psgrep finds a running process by name"
	kill "$probe" 2>/dev/null
	wait "$probe" 2>/dev/null
}
assert_contains "$(_mo_t mo-git 'alias gs')" "git status" "git aliases load"

# ── difftool predicates ──────────────────────────────────────────────────────
# `gd` asks only "can it run"; diff-zshrc also asks "is it a GUI". They were one
# predicate with an `[[ -t 1 ]] && return 1` clause meant to serve both, which
# let a GUI through whenever stdout was NOT a terminal — so a piped `gd` opened
# FileMerge and hung. Every assertion below captures output, so stdout is a pipe
# here, which is exactly the condition that used to fail.
_mo_dt() {
	zsh -c "
		setopt EXTENDED_GLOB
		export ZSH_CUSTOM='$MO_ROOT/omz-custom'
		for f in '$MO_ROOT'/omz-custom/lib/*.zsh(#qN); do source \$f; done
		source '$MO_ROOT/omz-custom/plugins/mo-git/mo-git.plugin.zsh' 2>/dev/null
		source '$MO_ROOT/omz-custom/plugins/mo-cli/mo-cli.plugin.zsh' 2>/dev/null
		$*
	" >/dev/null 2>&1
}
assert_ok   "opendiff is a GUI"          _mo_dt '_mo_difftool_is_gui opendiff'
assert_ok   "meld is a GUI"              _mo_dt '_mo_difftool_is_gui meld'
assert_fail "vimdiff is not a GUI"       _mo_dt '_mo_difftool_is_gui vimdiff'
assert_fail "a missing tool is unusable" _mo_dt '_mo_difftool_usable mo-no-such-difftool'
assert_ok   "an installed tool is usable" _mo_dt '_mo_difftool_usable diff'
# The regression itself. A stub on PATH, not the real thing: asking about a tool
# this machine does not have is a vacuous test, since it is then refused for
# being absent no matter what the GUI logic does — which is exactly how the bug
# survived a green suite on a Mac without full Xcode. With the stub the tool IS
# runnable, so only the GUI rule can reject it.
# PATH is set around the calls, not with `env`: _mo_dt is a shell function, and
# env can only exec a binary — it failed, assert_fail saw a failing command and
# called that a pass. The paired assert_ok below exists to prove the stub really
# is on PATH, so the refusal above it cannot pass for the wrong reason.
_MO_DT_BIN=$(mktemp -d)
printf '#!/bin/sh\nexit 0\n' > "$_MO_DT_BIN/meld"; chmod +x "$_MO_DT_BIN/meld"
_MO_DT_PATH="$PATH"; PATH="$_MO_DT_BIN:$PATH"
assert_ok   "a stubbed GUI tool is runnable"       _mo_dt '_mo_difftool_usable meld'
assert_fail "diff-zshrc refuses a runnable GUI tool" _mo_dt '_mo_cli_difftool_usable meld'
PATH="$_MO_DT_PATH"
command rm -rf "$_MO_DT_BIN"
# difftool.<tool>.cmd decides which binary actually runs, so the GUI check must
# follow it: the shipped gitconfig sets `difftool.meld.cmd = meld "$LOCAL" ...`.
# Written from here rather than inside _mo_dt — the config text survives two
# layers of zsh -c quoting far less well than an environment variable does.
_MO_DT_CFG=$(mktemp)
printf '[difftool "x"]\n\tcmd = meld $LOCAL $REMOTE\n' > "$_MO_DT_CFG"
export GIT_CONFIG_GLOBAL="$_MO_DT_CFG" GIT_CONFIG_NOSYSTEM=1
assert_ok "a cmd pointing at a GUI is a GUI" _mo_dt '_mo_difftool_is_gui x'
unset GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM
command rm -f "$_MO_DT_CFG"

# mo-cli keeps its own copy of the GUI list for when mo-git is disabled, and the
# two copies disagreeing is the original bug: mo-cli called meld a GUI, mo-git
# did not, so `gd` opened it and diff-zshrc refused it. Assert they stay equal.
_MO_GUI_GIT=$(command grep -o 'opendiff|[a-z0-9|]*' \
	"$MO_ROOT/omz-custom/plugins/mo-git/mo-git.plugin.zsh" | head -1)
_MO_GUI_CLI=$(command grep -o 'opendiff|[a-z0-9|]*' \
	"$MO_ROOT/omz-custom/plugins/mo-cli/mo-cli.plugin.zsh" | head -1)
assert_contains "$_MO_GUI_GIT" "meld" "the GUI list was actually found"
assert_eq "$_MO_GUI_GIT" "$_MO_GUI_CLI" "mo-git and mo-cli agree on which tools are GUIs"

# ── mo-eza-override: what actually reaches eza ───────────────────────────────
# `ls` had no test of any kind, unit or e2e, despite carrying the workaround for
# two upstream eza changes whose failure modes are both silent. 0.18 gave
# --classify an optional value, so a bare -F swallows the path after it; 0.23
# made eza read path names from stdin when stdin is not a TTY and no operand was
# given, so in a script or a pipeline `ls` lists nothing, or blocks on a pipe
# that never closes. Both are decided by the argument vector, so a stub eza that
# records its arguments tests them on any machine, eza installed or not — and
# the stub also satisfies requirements.zsh, which otherwise refuses to load the
# plugin at all.
_MO_EZA_BIN=$(mktemp -d)
printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "$MO_EZA_ARGS"\n' > "$_MO_EZA_BIN/eza"
chmod +x "$_MO_EZA_BIN/eza"
_mo_eza_args() {
	local out; out=$(mktemp)
	MO_EZA_ARGS="$out" PATH="$_MO_EZA_BIN:$PATH" zsh -c "
		setopt EXTENDED_GLOB
		export ZSH_CUSTOM='$MO_ROOT/omz-custom'
		for f in '$MO_ROOT'/omz-custom/lib/*.zsh(#qN); do source \$f; done
		source '$MO_ROOT/omz-custom/plugins/mo-eza-override/mo-eza-override.plugin.zsh'
		_mo_eza_ls $1
	" </dev/null >/dev/null 2>&1
	command tr '\n' ' ' < "$out" | command sed 's/ $//'
	command rm -f "$out"
}
# The stub must be reachable, or every assertion below compares "" with "" and
# passes without testing anything.
assert_contains "$(_mo_eza_args '')" "classify" "the eza stub is on PATH"
assert_eq "--classify=auto ."            "$(_mo_eza_args '')"          "a bare ls passes an explicit operand"
assert_eq "--classify=auto -l ."         "$(_mo_eza_args '-l')"        "flags alone still get an operand"
assert_eq "--classify=auto somedir"      "$(_mo_eza_args 'somedir')"   "a path operand is not doubled"
assert_eq "--classify=auto -L 1 ."       "$(_mo_eza_args '-L 1')"      "an option value is not mistaken for a path"
assert_eq "--classify=auto --level=2 ."  "$(_mo_eza_args '--level=2')" "--opt=value carries its own value"
assert_eq "--classify=auto -- x"         "$(_mo_eza_args '-- x')"      "an operand after -- counts as one"
command rm -rf "$_MO_EZA_BIN"

# ── platform-specific expectations ───────────────────────────────────────────
if _mo_is_macos; then
	assert_eq "" "$(_mo_t mo-colorize-override 'alias ip 2>/dev/null')" \
		"no ip alias on macOS, which has no ip"
	assert_eq "" "$(_mo_t mo-colorize-override 'alias dmesg 2>/dev/null')" \
		"no dmesg alias on macOS, whose dmesg takes no --color"
	# NEVER `lan-ssh setup` here. It is not a query: it writes a SendEnv
	# stanza into the tester's ~/.ssh/config, installs a crontab entry and
	# tries to drop a file into /etc/ssh/sshd_config.d. An earlier version of
	# this assertion relied on macOS refusing the whole subcommand; when the
	# refusal was removed the test silently began configuring the machine it
	# was running on. `status` and `help` only read.
	assert_not_contains "$(_mo_t mo-cli 'master-oogway lan-ssh status' 2>&1)" \
		"not supported on macOS" "lan-ssh is available on macOS"
	assert_contains "$(_mo_t mo-cli 'master-oogway lan-ssh help' 2>&1)" "lan-ssh" \
		"lan-ssh help renders"
	# The one genuinely platform-specific piece: deriving the LAN CIDR without
	# iproute2. Format only — the value depends on the tester's network.
	assert_match "$(MO_LAN_SUBNET= bash -c '
		'"$(sed -n '/^detect_subnet()/,/^}$/p' "$MO_ROOT/omz-custom/plugins/mo-cli/lan_scan.sh")"'
		SUBNET=""; detect_subnet' 2>/dev/null)" \
		'^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$' \
		"lan_scan derives a CIDR subnet without iproute2"
	assert_contains "$(_mo_t mo-brew 'type bup')" "bup" "mo-brew loads on macOS"
else
	# whence -w, not `type`: zsh's `type` writes "bup not found" to STDOUT, so
	# redirecting stderr does not silence it and the empty-string expectation
	# could never hold. whence -w prints nothing and returns 1 when undefined.
	assert_fail "mo-brew declines on Linux" _mo_t mo-brew 'whence -w bup'
	assert_not_contains "$(_mo_t mo-brew 'whence -w bup')" "function" \
		"mo-brew defines no bup function on Linux"
fi

assert_contains "$(_mo_t mo-colorize-override 'alias grep')" "--color=auto" "grep is colorized"

# ── no plugin may hardcode a package manager ─────────────────────────────────
# The exemption is per LINE, not per file. Testing whether the file mentions
# "platform-lint:" anywhere exempted the whole of lan_scan.sh the moment it
# gained its first waiver, so its `sudo apt install nmap` stopped being
# checked — this assertion passed vacuously.
assert_eq "" "$(command grep -rn 'sudo apt install' $MO_ROOT/omz-custom/plugins/mo-*/ 2>/dev/null \
	| while IFS=: read -r file line _; do
		# Waived on the line itself or within the three lines above it, the
		# same window test/lint_platform.zsh uses.
		start=$(( line > 3 ? line - 3 : 1 ))
		command sed -n "${start},${line}p" "$file" 2>/dev/null \
			| command grep -q 'platform-lint: allow' || print -r -- "${file}:${line}"
	done)" \
	"no plugin hardcodes apt outside a line-level waiver"
