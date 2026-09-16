#!/usr/bin/env zsh
# Fails if a plugin or theme file reaches for a raw platform call.
# Everything platform-specific belongs in omz-custom/lib/platform.zsh.
setopt EXTENDED_GLOB
MO_ROOT="${0:A:h:h}"

# lib/platform.zsh is the one place platform-specific calls belong.
typeset -i rc=0
# Declared here, not with `local` inside the loop: outside a function zsh
# treats `local` as `typeset`, and a bare `typeset name` prints the variable.
typeset -a hits real
typeset hit lineno prev pat f

# Two kinds of entry. The first are Linux-only interfaces — if one appears
# outside platform.zsh, that code cannot run on macOS at all. The second are
# GNU/BSD divergences: the call exists on both, but behaves differently enough
# to be a bug. The audit that prompted this list found four commands dead on
# macOS in files this lint had already called clean, because it only knew about
# the first kind.
typeset -a banned=(
	# Linux-only interfaces
	'\buname\b'
	'/proc/'
	'\bnproc\b'
	'\bxdg-open\b'
	'\bwl-copy\b'
	'\bxclip\b'
	'/etc/os-release'
	'\bsystemctl\b'
	'\btrash-put\b'
	'\bfc-list\b'          # fontconfig; macOS has none
	'\bss\b -'             # iproute2 socket stats; no macOS port
	'\bXDG_RUNTIME_DIR\b'  # unset on macOS; TMPDIR is the analogue
	'\bip\b (route|-o|-4|addr|link)'

	# GNU/BSD divergences
	'date -d'
	'--no-overwrite-dir'
	'apt install'
	'chmod --reference'
	'stat -c'
	'\bcat\b .*-A'         # GNU shorthand for -vET; BSD spells it -vet
	'who -u'                 # field count differs by one
	"man -k ''"              # matches nothing under mandoc
	'FS="\\\\0"'             # BWK awk cannot split on NUL
	'\bsed\b -i[^\x27"]'    # GNU takes no argument to -i, BSD requires one
	'\bpts\b'              # Linux tty naming; macOS uses ttysNNN
)

# install.sh, lib/ and the zshrc were outside the glob, so the chmod
# --reference / stat -c / sed -i rules — added precisely because install.sh had
# those defects — never actually scanned the file they were written for.
for f in \
	"$MO_ROOT"/omz-custom/plugins/mo-*/**/*(.N) \
	"$MO_ROOT"/omz-custom/themes/**/*(.N) \
	"$MO_ROOT"/omz-custom/lib/*(.N) \
	"$MO_ROOT"/install.sh(.N) \
	"$MO_ROOT"/zshrc.master-oogway(.N) \
	"$MO_ROOT"/zshenv.master-oogway(.N) \
; do
	[[ "$f" == *.md  ]] && continue
	[[ "$f" == *.zwc ]] && continue   # compiled bytecode, not source
	[[ "$f" == */lib/platform.zsh ]] && continue
	# A whole file may still opt out — optional-deps.zsh files name Debian
	# packages on purpose — but prefer the per-line form below. A file-level
	# waiver hides every future addition to that file too, which is how
	# mo-cli's Linux-isms went unnoticed after lan-ssh was (wrongly) gated.
	if command grep -qE '^#[[:space:]]*platform-lint:[[:space:]]*(metadata)\b' "$f"; then
		continue
	fi
	for pat in $banned; do
		# Skip whole-line comments: prose that names a Linux-ism to explain
		# why it is not used is not a call. A trailing comment on a real line
		# still counts, because the code before it does.
		hits=( ${(f)"$(command grep -nE "$pat" "$f" 2>/dev/null | command grep -vE '^[0-9]+:[[:space:]]*#')"} )
		(( ${#hits} )) || continue
		# Per-line waiver: "# platform-lint: allow — <reason>" on the offending
		# line or the line above it. A reason is required, so every exemption
		# is reviewable in the diff rather than silent.
		real=()
		for hit in $hits; do
			[[ -n "$hit" ]] || continue
			lineno="${hit%%:*}"
			[[ "$hit" == *'platform-lint: allow'* ]] && continue
			# Look back a few lines: a waiver usually carries a reason, and a
			# reason usually wraps.
			prev=$(command sed -n "$(( lineno > 3 ? lineno - 3 : 1 )),$(( lineno - 1 ))p" "$f" 2>/dev/null)
			[[ "$prev" == *'platform-lint: allow'* ]] && continue
			real+=("$hit")
		done
		if (( ${#real} )); then
			print -r -- "PLATFORM LINT: ${f#$MO_ROOT/} matches /$pat/"
			print -rl -- "${real[@]}" | sed 's/^/    /'
			rc=1
		fi
	done
done

(( rc == 0 )) && print -r -- "platform lint: clean"
exit $rc
