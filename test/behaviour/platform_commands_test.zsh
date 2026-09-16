source "$MO_ROOT/omz-custom/lib/platform.zsh"

# Behavioural coverage for the commands the audit found dead on macOS behind a
# green suite. Each asserts on output, not merely on a zero exit.

_mo_b() {
	local plug="$1"; shift
	zsh -c "
		setopt EXTENDED_GLOB
		export ZSH_CUSTOM='$MO_ROOT/omz-custom'
		for f in '$MO_ROOT'/omz-custom/lib/*.zsh(#qN); do source \$f; done
		source '$MO_ROOT/omz-custom/plugins/$plug/$plug.plugin.zsh' 2>/dev/null
		$*
	" 2>&1
}

# ── mo-welcome: every field must report a real value ─────────────────────────
# The suite previously checked only that this file parses. Each field is called
# by its own function and the result is pattern-matched, so a field that starts
# returning an error string — or nothing — fails instead of passing on the noise.
local -A _want=(
	[host]='.+@.+'
	[os]='[A-Za-z]+ ?[0-9.]*'
	[sys]='[0-9]+\.[0-9]+'
	[now]='[0-9]'
	[up]='[0-9]+[dhm]'
	[shell]='zsh [0-9]+\.[0-9]+'
	[load]='[0-9]+\.[0-9]+'
	[mem]='[0-9.]+ */ *[0-9.]+ *GB'
	[disk]='[0-9]+%'
	[arch]='(arm64|x86_64|aarch64)'
)
# The plugin prints its banner when sourced; silence it so each assertion sees
# only the field it asked for.
export MO_WELCOME_FIELDS=""
local _f _out
for _f in ${(k)_want}; do
	_out=$(_mo_b mo-welcome "_mo_welcome_field_${_f}")
	assert_not_contains "$_out" "command not found" "welcome field '$_f' exists"
	assert_match "$_out" "${_want[$_f]}" "welcome field '$_f' reports a real value"
done
unset MO_WELCOME_FIELDS

# disk read the sealed APFS system snapshot, which is a couple of percent
# whatever the machine is doing, so the 70/90 thresholds could never fire.
local _pct=$(_mo_disk_pct)
assert_match "$_pct" '^[0-9]+$' "disk_pct is a bare integer"
if _mo_is_macos; then
	assert_eq "$(df -P /System/Volumes/Data | awk 'NR==2{gsub(/%/,"",$5); print $5}')" "$_pct" \
		"disk_pct measures the writable volume, not the system snapshot"
	# And the field must actually call the primitive. It did not: the primitive
	# was added and mo-welcome kept its own `df -P /`, so the banner still
	# reported the snapshot's 2% while the primitive tested clean.
	export MO_WELCOME_FIELDS=""
	assert_contains "$(_mo_b mo-welcome '_mo_welcome_field_disk' | sed $'s/\x1b\[[0-9;]*m//g')" \
		"${_pct}%" "the disk field reports what disk_pct measured"
	unset MO_WELCOME_FIELDS
fi

# local_ip must fall through to ifconfig for interfaces ipconfig cannot answer
# for (static addresses, VPN tunnels) — the Linux branch has that second tier.
assert_match "$(_mo_local_ip)" '^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)?$' "local_ip is an address or empty"

# ── connected: who -u differs by one field between the platforms ─────────────
# GNU prints one ISO date token, BSD prints three, so parsing by column put the
# wrong value in every field after the username. _mo_who_sessions parses from
# the right, where both agree.
_parse_who() {
	print -r -- "$1" | awk '
		NF >= 5 {
			host = ""; last = NF
			if ($NF ~ /^\(.*\)$/) { host = substr($NF, 2, length($NF) - 2); last = NF - 1 }
			login = ""
			for (i = 3; i <= last - 2; i++) login = login (login == "" ? "" : " ") $i
			printf "%s|%s|%s|%s", $1, login, $last, host
		}'
}
assert_eq "kfir|2026-09-08 21:38|1234|192.168.1.9" \
	"$(_parse_who 'kfir pts/0 2026-09-08 21:38 . 1234 (192.168.1.9)')" \
	"who parser handles the GNU shape"
