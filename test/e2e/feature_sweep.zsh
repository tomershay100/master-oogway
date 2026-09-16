# End-to-end feature sweep, run inside a real installed login shell.
typeset -gi PASS=0 FAIL=0 SKIP=0
typeset -ga FAILED=()

# macOS has no timeout(1); perl's alarm is always present.
#
# MO_WELCOME_FIELDS= in the child's ENVIRONMENT, not in the command: mo-welcome
# prints its banner when the plugin is sourced, so setting the variable inside
# the command runs far too late. Without this every nested shell prefixes its
# output with the banner, which silently defeats any anchored assertion — and
# made an empty needle look like a reasonable choice in the first place.
# TERM: a CI runner starts with none, and anything calling tput at shell
# startup then writes "tput: No value for $TERM and no -T specified" to stderr,
# which 2>&1 folds into the captured output and defeats anchored matches.
# Startup warnings are filtered out of the capture, not out of the shell.
#
# A plugin whose hard dependency is missing prints "[mo-x] missing: ... —
# plugin not loaded" to stderr at every shell start, by design. 2>&1 then folds
# that line onto the front of EVERY assertion's output, so on any machine
# lacking one optional tool a large share of the suite fails for a reason that
# has nothing to do with what is being tested. Dropping just those lines keeps
# real stderr — the error messages several checks assert on — intact.
#
# Output goes through a temp file rather than straight into the caller's $(...).
# The alarm kills the shell it started, but not that shell's children: `gd` with
# a GUI difftool configured left FileMerge running, and the orphan held the write
# end of the capture pipe, so the substitution kept blocking long after the shell
# was dead. That turned a 15-second bound into a 15-minute CI hang. An orphan
# that inherits a temp file blocks nobody.
_t() {
	local _out _rc
	_out=$(mktemp)
	perl -e 'alarm shift; exec @ARGV' "$1" \
		env MO_WELCOME_FIELDS= ZSH_DISABLE_COMPFIX=true TERM="${TERM:-xterm-256color}" \
		"${@:2}" >"$_out" 2>&1
	_rc=$?
	command cat "$_out"
	command rm -f "$_out"
	return $_rc
}

# Drop shell-startup noise from a captured string.
#
# A plugin whose hard dependency is missing prints "[mo-x] missing: ... — plugin
# not loaded" to stderr at every shell start, by design, and 2>&1 folds it onto
# the front of every capture — so on a machine lacking one optional tool a large
# share of the suite fails for a reason unrelated to what is tested. Applied
# here rather than inside _t: piping there would make _t return grep's status
# instead of the command's, which silently inverted every checkrc that expects
# a failure.
_strip_noise() {
	# Match the stable middle of the message, not its bracketed prefix. The
	# warning is emitted with `print -P "%F{yellow}[mo-x]%f missing: ..."`, so
	# an ANSI escape sits between the closing bracket and " missing:" and a
	# pattern requiring them adjacent never matches.
	command grep -vE 'missing: .*plugin not loaded' \
	| command grep -vE 'Insecure completion-dependent directories' \
	| command grep -vE '^\[oh-my-zsh\]'
}

ok()   { print -r -- "  \e[32mPASS\e[0m  $1"; (( PASS++ )) }
bad()  { print -r -- "  \e[31mFAIL\e[0m  $1${2:+  — $2}"; (( FAIL++ )); FAILED+=("$1") }
skip() { print -r -- "  \e[33mSKIP\e[0m  $1${2:+  — $2}"; (( SKIP++ )) }

# check <label> <expected-substring> <command...>
# check <label> <expected-substring> <command...>
#
# An empty needle matches every string, including "command not found", so it
# turns an assertion into a no-op. Refuse it: use checkmatch for a shape, or
# checkrc when only the status matters.
check() {
	local label="$1" want="$2"; shift 2
	if [[ -z "$want" ]]; then
		bad "$label" "empty needle — use checkmatch or checkrc"
		return
	fi
	local out; out=$(_t 15 zsh -ic "$*" 2>&1 | _strip_noise)
	if [[ "$out" == *"$want"* ]]; then ok "$label"
	else bad "$label" "got: ${${out//$'\n'/ | }[1,90]}"; fi
}

# checkmatch <label> <ere> <command...> — for output whose exact text depends
# on the machine but whose shape does not.
checkmatch() {
	local label="$1" re="$2"; shift 2
	local out; out=$(_t 15 zsh -ic "$*" 2>&1 | _strip_noise)
	if [[ "$out" =~ $re ]]; then ok "$label"
	else bad "$label" "got: ${${out//$'\n'/ | }[1,90]}"; fi
}
# checkrc <label> <expected-rc> <command...>
checkrc() {
	local label="$1" want="$2"; shift 2
	_t 15 zsh -ic "$*" >/dev/null 2>&1
	local rc=$?
	[[ "$rc" == "$want" ]] && ok "$label" || bad "$label" "rc=$rc want=$want"
}

