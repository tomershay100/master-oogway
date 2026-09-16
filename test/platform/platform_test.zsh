source "$MO_ROOT/omz-custom/lib/platform.zsh"

# -- cpu ------------------------------------------------------------------------
assert_match "$(_mo_cpu_count)" '^[0-9]+$' "cpu_count is an integer"
assert_true "cpu_count > 0" "$(_mo_cpu_count) > 0"

typeset -a pe=( ${(z)$(_mo_perf_cores)} )
assert_eq 2 ${#pe} "perf_cores returns two fields"
assert_match "${pe[1]}" '^[0-9]+$' "perf cores integer"
assert_match "${pe[2]}" '^[0-9]+$' "efficiency cores integer"

# -- memory ---------------------------------------------------------------------
typeset -a mem=( ${(z)$(_mo_mem_stats)} )
assert_eq 2 ${#mem} "mem_stats returns two fields"
assert_true "mem total > 0" "${mem[2]} > 0"
assert_true "mem used in range" "${mem[1]} > 0 && ${mem[1]} <= ${mem[2]}"

# -- load / uptime --------------------------------------------------------------
assert_match "$(_mo_load_avg)" '^[0-9]+\.[0-9]+$' "load_avg is decimal"
assert_match "$(_mo_uptime_secs)" '^[0-9]+$' "uptime_secs is an integer"
assert_true "uptime > 0" "$(_mo_uptime_secs) > 0"

# -- identity -------------------------------------------------------------------
if _mo_is_macos; then
	assert_contains "$(_mo_os_name)" "macOS" "os_name reports the macOS product version"
else
	assert_true "os_name is non-empty on Linux" "${#$(_mo_os_name)} > 0"
fi
assert_match "$(_mo_kernel)" '^[0-9]+\.' "kernel looks like a version"

# -- dates ----------------------------------------------------------------------
assert_eq "2023-11-14 22:13:20" "$(_mo_epoch_to_date 1700000000 --utc)" "epoch_to_date UTC"

# Pin TZ: without it these assert whatever the tester's clock says, and the
# earlier hardcoded 1700000000 quietly encoded the UTC reading of a local-time
# string — it passed on macOS only because the implementation had the same bug,
# and would have failed on Linux by exactly the UTC offset.
(
	export TZ=Asia/Jerusalem   # UTC+2 in November, so the two readings differ
	assert_eq 1700000000 "$(_mo_date_to_epoch '2023-11-14 22:13:20' --utc)" \
		"date_to_epoch reads --utc as UTC"
	assert_eq 1699992800 "$(_mo_date_to_epoch '2023-11-14 22:13:20')" \
		"date_to_epoch reads a bare datetime as local time"
	assert_eq 1700000000 "$(_mo_date_to_epoch "$(_mo_epoch_to_date 1700000000 --utc)" --utc)" \
		"epoch -> date -> epoch round-trips in UTC"
)

# Relative expressions: GNU date parses them natively, BSD date needs the
# translation table in _mo_relative_to_epoch.
assert_match "$(_mo_relative_to_epoch yesterday)" '^[0-9]+$' "relative: yesterday parses"
assert_true "relative: yesterday is in the past" \
	"$(_mo_relative_to_epoch yesterday) < $(date +%s)"
assert_fail "relative: gibberish is rejected" _mo_relative_to_epoch 'not a date' 

# -- clipboard ------------------------------------------------------------------
# Guarded on capability, not by running the tool. The first version probed
# with `_mo_paste`, which HUNG the whole suite on a desktop Linux reached over
# SSH: wl-clipboard is installed there but has no Wayland session, and wl-paste
# blocks rather than failing. _mo_clip_tool decides from the environment and
# always returns.
if _mo_clip_tool >/dev/null 2>&1; then
	_saved_clipboard=$(_mo_paste 2>/dev/null)
	_mo_clip "mo-clip-test-$$"
	assert_eq "mo-clip-test-$$" "$(_mo_paste)" "clip roundtrip"
	# Put it back: this file runs before test/plugins, so without a restore
	# here the save/restore there captures this sentinel instead of the
	# tester's own clipboard.
	[[ -n "$_saved_clipboard" ]] && _mo_clip "$_saved_clipboard"
	unset _saved_clipboard
else
	t_skip "clip roundtrip" "no clipboard tool"
fi

# -- sed ------------------------------------------------------------------------
local tmp=$(mktemp)
print -l -- alpha beta gamma > "$tmp"
_mo_sed_inplace '/beta/d' "$tmp"
assert_eq "alpha
gamma" "$(command cat "$tmp")" "sed_inplace deletes a line"
command rm -f "$tmp"

# -- untar ----------------------------------------------------------------------
local td=$(mktemp -d)
mkdir -p "$td/src" "$td/out"
print -- hello > "$td/src/f.txt"
tar -czf "$td/a.tar.gz" -C "$td/src" f.txt
_mo_untar "$td/a.tar.gz" "$td/out"
assert_eq "hello" "$(command cat "$td/out/f.txt")" "untar extracts"
command rm -rf "$td"

# -- brew -----------------------------------------------------------------------
if _mo_is_macos; then
	assert_match "$(_mo_brew_prefix)" '^(/opt/homebrew|/usr/local)?$' "brew_prefix is a known location"
fi

# -- local ip -------------------------------------------------------------------
assert_match "$(_mo_local_ip)" '^([0-9]{1,3}\.){3}[0-9]{1,3}$|^$' "local_ip is IPv4 or empty"

# Core tier names are read from the chip, never assumed: M1-M4 report
# Performance/Efficiency, M5 reports Super/Performance.
assert_match "$(_mo_core_summary)" '^[0-9]+[A-Z]\+[0-9]+[A-Z]$|^[0-9]+$' "core_summary is well-formed"
if _mo_is_macos; then
	# Only physical Apple Silicon exposes hw.perflevelN.name; a VM (GitHub's
	# macos runners included) reports no perf levels at all, and _mo_perf_cores
	# correctly falls back to a flat count there. Assert the pairing only when
	# the kernel actually offers the tiers.
	typeset -a cn=( ${(z)$(_mo_perf_core_names)} )
	# Both tiers, not just the first: _mo_perf_core_names prints nothing unless
	# hw.perflevel0.name AND hw.perflevel1.name exist. A virtualised Mac — the
	# GitHub runner included — reports perflevel0 alone, all cores being equal
	# there, so a guard on perflevel0 took the two-name branch while the
	# function correctly returned nothing.
	if [[ -n "$(sysctl -n hw.perflevel0.name 2>/dev/null)" \
	   && -n "$(sysctl -n hw.perflevel1.name 2>/dev/null)" ]]; then
		assert_true "perf_core_names returns two names on Apple Silicon" "${#cn} == 2"
	else
		assert_eq "0" "${#cn}" "perf_core_names is empty where the kernel reports one tier"
	fi
fi

# -- platform detection ---------------------------------------------------------
assert_match "$_MO_PLATFORM" '^(linux|macos)$' "platform is detected"
assert_contains "$(_mo_pkg_hint fzf)" "fzf" "pkg_hint names the package"
if _mo_is_macos; then
	assert_contains "$(_mo_pkg_hint fzf)" "brew install" "macOS hint uses brew"
else
	assert_contains "$(_mo_pkg_hint fzf)" "apt install"  "Linux hint uses apt"
fi