assert_eq "kfir|Sep 8 21:38|66764|192.168.1.9" \
	"$(_parse_who 'kfir ttys002 Sep 8 21:38 00:03 66764 (192.168.1.9)')" \
	"who parser handles the BSD shape"
assert_eq "kfir|Sep 8 21:38|905|" \
	"$(_parse_who 'kfir console Sep 8 21:38 16:18 905')" \
	"who parser handles a local session with no host"

# connected -v needed `ss`, which macOS has no port of.
assert_ok "ssh_peer answers without ss" _mo_ssh_peer 127.0.0.1

# ── mo-search: two parsers that returned nothing on macOS ────────────────────
# `man -k ''` matches everything under man-db and nothing under mandoc.
# `man -k` of any kind needs a built index, and `command -v man` does not tell
# you there is one. Installing packages leaves man-db rebuilding its cache in
# the background, and inside that window every apropos query returns nothing —
# which failed this assertion on a CI runner while saying nothing whatever about
# the pattern under test. Probe with a concrete page first: no index means the
# comparison is moot, a working index means a `.` that finds nothing is real.
if command -v man &>/dev/null; then
	if (( $(man -k ls 2>/dev/null | wc -l) > 0 )); then
		assert_true "man -k . finds pages (man -k '' finds none under mandoc)" \
			"$(man -k . 2>/dev/null | wc -l) > 0"
	else
		t_skip "man -k . finds pages" "no man index on this machine"
	fi
fi

# The apropos output shape differs: man-db separates the section, mandoc glues
# it on. One regex has to cover both.
_parse_man() {
	print -r -- "$1" | awk '
		{
			if (!match($0, /[A-Za-z0-9_.:@\[\]-]+[ ]?\([0-9a-zA-Z]+\)/)) next
			tok = substr($0, RSTART, RLENGTH)
			p = index(tok, "(")
			name = substr(tok, 1, p - 1); sub(/[ ,]+$/, "", name)
			sec  = substr(tok, p + 1);    sub(/\)$/, "", sec)
			print sec, name
		}'
}
assert_eq "1 ls" "$(_parse_man 'ls(1) - list directory contents')"  "fman parses the mandoc shape"
assert_eq "1 ls" "$(_parse_man 'ls (1)              - list dir')"   "fman parses the man-db shape"

# BWK awk cannot split on NUL, so frg's NF == 2 guard never fired and the
# picker stayed empty no matter what was typed.
assert_eq "2" "$(printf 'a\0b\n' | tr '\0' '\t' | awk 'BEGIN{FS="\t"}{print NF}')" \
	"the tr shim gives awk two fields where a NUL FS gives one"

# ── zsh's % is an anchor in a substitution pattern ───────────────────────────
# EDITOR_LINENO_FMT has never worked on any platform without the escape.
local _fmt='hx %f:%l' _got
_got="${_fmt//\%f//tmp/x}"; _got="${_got//\%l/42}"
assert_eq "hx /tmp/x:42" "$_got" "EDITOR_LINENO_FMT substitutes both placeholders"