SB=$(mktemp -d); trap 'command rm -rf "$SB"' EXIT

print -r -- "\n\e[1m── theme & shell ──\e[0m"
check "dragon theme loaded"        "dragon"  'print -- $ZSH_THEME'
checkrc "PROMPT is non-empty"      0         '[[ -n "$PROMPT" ]]'
check "lib/*.zsh sourced"          "function" 'type -w _mo_clip'

print -r -- "\n\e[1m── mo-shell-tools ──\e[0m"
check "calc"                       "1024"        'calc "2^10"'
check "calc rejects injection"     "invalid"     'calc "foo;rm" 2>&1'
checkmatch "epoch now"             '^[0-9]{10}$'  'epoch'
check "epoch ts -> date"           "2023-11-14"  'epoch --utc 1700000000'
# Pin TZ. The earlier form asserted 1699992800, which is only the UTC+2
# reading — it failed on the UTC CI runners and for any contributor outside
# that zone. This is the same mistake the unit suite was just fixed for.
check "epoch ISO -> ts (--utc)"    "1700000000"  "TZ=Asia/Jerusalem epoch --utc '2023-11-14 22:13:20'"
check "epoch ISO -> ts (local)"    "1699992800"  "TZ=Asia/Jerusalem epoch '2023-11-14 22:13:20'"
checkmatch "epoch relative"        '^[0-9]{10}$'  'epoch yesterday'
checkrc "epoch rejects gibberish"  1             'epoch "not a date"'
# _mo_paste, not pbpaste: the Linux branch uses wl-paste/xclip, and a headless
# runner has neither, so the check is skipped rather than failed there.
if _mo_clip_tool >/dev/null 2>&1; then
	check "clip -> clipboard"      "e2e-$$"      "print -n e2e-$$ | clip >/dev/null; _mo_paste"
else
	skip "clip -> clipboard" "no clipboard tool (headless?)"
fi
check "mo-where finds calc"        "mo-shell-tools" 'mo-where calc'
check "mo-where finds indented rm" "mo-trash"    'mo-where rm'
checkrc "mo-where rc=0 on hit"     0             'mo-where calc'
# cwhich renders a command's file: bat prints a header naming the path, plain
# cat prints the bytes — and for a binary those bytes are not assertable. Test
# the contract that holds either way: it succeeds for a real command and fails
# for one that has no file.
checkrc "cwhich succeeds for a real command" 0 'cwhich git >/dev/null'
checkrc "cwhich fails for a missing command" 1 'cwhich no-such-command-9271'


print -r -- "\n\e[1m── mo-files ──\e[0m"
check "compress .tar.gz"  "Created"   "cd $SB && mkdir -p s && echo hi > s/f.txt && compress a.tar.gz s"
check "extract .tar.gz"   "hi"        "cd $SB && mkdir -p o && cd o && tar -czf x.tar.gz -C ../s f.txt && extract x.tar.gz && cat f.txt"
# A zip whose entry really is ../evil — `zip` refuses to store one, so the
# path is rewritten in the archive bytes after the fact.
if python3 -c 'import zipfile' 2>/dev/null; then
	python3 - "$SB" <<'PYZ' 2>/dev/null
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1] + "/trav.zip", "w")
z.writestr("../evil.txt", "x")
z.close()
PYZ
	check "extract refuses traversal" "refusing" "cd $SB && extract trav.zip 2>&1 | head -1"
else skip "extract refuses traversal" "python3 absent"; fi
check "bak"               "->"        "cd $SB && bak s/f.txt"
check "sizeof"            "f.txt"     "cd $SB && sizeof s/f.txt"
# mo-bat-override ships disabled, so `cat` is the system cat unless it is
# turned on. Source it explicitly to exercise the -A translation.
# batcat too: Debian and Ubuntu ship bat under that name, and every consumer in
# the tree falls back to it — mo-bat-override, mo-search, mo-files,
# mo-shell-tools and mo-man all check both. Probing only for "bat" skipped this
# on the one platform where the fallback is what is being exercised, so
# installing the recommended package left the check silently not running.
if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
	check "cat -A (BSD -vet)" 'b$' \
		"source \$ZSH_CUSTOM/plugins/mo-bat-override/mo-bat-override.plugin.zsh 2>/dev/null; cd $SB && printf 'a\tb\n' > tab.txt && cat -A tab.txt"
else skip "cat -A" "bat absent"; fi

