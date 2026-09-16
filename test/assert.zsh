typeset -gi _T_PASS=0 _T_FAIL=0 _T_SKIP=0
typeset -g  _T_FILE=""

_t_ok()   { (( _T_PASS++ )); print -r -- "  ok     $1" }
_t_fail() { (( _T_FAIL++ )); print -r -- "  NOT OK $1"; [[ -n "$2" ]] && print -r -- "         $2" }

# An assertion this machine cannot make. Say so out loud: conditional blocks
# used to just not run, so a suite that skipped six checks was indistinguishable
# from one that made them, and the pass counts differed between machines with no
# way to account for the gap.
t_skip()  { (( _T_SKIP++ )); print -r -- "  skip   $1${2:+  — $2}" }

assert_eq() {
	local expected="$1" actual="$2" label="$3"
	[[ "$expected" == "$actual" ]] \
		&& _t_ok "$label" \
		|| _t_fail "$label" "expected: [$expected]  actual: [$actual]"
}

assert_contains() {
	local haystack="$1" needle="$2" label="$3"
	[[ "$haystack" == *"$needle"* ]] \
		&& _t_ok "$label" \
		|| _t_fail "$label" "[$haystack] does not contain [$needle]"
}

assert_match() {
	local str="$1" re="$2" label="$3"
	[[ "$str" =~ $re ]] \
		&& _t_ok "$label" \
		|| _t_fail "$label" "[$str] does not match /$re/"
}

assert_ok() {
	local label="$1"; shift
	if "$@" >/dev/null 2>&1; then _t_ok "$label"; else _t_fail "$label" "command failed: $*"; fi
}

assert_fail() {
	local label="$1"; shift
	if "$@" >/dev/null 2>&1; then _t_fail "$label" "expected failure: $*"; else _t_ok "$label"; fi
}

assert_true() {
	local label="$1" cond="$2"
	(( cond )) && _t_ok "$label" || _t_fail "$label"
}

assert_not_contains() {
	local haystack="$1" needle="$2" label="$3"
	[[ "$haystack" != *"$needle"* ]] \
		&& _t_ok "$label" \
		|| _t_fail "$label" "[$haystack] unexpectedly contains [$needle]"
}