# ── install.sh prompts for a git identity it may not be able to read ─────────
# Structural, like the picker checks above: driving a real install to this point
# costs an install. The bug was upstream's and pre-dates this branch — confirm()
# was fixed in 0e768f5 ("detect controlling tty by opening /dev/tty, not -r")
# and _install_gitconfig kept the check that commit had just declared wrong.
# `[[ -r /dev/tty ]]` only stats the device node, mode 666, so it passes with no
# controlling terminal; the read then failed and, under set -e, killed the
# install AFTER ~/.zshrc and ~/.zshenv had already been replaced.
# install.sh must look for a Nerd Font rather than assume one. The theme
# defaults DRAGON__USE_NERD_FONT to true, so when the assumption is wrong every
# separator and icon renders as a tofu box, which reads as a broken install.
local _nf
_nf=$(awk '/^_nerd_font_installed\(\)/,/^}$/' "$MO_ROOT/install.sh")
assert_contains "$_nf" "nerd" "install.sh probes for a Nerd Font"
# Both platforms, and the macOS branch must not lean on fc-list, which macOS
# has no reason to ship.
assert_contains "$_nf" "Library/Fonts"      "the macOS branch looks in the Library font dirs"
assert_contains "$_nf" "fc-list"            "the Linux branch asks fontconfig"
assert_contains "$_nf" ".local/share/fonts" "the Linux branch also looks on disk when fc-list is absent"

# The probe must actually reach the seeded config. Detecting the font and then
# writing the schema default anyway would fix nothing.
local _seed
_seed=$(awk '/^_regen_theme_conf\(\)/,/^}$/' "$MO_ROOT/install.sh")
assert_contains "$_seed" '_DRAGON_CURRENT[USE_NERD_FONT]' \
	"the seeded config takes the Nerd Font answer from the probe"
assert_contains "$_seed" "_nerd_font_installed" \
	"the seed path runs the probe"
# Multi-line todos are indented in the source; that indentation used to reach
# the screen verbatim, putting continuation lines far right of what they follow.
assert_contains "$(awk '/^print_todos\(\)/,/^}$/' "$MO_ROOT/install.sh")" \
	'2,$s/^[[:space:]]*/' "multi-line todos are re-indented for display"

# The optional-package report runs at the very bottom of install.sh, after every
# dotfile is linked, so it cannot block anything. It used to `exit 1` there —
# reporting failure for an install that had succeeded, so `install.sh && x` never
# ran x — while printing text that read as though nothing had been installed.
local _report_fn
_report_fn=$(awk '/^_report_optional_deps\(\)/,/^}$/' "$MO_ROOT/install.sh" \
	| command grep -v '^[[:space:]]*#')
assert_not_contains "$_report_fn" "exit 1" \
	"the optional-package report does not fail a completed install"
assert_not_contains "$_report_fn" "install without the recommended" \
	"the report does not imply the install was skipped"

local _inst="$MO_ROOT/install.sh"
local _gitcfg_fn
# Comment lines are stripped, as lint_platform.zsh does: the comment explaining
# why the old check was wrong quotes it verbatim, and matched this assertion.
_gitcfg_fn=$(awk '/^_install_gitconfig\(\)/,/^}$/' "$_inst" | command grep -v '^[[:space:]]*#')
assert_not_contains "$_gitcfg_fn" '[[ -r /dev/tty ]]' \
	"the identity prompt does not gate on -r /dev/tty"
assert_contains "$_gitcfg_fn" '{ : < /dev/tty; }' \
	"the identity prompt probes the tty by opening it"
# Both reads must handle EOF; a bare `read` aborts the run on Ctrl-D.
assert_eq "2" "$(print -r -- "$_gitcfg_fn" | command grep -c 'read -r git_.* || _die_no_git_identity')" \
	"both identity reads handle a closed input"
assert_contains "$(command cat "$_inst")" "_die_no_git_identity()" \
	"the refusal is defined in one place"