print -r -- "\n\e[1m── mo-git ──\e[0m"
(cd "$SB" && git init -q r && cd r && git config user.email t@e && git config user.name T && echo a > f && git add f && git commit -qm one && echo b >> f && git add f && git commit -qm two) 2>/dev/null
check "git aliases load"  "git status" 'alias gs'
check "glc graph log"     "two"        "cd $SB/r && glc | head -1"
check "gsum"              "branch"     "cd $SB/r && gsum"
checkrc "gsum rc=0 clean" 0            "cd $SB/r && gsum"
# NOT opendiff: on a Mac with full Xcode that tool is genuinely usable, so `gd`
# correctly launches FileMerge — which on a CI runner is a window nobody closes.
# This asserts the fallback, so it needs a tool that cannot run anywhere.
check "gd falls back to git diff" "diff --git" "cd $SB/r && git config diff.tool mo-no-such-difftool && gd HEAD~1 HEAD"
check "groot"             "/r"         "cd $SB/r && mkdir -p a/b && cd a/b && groot && pwd"
checkrc "flog outside repo rc=1" 1     'cd /tmp && flog'

print -r -- "\n\e[1m── mo-dirs / mo-projects / mo-mkscript ──\e[0m"
check "mkcd"     "deep"    "cd $SB && mkcd deep/nest && pwd"
check "up N"     "$SB"     "cd $SB/deep/nest && up 2 && pwd"
check "tmpcd"    "/"       'tmpcd'
check "mkscript" "Created" "cd $SB && EDITOR=true mkscript ./s.sh"
checkrc "mkscript no-arg rc=1" 1 'mkscript'

print -r -- "\n\e[1m── mo-process ──\e[0m"
check "psgrep"          "zsh"      'psgrep zsh | head -1'
check "port validates"  "invalid"  'port abc 2>&1'
# Either a session table or the explicit "no inbound" line; anything else
# (a parse error, an empty string) is a failure.
checkmatch "connected" '(no inbound SSH sessions|from)' 'connected 2>&1 | head -1'
checkrc "connected -v does not die on ss" 1 'connected -v'

print -r -- "\n\e[1m── mo-search ──\e[0m"
check "grep colorized"    "--color"  'alias grep'
if command -v fzf &>/dev/null; then
	check "f finds a file"  "f.txt"  "cd $SB && f f.txt"
else
	skip "f finds a file" "mo-search needs fzf, which is absent"
fi
if man -k . >/dev/null 2>&1 && [[ -n "$(man -k . 2>/dev/null | head -1)" ]]; then
	checkmatch "man -k . populated" '\(.*\)' 'man -k . 2>/dev/null | head -1'
else
	skip "man -k . populated" "no whatis database"
fi
if command -v rg &>/dev/null && command -v fzf &>/dev/null; then
	check "frg pipeline yields rows" "needle" \
		"cd $SB && printf 'hay\nneedle\n' > n.txt && rg --color=always --line-number --null -- needle . 2>/dev/null | tr '\0' '\t' | awk 'BEGIN{FS=\"\t\"} NF==2{print \$2}' | head -1"
else skip "frg pipeline" "rg or fzf absent"; fi

print -r -- "\n\e[1m── mo-trash ──\e[0m"
if [[ -n "$(_mo_trash_tool 2>/dev/null)" ]]; then
	print -- keep > "$SB/e2e-trash-$$.txt"
	check "rm trashes"        "gone"        "cd $SB && rm e2e-trash-$$.txt; [[ -e e2e-trash-$$.txt ]] && print STILL || print gone"
	if _mo_is_macos; then
		check "index records path" "$SB"      "grep e2e-trash-$$ \${MO_TRASH_INDEX:-\$HOME/.config/master-oogway/trash-index.tsv} | tail -1"
	else
		skip "index records path" "trash-cli records it itself on Linux"
	fi
	# /usr/bin/trash always writes to the real user's ~/.Trash regardless of
	# $HOME, so point MO_TRASH_DIR there for this check.
	check "trash-list shows it" "e2e-trash-$$" "MO_TRASH_DIR=\$(eval echo ~\$USER)/.Trash trash-list"
	if _mo_is_macos; then
		check "rm -h shows the bypass" '\rm'  'rm -h'
	else
		skip "rm -h shows the bypass" "trash-cli owns rm on Linux"
	fi
	print -- bye > "$SB/e2e-bypass-$$.txt"
	# ~$USER, not $HOME: /usr/bin/trash writes to the real user's Trash
	# regardless of $HOME, and under the e2e $HOME is the throwaway dir — so
	# this assertion could never fail and the cleanup below missed its target.
	check "\\rm really deletes" "gone"      "cd $SB && \\rm e2e-bypass-$$.txt; [[ -e $(eval echo ~$USER)/.Trash/e2e-bypass-$$.txt ]] && print TRASHED || print gone"
	command rm -f "$(eval echo ~$USER)/.Trash/e2e-trash-$$.txt" 2>/dev/null
