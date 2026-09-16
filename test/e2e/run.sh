#!/usr/bin/env bash
# End-to-end: install into a throwaway HOME, exercise every user-facing command
# in a real interactive login shell, then uninstall.
#
# The unit suite sources plugins directly, which cannot see the class of bug
# that only appears once oh-my-zsh has loaded them for real — a lib nothing
# sources, an alias shadowed by load order, a plugin that ships disabled. That
# is what this catches.
#
# Your own HOME is mostly untouched: everything happens under a mktemp -d. But
# three pieces of state are per-USER, not per-HOME, and no relocation isolates
# them:
#
#   crontab       crontab(1) reads the system spool and ignores $HOME entirely
#                 (HOME=/tmp crontab -l prints your real crontab), and the
#                 uninstall path removes the lan-scan line.
#   ~/.ssh/config the uninstall path strips its SendEnv stanza.
#   ~/.Trash      /usr/bin/trash writes there regardless of $HOME (macOS).
#
# The first two are snapshotted and restored below. The clipboard is also
# clobbered by the sweep.
#
# Usage:  bash test/e2e/run.sh
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OMZ="${ZSH:-$HOME/.oh-my-zsh}"

[[ -d "$OMZ" ]] || { echo "e2e: oh-my-zsh not found at $OMZ" >&2; exit 1; }
command -v script >/dev/null || { echo "e2e: needs script(1) for a pty" >&2; exit 1; }

# pty <seconds> <command...> — run a command on a real pty, time-bounded.
#
# script(1) takes its command differently per platform: util-linux wants
# -c "cmd" with the file last, BSD takes the file then the argv. A login shell
# needs a real pty, so there is no portable way around that.
#
# The bound is not optional. script waits for its child, and a login shell that
# never reads the "exit" we feed it — a prompt with nothing to answer it, a
# tool blocking on a device that is not there — hangs the pipeline. Unbounded,
# that consumed GitHub's six-hour job limit before the runner killed the job,
# which reports as "cancelled" and explains nothing. macOS has no timeout(1);
# perl's alarm is present everywhere.
if script --version 2>&1 | grep -qi util-linux; then
	_SCRIPT_FLAVOUR=util-linux
else
	_SCRIPT_FLAVOUR=bsd
fi

pty() {
	local secs="$1"; shift
	if [[ "$_SCRIPT_FLAVOUR" == util-linux ]]; then
		perl -e 'alarm shift; exec @ARGV' "$secs" script -qec "$*" /dev/null
	else
		perl -e 'alarm shift; exec @ARGV' "$secs" script -q /dev/null "$@"
	fi
}

TH="$(mktemp -d)"

# Snapshot the per-user state the uninstall path reaches, so a developer who
# has actually run `master-oogway lan-ssh setup` does not lose it to a test.
CRONTAB_SNAP="$TH/.crontab.snapshot"
crontab -l > "$CRONTAB_SNAP" 2>/dev/null || : > "$CRONTAB_SNAP"
SSHCFG_SNAP="$TH/.sshconfig.snapshot"
SSHCFG_EXISTED=0
if [[ -f "$HOME/.ssh/config" ]]; then
	cp "$HOME/.ssh/config" "$SSHCFG_SNAP"; SSHCFG_EXISTED=1
fi

restore_user_state() {
	if [[ -s "$CRONTAB_SNAP" ]]; then
		crontab "$CRONTAB_SNAP" 2>/dev/null || true
	else
		# Only clear it if it was empty to begin with.
		crontab -r 2>/dev/null || true
	fi
	if (( SSHCFG_EXISTED )); then
		mkdir -p "$HOME/.ssh"; cp "$SSHCFG_SNAP" "$HOME/.ssh/config"
	fi
}

cleanup() { restore_user_state; rm -rf "$TH"; }
trap cleanup EXIT

ln -s "$OMZ" "$TH/.oh-my-zsh"
cp -R "$REPO" "$TH/src"
printf '[user]\n\tname = e2e\n\temail = e2e@example.invalid\n' > "$TH/.gitconfig"