# ── the package hints must not make claims that are false on macOS ───────────
if _mo_is_macos; then
	assert_not_contains "$(_mo_pkg_hint xclip)"    "check your PATH" "xclip hint does not claim macOS ships it"
	assert_not_contains "$(_mo_pkg_hint iproute2)" "check your PATH" "iproute2 hint does not claim macOS ships it"
	assert_contains "$(_mo_pkg_hint build-essential fzf)" "fzf" \
		"a non-formula entry no longer swallows the rest of the list"
	assert_contains "$(_mo_pkg_hint nmap texlive-xetex)" "--cask" \
		"casks are emitted as their own brew invocation"
	assert_not_contains "$(_mo_pkg_hint unrar)" "brew install unrar" \
		"the removed unrar formula is not suggested"
	# xclip and wl-clipboard carry the same note, and it was emitted per package,
	# so a real install printed the identical sentence twice on one line.
	assert_eq "1" \
		"$(_mo_pkg_hint xclip wl-clipboard | command grep -o 'pbcopy/pbpaste' | command wc -l | command tr -d ' ')" \
		"a note shared by two packages is printed once"
	# The hint is displayed as a line to paste, so a note must not sit after a
	# "; " where it reads as another command.
	assert_not_contains "$(_mo_pkg_hint nmap xclip)" "; macOS" \
		"notes are not appended as if they were shell commands"
fi

# ── color pick owns the tty for the whole session ────────────────────────────
# Structural, not behavioural: exercising the picker needs a real pty and
# keystroke timing, which the unit suite has no way to provide. The behaviour
# was verified by hand — sending Ctrl+C after navigating returns 130 with this
# structure and kills the shell with the old one — and these assertions pin the
# structure that makes it true.
#
# The bug: raw mode was set and restored around every single keystroke, so ISIG
# was re-enabled between reads. A Ctrl+C landing in that window arrived as a
# real SIGINT instead of the \x03 the reader turns into "cancel".
local _pick="$MO_ROOT/omz-custom/plugins/mo-color/_mo_color_pick.zsh"
if [[ -r "$_pick" ]]; then
	local _reader
	_reader=$(awk '/^_mo_pick_read_key\(\)/,/^}$/' "$_pick")
	assert_not_contains "$_reader" "stty -echo" \
		"the key reader does not set raw mode per keystroke"
	assert_not_contains "$_reader" 'stty "$stty_save"' \
		"the key reader does not restore the tty per keystroke"
	assert_contains "$(<$_pick)" 'stty "$_MO_PICK_STTY"' \
		"the picker restores the tty from its trap"
	# The saved mode must be global. zsh tears a function's locals down before
	# running its EXIT trap, so a trap naming a local restores `stty ""` and
	# leaves the terminal with no echo and no Ctrl+C.
	assert_contains "$(<$_pick)" 'typeset -g _MO_PICK_STTY' \
		"the saved tty mode outlives the function's locals"
	assert_contains "$(<$_pick)" '} always {' \
		"the picker also restores the tty from an always block"
	assert_eq "1" "$(command grep -c 'stty -echo -icanon -isig' "$_pick")" \
		"raw mode is set exactly once, around the whole loop"
	# The Esc timeout must stay zsh's own: `read -k` re-applies VMIN/VTIME from
	# the shell's saved state, so an stty-based timeout is silently undone.
	assert_contains "$(<$_pick)" 'read -t 0.05 -k1' \
		"Esc disambiguation uses zsh's read timeout, not stty"
fi

# ── the font question install.sh cannot answer on its own ───────────────────
# _nerd_font_renders decides what install.sh seeds USE_NERD_FONT to. A font on
# disk is not the question: a machine can have JetBrainsMono NF installed and
# still render U+E0B0 as a box, because the terminal is pointed at Monaco. No
# portable way exists to read a terminal's active font — Ghostty and kitty keep
# it in plain text, iTerm2 behind a profile GUID, Terminal.app in an archived
# NSFont, WezTerm in arbitrary Lua — and under tmux or ssh the font belongs to a
# terminal we cannot see at all. So the disk probe narrows it and the person
# looking at the screen settles it.
#
# The two environment probes are separate one-liners precisely so this table can
# be walked without a pty. 0 = yes, mirroring shell exit status.
typeset -g _NF_SEED _NF_PROMPT
_nf_seed() {
	local has_font="$1" has_tty="$2" answer="$3" drv
	drv="$(mktemp)"
	{
		print -r -- 'set -Eeuo pipefail'
		print -r -- '_ask() { printf "%s" "$*" >&2; }'
		print -r -- "_nerd_font_installed() { return $has_font; }"
		print -r -- "_mo_has_tty() { return $has_tty; }"
		print -r -- "_mo_read_tty() { printf '%s' '$answer'; }"
		awk '/^_nerd_font_renders\(\)/,/^}$/' "$MO_ROOT/install.sh"
		print -r -- 'if _nerd_font_renders; then echo true; else echo false; fi'
	} > "$drv"
	_NF_SEED="$(bash "$drv" 2>"${drv}.err")"
	_NF_PROMPT="$(<"${drv}.err")"
	rm -f "$drv" "${drv}.err"
}