else skip "mo-trash" "no trash tool"; fi

print -r -- "\n\e[1m── mo-welcome ──\e[0m"
typeset -A _wre=(
	[host]='.+@.+'            [os]='[A-Za-z]'
	[sys]='[0-9]+\.[0-9]+'    [up]='[0-9]+[dhm]'
	[load]='[0-9]+\.[0-9]+'   [mem]='[0-9.]+ */ *[0-9.]+ *GB'
	[disk]='[0-9]+%'          [arch]='(arm64|x86_64|aarch64)'
)
for fld in host os sys up load mem disk arch; do
	# A needle per field: an empty one matched "command not found" too, so
	# these passed even when the plugin never loaded.
	checkmatch "welcome:$fld" "${_wre[$fld]}" "MO_WELCOME_FIELDS= ; _mo_welcome_field_$fld"
done

print -r -- "\n\e[1m── mo-cli ──\e[0m"
check "master-oogway version" "master-oogway" 'master-oogway version'
check "master-oogway help"    "configure"     'master-oogway help'
assert_not_refused=$(_t 15 zsh -ic 'master-oogway lan-ssh status 2>&1' 2>&1)
if [[ "$assert_not_refused" == *"not supported on macOS"* ]]; then
	bad "lan-ssh not refused" "still gated"
else ok "lan-ssh not refused"; fi
checkrc "unknown subcommand rc=1" 1           'master-oogway bogus'

print -r -- "\n\e[1m── mo-safety-override / colorize ──\e[0m"
check "mkdir -pv"  "b"     "cd $SB && mkdir a2/b 2>&1 | tail -1"
check "cp -i"      "cp -i" 'alias cp'
check "reboot is confirmed" "_confirm_reboot" 'alias reboot'
if _mo_is_macos; then
	checkrc "no ip alias (macOS has no ip)"       1 'alias ip'
	checkrc "no dmesg alias (BSD dmesg has no --color)" 1 'alias dmesg'
else
	# Both exist on Linux; the aliases are guarded on the command being there,
	# which a minimal container may not have.
	command -v ip    &>/dev/null && check "ip alias on Linux"    "--color" 'alias ip'    || skip "ip alias"    "ip absent"
	command -v dmesg &>/dev/null && check "dmesg alias on Linux" "--color" 'alias dmesg' || skip "dmesg alias" "dmesg absent"
fi

print -r -- "\n\e[1m── theme seeding ──\e[0m"
# The throwaway HOME has no font directory, so the installer must have seeded
# plain separators. Seeding the schema default of true here would put a tofu box
# in place of every separator on the first prompt.
check "no Nerd Font seeds plain separators" "USE_NERD_FONT='false'" \
	"command grep -o \"USE_NERD_FONT='[a-z]*'\" \$HOME/.config/master-oogway/conf.zsh | head -1"

print -r -- "\n\e[1m── platform primitives ──\e[0m"
# "6S+12P" only where the kernel reports performance tiers; a plain count
# everywhere else, which is what the primitive is specified to return.
checkmatch "core summary" '^([0-9]+[A-Za-z]\+[0-9]+[A-Za-z]|[0-9]+)$' '_mo_core_summary' 
checkmatch "disk pct" '^[0-9]+$' '_mo_disk_pct'
if [[ -n "$(_mo_local_ip)" ]]; then
	check "local ip"  "."   '_mo_local_ip'
else
	skip "local ip" "no non-loopback address"
fi
if _mo_default_subnet_cidr >/dev/null 2>&1 && [[ -n "$(_mo_default_subnet_cidr)" ]]; then
	check "subnet CIDR" "/" '_mo_default_subnet_cidr'
else
	skip "subnet CIDR" "no default route"
fi
if _mo_is_macos; then
	check "pkg hint xclip is honest" "pbcopy"      '_mo_pkg_hint xclip'
else
	check "pkg hint uses apt"        "apt install" '_mo_pkg_hint xclip'
fi
if _mo_is_macos; then
	check "cask split"  "--cask"      '_mo_pkg_hint nmap texlive-xetex'
else
	check "apt hint"    "apt install" '_mo_pkg_hint nmap texlive-xetex'
fi

print -r -- "\n\e[1m════ RESULT ════\e[0m"
print -r -- "  passed: $PASS   failed: $FAIL   skipped: $SKIP"
(( FAIL )) && { print -r -- "\n  failures:"; printf '    - %s\n' "${FAILED[@]}" }