echo "── installing into $TH"
( printf '\n\n\n\n\n\n'; sleep 30 ) \
	| pty 420 env HOME="$TH" MO_CONFIG_DIR="$TH/.config/master-oogway" \
		bash "$TH/src/install.sh" --no-recommended-packages >/dev/null 2>&1 || true
[[ -L "$TH/.zshrc" ]] || { echo "e2e: install did not link ~/.zshrc" >&2; exit 1; }

# Assert we are testing THIS tree.
#
# install.sh decides it is running from a clone by looking for "master-oogway"
# in the origin remote URL. A copy without a .git — a tarball, an export, an
# archive download — fails that test, so the installer takes its curl-pipe
# path, clones upstream from GitHub, and re-execs from there. The suite then
# runs green or red against code nobody in this repo wrote, and says nothing.
# That is exactly what happened the first time this was run on Linux: every
# reported failure was upstream behaviour, including the bugs this branch
# fixes.
_installed="$(cd "$TH/.master-oogway" 2>/dev/null && pwd -P || true)"
if [[ "$_installed" != "$(cd "$TH/src" && pwd -P)" ]]; then
	echo "e2e: the installer did not use this tree." >&2
	echo "  ~/.master-oogway resolves to: ${_installed:-<missing>}" >&2
	echo "  expected:                     $TH/src" >&2
	echo "  Most likely the copy has no .git, so install.sh treated it as a" >&2
	echo "  curl-pipe bootstrap and cloned upstream instead." >&2
	exit 1
fi
# Belt and braces: a marker only this branch has.
[[ -f "$TH/.master-oogway/omz-custom/lib/platform.zsh" ]] || {
	echo "e2e: installed tree has no lib/platform.zsh — wrong source" >&2; exit 1; }

# Turn on the plugins that ship commented out, so the sweep covers them. Match
# a name followed by its trailing comment: the plugins=() block also contains
# prose comments, and uncommenting one of those injects its words as plugin
# names (oh-my-zsh then reports "plugin 'is' not found").
sed -i.bak -E 's/^    # (mo-welcome|mo-trash|mo-search)([[:space:]]+#)/    \1\2/' \
	"$TH/.config/master-oogway/zshrc"

cp "$REPO/test/e2e/feature_sweep.zsh" "$TH/sweep.zsh"

echo "── running the sweep in a real login shell"
out="$TH/out.txt"
# ZSH_DISABLE_COMPFIX: on a CI runner some completion directory is
# world-writable, and oh-my-zsh then prints a multi-line "Insecure
# completion-dependent directories detected" banner at every shell start. It
# lands on stdout, so it prefixes the output of every assertion and defeats any
# anchored match. It is a property of the runner, not of anything under test.
( sleep 1; printf 'source $HOME/sweep.zsh\nexit\n'; sleep 240 ) \
	| pty 900 env HOME="$TH" ZSH_DISABLE_COMPFIX=true TERM="${TERM:-xterm-256color}" \
		"$(command -v zsh)" -l -i > "$out" 2>&1 || true

tr -d '\r' < "$out" | sed 's/\x1b\[[0-9;]*m//g' | sed -n '/── theme/,$p' \
	| grep -E '──|PASS|FAIL|SKIP|passed:|^    - ' || true

echo "── uninstalling"
( printf 'y\ny\nn\nn\n'; sleep 20 ) \
	| pty 420 env HOME="$TH" MO_CONFIG_DIR="$TH/.config/master-oogway" \
		bash "$TH/src/install.sh" --uninstall >/dev/null 2>&1 || true
for f in .zshrc .zshenv .editorconfig; do
	[[ -L "$TH/$f" ]] && { echo "e2e: --uninstall left $f linked" >&2; exit 1; }
done
echo "── uninstall reversed every managed dotfile"

grep -qE 'failed: 0' <(tr -d '\r' < "$out")