# No font on disk: nothing to look at, so spend no prompt on it.
_nf_seed 1 0 ''
assert_eq "false" "$_NF_SEED"   "no font on disk seeds plain separators"
assert_eq ""      "$_NF_PROMPT" "no font on disk asks nothing"

# No controlling terminal — curl | bash, CI, the e2e sweep. Nobody can answer,
# so fall back to what the disk says rather than blocking the install forever.
_nf_seed 0 1 ''
assert_eq "true" "$_NF_SEED"   "a headless install falls back to the disk probe"
assert_eq ""     "$_NF_PROMPT" "a headless install asks nothing"

# Font on disk and someone to ask: the answer decides.
_nf_seed 0 0 'y'
assert_eq "true" "$_NF_SEED" "seeing the glyphs seeds Nerd Font separators"
assert_contains "$_NF_PROMPT" "render" "the question is actually asked"

_nf_seed 0 0 'n'
assert_eq "false" "$_NF_SEED" "not seeing the glyphs seeds plain separators"

# Enter must mean no. The failure modes are asymmetric: a wrong no is a plain
# but readable prompt, a wrong yes is a tofu box on every line.
_nf_seed 0 0 ''
assert_eq "false" "$_NF_SEED" "a bare Enter declines rather than assuming"

# Structural guards on the new tty code. Both mistakes below have been made in
# this file before.
local _nfr _hastty
_nfr=$(awk '/^_nerd_font_renders\(\)/,/^}$/' "$MO_ROOT/install.sh")
_hastty=$(awk '/^_mo_has_tty\(\)/,/^}$/' "$MO_ROOT/install.sh")
# 0e768f5 fixed `[[ -r /dev/tty ]]` once already: it stats a mode-666 device
# node, so it passes with no controlling terminal and the read then dies.
assert_contains "$_hastty" '{ : < /dev/tty; }' \
	"the tty probe opens /dev/tty rather than stat-ing it"
assert_not_contains "$_hastty" '[[ -r /dev/tty ]]' \
	"the tty probe does not gate on -r /dev/tty"
# macOS ships bash 3.2, which has no \u escape. \x is the portable spelling.
assert_contains "$_nfr" '\xee\x82\xb0' \
	"the powerline glyph is written as bytes bash 3.2 understands"
assert_not_contains "$_nfr" '\uE0B0' \
	"the glyph does not use a \\u escape bash 3.2 cannot read"
assert_not_contains "$_nfr" '\ue0b0' \
	"the glyph does not use a lowercase \\u escape either"

# The seed path must ask the question, not just consult the disk.
local _seed2
_seed2=$(awk '/^_regen_theme_conf\(\)/,/^}$/' "$MO_ROOT/install.sh")
assert_contains "$_seed2" "_nerd_font_renders" \
	"the seeded config comes from the rendering question"

# The case this whole change exists for: a font is installed and the terminal is
# not using it. Before, that produced no guidance at all.
local _todos
_todos=$(awk '/^_regen_theme_conf\(\)/,/^}$/' "$MO_ROOT/install.sh")
assert_contains "$_todos" "isn't using it" \
	"an installed-but-unused font gets its own todo"

# The todo can name the font it found, which turns "install a Nerd Font" into
# "you already have this one, point your terminal at it".
_nf_family() {
	local home="$1" drv
	drv="$(mktemp)"
	{
		print -r -- 'set -Eeuo pipefail'
		print -r -- "_mo_is_macos() { [[ $(uname -s) == Darwin ]]; }"
		awk '/^_nerd_font_family\(\)/,/^}$/' "$MO_ROOT/install.sh"
		print -r -- '_nerd_font_family'
	} > "$drv"
	HOME="$home" bash "$drv" 2>/dev/null
	rm -f "$drv"
}
local _fh
_fh="$(mktemp -d)"
mkdir -p "$_fh/Library/Fonts" "$_fh/.local/share/fonts"
: > "$_fh/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"
: > "$_fh/.local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf"
assert_eq "JetBrainsMono Nerd Font" "$(_nf_family "$_fh")" \
	"the installed family is named in readable form"
rm -rf "$_fh"

assert_contains "$_todos" '_nerd_font_family' \
	"the installed-but-unused todo names the font it found"

# ── the seam the stubs bypass: a real read from a real tty ──────────────────
# Everything above replaces _mo_read_tty, so a broken `read -r r < /dev/tty`
# would pass the whole truth table. This drives the real helpers on a real pty.
if ! command -v script &>/dev/null; then
	t_skip "the font question reads a real tty" "script(1) not installed"
	t_skip "a bare Enter on a real tty declines" "script(1) not installed"
else
	# script(1) takes its command differently per platform: util-linux wants
	# -c "cmd" with the file last, BSD takes the file then the argv.
	_nf_on_pty() {
		local answer="$1" drv out
		drv="$(mktemp)"
		{
			print -r -- 'set -Eeuo pipefail'
			print -r -- 'COLOR_MAGENTA="" COLOR_RESET=""'
			print -r -- '_ask() { echo -en "$*" > /dev/tty; }'
			print -r -- '_nerd_font_installed() { return 0; }'
			command grep '^_mo_has_tty()'  "$MO_ROOT/install.sh"
			command grep '^_mo_read_tty()' "$MO_ROOT/install.sh"
			awk '/^_nerd_font_renders\(\)/,/^}$/' "$MO_ROOT/install.sh"
			print -r -- 'if _nerd_font_renders; then echo RENDERS=yes; else echo RENDERS=no; fi'
		} > "$drv"
		# stdin must outlive the read. Closing it straight after the answer
		# delivers EOF to the pty before the prompt is even printed, and the
		# read then returns empty — which looks exactly like a declined answer.
		if script --version 2>&1 | command grep -qi util-linux; then
			out="$( { printf '%s\n' "$answer"; sleep 2; } | script -qec "bash $drv" /dev/null 2>&1)"
		else
			out="$( { printf '%s\n' "$answer"; sleep 2; } | script -q /dev/null bash "$drv" 2>&1)"
		fi
		rm -f "$drv"
		print -r -- "${${out##*RENDERS=}%%[^a-z]*}"
	}
	assert_eq "yes" "$(_nf_on_pty y)" "the font question reads a real tty"
	assert_eq "no"  "$(_nf_on_pty '')" "a bare Enter on a real tty declines"
fi

# fc-list can report a Nerd Font that lives outside the directories
# _nerd_font_family scans (/usr/local/share/fonts, a fontconfig custom dir), so
# the name can come back empty while the font is genuinely installed.
# Interpolating it bare would print "A Nerd Font is installed () but ...".
local _eh
_eh="$(mktemp -d)"
assert_eq "" "$(_nf_family "$_eh")" "an unscanned font dir yields no family name"
rm -rf "$_eh"
assert_not_contains "$_todos" '($(_nerd_font_family))' \
	"the font name is composed conditionally, not interpolated bare"
