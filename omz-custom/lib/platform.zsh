# Platform primitives — the one place OS differences live.
#
# Nothing under plugins/ or themes/ may call `uname`, read /proc, or use a
# GNU-only flag; it calls a primitive here instead. test/lint_platform.zsh
# enforces that. Keeping the branches in one file means each plugin reads the
# same on every OS, and a third platform is one file rather than a 22-file
# audit.
#
# Each function pairs the Linux implementation (the behaviour master-oogway
# already had) with its macOS counterpart, so the two are reviewable together.

# Set before anything else: plugins guard-source this file on the strength
# of it, and a partial load must not look like a complete one.
typeset -g _MO_PLATFORM_LOADED=1

typeset -g _MO_PLATFORM
case "$(command uname -s)" in
	Linux)  _MO_PLATFORM=linux  ;;
	Darwin) _MO_PLATFORM=macos  ;;
	*)      _MO_PLATFORM=linux  ;;   # BSDs are closer to Linux here than to macOS
esac

_mo_is_macos() { [[ "$_MO_PLATFORM" == macos ]] }
_mo_is_linux() { [[ "$_MO_PLATFORM" == linux ]] }

# -- clipboard ------------------------------------------------------------------
# A clipboard tool is only usable if its display server is actually there.
# wl-copy/wl-paste and xclip/xsel are frequently installed on a desktop distro
# yet reached over SSH with no session — and they do not fail fast in that
# state: wl-copy forks to own the selection and holds the pipe open, so a bare
# `wl-paste` probe blocks forever rather than erroring. Requiring the display
# variable first makes every caller safe, including the probe itself.
_mo_clip_tool() {
	_mo_is_macos && { print -- pbcopy; return 0 }
	if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy &>/dev/null; then
		print -- wl-copy; return 0
	fi
	if [[ -n "${DISPLAY:-}" ]]; then
		command -v xclip &>/dev/null && { print -- xclip; return 0 }
		command -v xsel  &>/dev/null && { print -- xsel;  return 0 }
	fi
	return 1
}

_mo_clip() {
	local data="${1}"
	if _mo_is_macos; then
		printf '%s' "$data" | pbcopy
		return
	fi
	local tool
	if ! tool=$(_mo_clip_tool); then
		echo "_mo_clip: no usable clipboard (no WAYLAND_DISPLAY or DISPLAY)" >&2
		return 1
	fi
	if [[ "$tool" == wl-copy ]]; then
		printf '%s' "$data" | wl-copy
	elif [[ "$tool" == xclip ]]; then
		printf '%s' "$data" | xclip -selection clipboard
	else
		printf '%s' "$data" | xsel --clipboard --input
	fi
}

_mo_paste() {
	if _mo_is_macos; then
		pbpaste
		return
	fi
	local tool
	tool=$(_mo_clip_tool) || return 1
	case "$tool" in
		wl-copy) wl-paste ;;
		xclip)   xclip -selection clipboard -o ;;
		xsel)    xsel --clipboard --output ;;
	esac
}

# -- gui ------------------------------------------------------------------------
_mo_open() {
	if _mo_is_macos; then
		open "$@"
	else
		command -v xdg-open &>/dev/null \
			|| { echo "_mo_open: xdg-open not found (install xdg-utils)" >&2; return 1; }
		xdg-open "$@"
	fi
}

# -- dates ----------------------------------------------------------------------
# GNU date takes -d for both epoch and free-form input; BSD date needs -r for an
# epoch and -j -f with an explicit format for parsing, and cannot parse natural
# language at all.
_mo_epoch_to_date() {
	local epoch="$1"; shift
	local -a flags=()
	[[ "${1:-}" == "--utc" ]] && flags=(-u)
	if _mo_is_macos; then
		date $flags -r "$epoch" '+%Y-%m-%d %H:%M:%S'
	else
		date $flags -d "@$epoch" '+%Y-%m-%d %H:%M:%S'
	fi
}

# Returns 1 when the input cannot be parsed, so callers can report it.
_mo_date_to_epoch() {
	local input="$1"; shift
	local -a flags=()
	[[ "${1:-}" == "--utc" ]] && flags=(-u)
	if _mo_is_macos; then
		# -j parses without setting the clock; -f gives the input format. Without
		# -u this reads the string in local time, which is what `date -d` does.
		# BSD date fills unspecified fields from the current clock, not from
		# midnight, so a bare date parsed to a different timestamp every run
		# and disagreed with GNU date. Supply the time explicitly. The strict
		# full-datetime attempt comes first so a malformed string still fails.
		date $flags -j -f '%Y-%m-%d %H:%M:%S' "$input" '+%s' 2>/dev/null && return
		[[ "$input" =~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ]] || return 1
		date $flags -j -f '%Y-%m-%d %H:%M:%S' "$input 00:00:00" '+%s' 2>/dev/null
	else
		date $flags -d "$input" '+%s' 2>/dev/null
	fi
}

# Relative expressions GNU date parses natively. BSD date has no such grammar,
# but -v adjusts a field at a time, which covers the idioms the help advertises.
# Returns 1 when the expression is not one we can translate.
_mo_relative_to_epoch() {
	local expr="${(L)1}"
	if ! _mo_is_macos; then
		date -d "$expr" '+%s' 2>/dev/null
		return
	fi
	# GNU date is available on macOS as gdate when coreutils is installed; it
	# parses everything, so prefer it over our translation table.
	if command -v gdate &>/dev/null; then
		gdate -d "$expr" '+%s' 2>/dev/null && return
	fi
	# BSD date -v understands y/m/w/d/H/M/S and the three-letter weekday names,
	# and it PREFIX-MATCHES them: -v-month and -v-mon are byte-identical, so
	# "last month" silently resolved to last Monday. Map the calendar units
	# explicitly and only pass through real weekday names.
	local -A unit=( day d week w month m year y )
	local -a adj=()
	local word
	case "$expr" in
		now|today)      adj=(-v0H -v0M -v0S) ;;
		yesterday)      adj=(-v-1d -v0H -v0M -v0S) ;;
		tomorrow)       adj=(-v+1d -v0H -v0M -v0S) ;;
		"last "*|"next "*)
			local sign=-; [[ "$expr" == next* ]] && sign=+
			word="${expr#* }"
			if [[ -n "${unit[$word]:-}" ]]; then
				adj=(-v${sign}1${unit[$word]} -v0H -v0M -v0S)
			elif [[ "$word" == (mon|tue|wed|thu|fri|sat|sun)* ]]; then
				adj=(-v${sign}${word[1,3]} -v0H -v0M -v0S)
			else
				return 1
			fi
			;;
		<->" "(day|week|month|year)"s ago"|<->" "(day|week|month|year)" ago")
			word="${${expr#* }%% ago}"; word="${word%s}"
			[[ -n "${unit[$word]:-}" ]] || return 1
			adj=(-v-${expr%% *}${unit[$word]})
			;;
		*) return 1 ;;
	esac
	date "${adj[@]}" '+%s' 2>/dev/null
}

# True when the platform's date can parse free-form input like "yesterday".
_mo_date_parses_natural_language() { _mo_is_linux }

# -- cpu ------------------------------------------------------------------------
_mo_cpu_count() {
	if _mo_is_macos; then
		sysctl -n hw.logicalcpu 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || print -- 1
	else
		nproc 2>/dev/null || command grep -c '^processor' /proc/cpuinfo 2>/dev/null || print -- 1
	fi
}

# Apple Silicon splits cores into performance levels, so a flat count misleads.
# Returns "<level0> <level1>"; on Linux and Intel the second field is 0.
_mo_perf_cores() {
	if _mo_is_macos; then
		local p e
		p=$(sysctl -n hw.perflevel0.logicalcpu 2>/dev/null) || p=""
		e=$(sysctl -n hw.perflevel1.logicalcpu 2>/dev/null) || e=""
		if [[ -n "$p" && -n "$e" ]]; then
			print -- "$p $e"
			return
		fi
	fi
	print -- "$(_mo_cpu_count) 0"
}

# The tier names are not fixed across chips: M1-M4 report Performance and
# Efficiency, M5 reports Super and Performance. Read them rather than assume.
_mo_perf_core_names() {
	_mo_is_macos || return 1
	local n0 n1
	n0=$(sysctl -n hw.perflevel0.name 2>/dev/null) || n0=""
	n1=$(sysctl -n hw.perflevel1.name 2>/dev/null) || n1=""
	[[ -n "$n0" && -n "$n1" ]] && print -- "$n0 $n1"
}

# Display string for a core count: "6S+12P" on an M5 Pro, "10P+8E" on an M3
# Pro, a plain count on Linux and Intel.
_mo_core_summary() {
	local -a counts names
	counts=( ${(z)$(_mo_perf_cores)} )
	names=(  ${(z)$(_mo_perf_core_names 2>/dev/null)} )
	if (( ${#names} == 2 )) && (( counts[2] > 0 )); then
		print -- "${counts[1]}${names[1][1]}+${counts[2]}${names[2][1]}"
	else
		print -- "$(_mo_cpu_count)"
	fi
}

# -- memory ---------------------------------------------------------------------
# Returns "<used_bytes> <total_bytes>". Linux uses MemAvailable, which accounts
# for reclaimable cache; macOS counts active + wired + compressed, which is what
# Activity Monitor calls memory in use.
_mo_mem_stats() {
	local used=0 total=0
	if _mo_is_macos; then
		local pagesize
		total=$(sysctl -n hw.memsize 2>/dev/null)  || total=0
		pagesize=$(sysctl -n hw.pagesize 2>/dev/null) || pagesize=4096
		if command -v vm_stat &>/dev/null; then
			used=$(vm_stat 2>/dev/null | awk -v ps="$pagesize" '
				/Pages active/                 {gsub(/\./,"",$3); a=$3}
				/Pages wired down/             {gsub(/\./,"",$4); w=$4}
				/Pages occupied by compressor/ {gsub(/\./,"",$5); c=$5}
				END {printf "%.0f", (a+w+c)*ps}
			')
		fi
	else
		local total_kb avail_kb
		total_kb=$(awk '/^MemTotal:/{print $2}'     /proc/meminfo 2>/dev/null)
		avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null)
		if [[ -n "$total_kb" && -n "$avail_kb" ]]; then
			total=$(( total_kb * 1024 ))
			used=$((  (total_kb - avail_kb) * 1024 ))
		fi
	fi
	[[ -z "$used"  ]] && used=0
	[[ -z "$total" ]] && total=0
	print -- "$used $total"
}

# -- load / uptime --------------------------------------------------------------
_mo_load_avg() {
	local raw
	if _mo_is_macos; then
		raw=$(sysctl -n vm.loadavg 2>/dev/null) || raw=""
	else
		raw=$(< /proc/loadavg) 2>/dev/null || raw=""
	fi
	if [[ "$raw" =~ '([0-9]+\.[0-9]+)' ]]; then
		print -- "$match[1]"
	else
		print -- "0.00"
	fi
}

_mo_uptime_secs() {
	if _mo_is_macos; then
		local boot
		boot=$(sysctl -n kern.boottime 2>/dev/null) || boot=""
		if [[ "$boot" =~ 'sec = ([0-9]+)' ]]; then
			print -- $(( $(date +%s) - match[1] ))
			return
		fi
		print -- 0
	else
		local secs
		IFS=. read -r secs _ < /proc/uptime 2>/dev/null || secs=0
		print -- "${secs:-0}"
	fi
}

# -- identity -------------------------------------------------------------------
_mo_os_name() {
	if _mo_is_macos; then
		local name ver
		name=$(sw_vers -productName 2>/dev/null)   || name="macOS"
		ver=$(sw_vers -productVersion 2>/dev/null) || ver=""
		print -- "${name}${ver:+ $ver}"
	else
		local os_name=""
		[[ -r /etc/os-release ]] && os_name=$(
			awk -F= '$1=="PRETTY_NAME"{gsub(/"/,"",$2); print $2; exit}' /etc/os-release
		)
		print -- "${os_name:-$(command uname -s)}"
	fi
}

_mo_kernel() {
	if _mo_is_macos; then
		command uname -r
	else
		print -- "$(< /proc/sys/kernel/osrelease)"
	fi
}

_mo_arch() { command uname -m }

# -- network --------------------------------------------------------------------
# Primary outbound address. On Linux `ip route get` asks the kernel which source
# address it would use, without sending anything; on macOS the default route's
# interface is resolved instead, since en0 is not always the active one.
_mo_local_ip() {
	local ip=""
	if _mo_is_macos; then
		local iface
		for iface in $(route -n get default 2>/dev/null | awk '/interface:/{print $2}') en0 en1 en2 en3; do
			[[ -n "$iface" ]] || continue
			ip=$(ipconfig getifaddr "$iface" 2>/dev/null) && [[ -n "$ip" ]] && { print -- "$ip"; return 0 }
		done
		# ipconfig only answers for DHCP-configured interfaces, so a static
		# address or a VPN tunnel falls through to here — the same second tier
		# the Linux branch has.
		ip=$(ifconfig 2>/dev/null \
			| awk '/inet /{if ($2 != "127.0.0.1") {print $2; exit}}')
		[[ -n "$ip" ]] && { print -- "$ip"; return 0 }
	else
		ip=$(ip -4 route get 1.1.1.1 2>/dev/null \
			| awk '/src/{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
		[[ -z "$ip" ]] && ip=$(ip -4 addr show 2>/dev/null \
			| awk '/inet /{gsub(/\/.*/, "", $2); if ($2 != "127.0.0.1") {print $2; exit}}')
		[[ -n "$ip" ]] && print -- "$ip"
	fi
	return 0
}

# The CIDR of the default route's network, e.g. 192.168.1.0/24. Used to scan
# the LAN. Linux reads it from `ip route`; macOS resolves the default interface
# and converts its hex netmask.
_mo_default_subnet_cidr() {
	if ! _mo_is_macos; then
		ip -o -f inet addr show 2>/dev/null | awk '
			$4 !~ /^127\./ {print $4; exit}'
		return
	fi
	local iface addr mask
	iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
	[[ -n "$iface" ]] || return 1
	# Locate the fields by keyword, not position: a point-to-point interface
	# (any full-tunnel VPN makes the default route a utunN) prints
	# "inet 10.8.0.1 --> 10.8.0.2 netmask 0xffffffff", where $4 is the PEER
	# address. Feeding that to the arithmetic below aborts the shell with
	# "bad floating point constant", past any || return the caller wrote.
	read -r addr mask <<< "$(ifconfig "$iface" 2>/dev/null \
		| awk '/inet /{
			for (i = 1; i <= NF; i++) {
				if ($i == "inet")    a = $(i+1)
				if ($i == "netmask") m = $(i+1)
			}
			if (a != "" && m != "") { print a, m; exit }
		}')"
	[[ -n "$addr" && -n "$mask" ]] || return 1
	# Only a hex mask is safe to feed to $(( )). Written as a regex, not an
	# extended-glob pattern: this file is sourced before any setopt runs, and
	# under `zsh -f` an EXTENDED_GLOB pattern silently fails to match.
	[[ "$mask" =~ '^0x[0-9a-fA-F]+$' ]] || return 1
	# ifconfig prints the mask as 0xffffff00; count its bits for the prefix and
	# AND it with the address for the network.
	local -i m=$(( ${mask} )) prefix=0 i
	for (( i = 31; i >= 0; i-- )); do
		if (( (m >> i) & 1 )); then
			(( prefix += 1 ))
		else
			break
		fi
	done
	local -a oct=( ${(s:.:)addr} )
	local -i a=$(( (oct[1] << 24) | (oct[2] << 16) | (oct[3] << 8) | oct[4] ))
	local -i net=$(( a & m ))
	print -- "$(( (net >> 24) & 255 )).$(( (net >> 16) & 255 )).$(( (net >> 8) & 255 )).$(( net & 255 ))/$prefix"
}

# "IP:port" of an established inbound connection from <ip>, or nothing.
# Linux has `ss -tnp`; macOS has neither ss nor any iproute2 port, so netstat
# supplies the same answer without needing root.
_mo_ssh_peer() {
	local ip="$1"
	[[ -n "$ip" ]] || return 1
	if _mo_is_macos; then
		# netstat columns: Proto Recv-Q Send-Q Local Foreign (state). The
		# foreign address is $5, written 192.168.1.9.51234 — dot, not colon.
		# Anchor the match on the whole address: a bare prefix test let peer
		# 192.168.1.9 also match 192.168.1.90.
		netstat -an -p tcp 2>/dev/null | awk -v ip="$ip" '
			$NF == "ESTABLISHED" {
				addr = $5
				n = split(addr, a, ".")
				port = a[n]
				sub(/\.[0-9]+$/, "", addr)
				if (addr == ip) { print addr ":" port; exit }
			}'
	else
		# ss -tn columns: State Recv-Q Send-Q Local-Address:Port
		# Peer-Address:Port. $4 is this host's OWN address, so reporting it
		# overwrote the client IP with our own, identically for every row.
		# The peer is $5.
		ss -tnp 2>/dev/null | awk -v ip="$ip" '
			/sshd/ && index($5, ip ":") == 1 { print $5; exit }'
	fi
}

# True when this host actually accepts SSH, i.e. writing an sshd drop-in is
# meaningful. The obvious test — does /etc/ssh/sshd_config exist — is
# Debian-shaped: there the file arrives with openssh-server, but macOS ships it
# with the base OS whether or not Remote Login is ever switched on, so it never
# fired and setup would sudo a config file onto a machine that is not a server.
#
# launchctl is no help either: with Remote Login OFF it still reports
# com.openssh.sshd as "enabled" and `launchctl print` exits 0. A listener on
# port 22 is the thing that is actually true only when the service is running.
_mo_sshd_is_server() {
	if _mo_is_macos; then
		command -v lsof &>/dev/null || return 1
		lsof -nP -iTCP:22 -sTCP:LISTEN >/dev/null 2>&1
	else
		[[ -f /etc/ssh/sshd_config ]]
	fi
}

# Match processes by full command line and print "PID command-line".
#
# The flag that does this differs in meaning: procps reads -l as "print the
# NAME", so `pgrep -lf sleep` on Linux prints "1234 bash" for a shell whose
# arguments happen to contain sleep, while BSD prints the whole command line.
# procps spells the BSD behaviour -a. Same output shape either way.
_mo_pgrep_full() {
	local -a flags=()
	[[ "${1:-}" == -i ]] && { flags=(-i); shift }
	if _mo_is_macos; then
		pgrep -lf "${flags[@]}" -- "$1"
	else
		pgrep -af "${flags[@]}" -- "$1"
	fi
}

# Logged-in sessions as TSV: user, tty, login-time, idle, pid, host.
# `who -u` differs by exactly one field between the platforms (GNU prints one
# ISO date token, BSD prints "Sep  8"), so parse from the right, where both
# agree, rather than from the left.
_mo_who_sessions() {
	who -u 2>/dev/null | awk '
		NF >= 5 {
			host = ""
			last = NF
			if ($NF ~ /^\(.*\)$/) { host = substr($NF, 2, length($NF) - 2); last = NF - 1 }
			pid  = $last
			idle = $(last - 1)
			login = ""
			for (i = 3; i <= last - 2; i++) login = login (login == "" ? "" : " ") $i
			printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, login, idle, pid, host
		}'
}

# A per-user directory for short-lived secrets. Linux has XDG_RUNTIME_DIR (a
# tmpfs cleared at logout); macOS's exact analogue is TMPDIR, a per-user 0700
# directory under /var/folders. Never plain /tmp when either exists.
_mo_runtime_dir() {
	if _mo_is_macos; then
		print -- "${TMPDIR:-/tmp}"
	else
		print -- "${XDG_RUNTIME_DIR:-/tmp}"
	fi
}

# True when a font family is installed. macOS has no fontconfig, so fc-list is
# not merely missing output — it cannot answer, and treating its absence as
# "font missing" produces an unconditional false warning.
_mo_font_installed() {
	local family="$1"
	if _mo_is_macos; then
		setopt local_options extended_glob null_glob
		# Font files may spell a family with the spaces removed
		# (JetBrainsMonoNL-Regular.ttf) or kept (Andale Mono.ttf), so match a
		# pattern that allows either at each gap rather than stripping them.
		local pat="${family// /*}"
		local -a hits=(
			/System/Library/Fonts/**/${~pat}*(N.)
			/Library/Fonts/**/${~pat}*(N.)
			${HOME}/Library/Fonts/**/${~pat}*(N.)
		)
		(( ${#hits} > 0 ))
	else
		command -v fc-list &>/dev/null || return 1
		fc-list "$family" 2>/dev/null | command grep -qi "${family%% *}"
	fi
}

# Percent-used of the filesystem holding the user's data. On macOS `/` is the
# sealed, read-only system snapshot — always a couple of percent, so the
# thresholds never fire; the writable volume is /System/Volumes/Data.
_mo_disk_pct() {
	local target=/
	_mo_is_macos && [[ -d /System/Volumes/Data ]] && target=/System/Volumes/Data
	df -P "$target" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

# Octal mode of a file. GNU stat uses -c %a; BSD stat uses -f %OLp.
_mo_stat_mode() {
	if _mo_is_macos; then
		stat -f '%OLp' "$1" 2>/dev/null
	else
		stat -c '%a' "$1" 2>/dev/null
	fi
}

# The graceful restart command. Linux's reboot is a systemd unit that shuts
# services down in order; macOS reboot(8) just SIGTERMs everything, so the
# equivalent is shutdown(8), which notifies loginwindow first.
_mo_reboot_cmd() {
	if _mo_is_macos; then
		print -- "shutdown -r now"
	else
		print -- "reboot"
	fi
}

# -- file editing ---------------------------------------------------------------
# GNU sed refuses an argument to -i; BSD sed requires one.
_mo_sed_inplace() {
	local expr="$1" file="$2"
	if _mo_is_macos; then
		sed -i '' "$expr" "$file"
	else
		sed -i "$expr" "$file"
	fi
}

# -- archives -------------------------------------------------------------------
# bsdtar accepts --no-same-owner and --no-same-permissions; only GNU's
# --no-overwrite-dir has no bsdtar equivalent (it errors "Option ... is not
# supported"). bsdtar also autodetects compression, so no caller passes -z/-j/-J.
_mo_untar() {
	local archive="$1" dest="${2:-.}"
	mkdir -p "$dest"
	if _mo_is_macos; then
		tar -xf "$archive" -C "$dest" --no-same-owner --no-same-permissions
	else
		tar -xf "$archive" -C "$dest" \
			--no-overwrite-dir --no-same-owner --no-same-permissions
	fi
}

# GNU `cat -A` is shorthand for -vET. BSD cat spells the same thing -vet and
# rejects -A outright, so translate rather than pass it through.
_mo_cat_raw() {
	if _mo_is_macos; then
		local -a args=(); local a
		local -i seen_ddash=0
		for a in "$@"; do
			# Everything after -- is an operand, and a file may legitimately
			# be named -A.
			(( seen_ddash )) && { args+=("$a"); continue }
			[[ "$a" == "--" ]] && { seen_ddash=1; args+=("$a"); continue }
			# Short-option clusters only: a long option such as --show-all is
			# not -A's spelling and BSD cat has no long options at all.
			[[ "$a" == --* ]] || [[ "$a" != -*A* ]] || a="${a//A/vet}"
			args+=("$a")
		done
		command cat "${args[@]}"
	else
		command cat "$@"
	fi
}

# -- packages -------------------------------------------------------------------
_mo_pkg_manager() { _mo_is_macos && print -- brew || print -- apt }

# Debian package names that differ on Homebrew, or that have no brew formula
# because macOS already ships the tool.
# @builtin  — macOS ships this exact tool; suggesting an install is wrong.
# @none:MSG — macOS solves the same problem with a different tool, so neither
#             the Debian name nor any formula is the right advice. Saying
#             "ships with macOS — check your PATH" for these was a lie: no
#             amount of PATH hunting finds xclip or ip(8) on a Mac.
typeset -gA _MO_PKG_MACOS=(
	[build-essential]="@xcode"      [texlive-xetex]="--cask basictex"
	[fd-find]="fd"                  [xz-utils]="xz"
	[p7zip-full]="sevenzip"         [meld]="--cask meld"
	[unrar]="unar"

	# Ship with macOS.
	[procps]="@builtin"             [trash-cli]="@none:macOS ships /usr/bin/trash — no install needed"
	[bc]="@builtin"                 [coreutils]="@builtin"
	[tar]="@builtin"                [unzip]="@builtin"
	[zip]="@builtin"                [gzip]="@builtin"
	[bzip2]="@builtin"              [git]="@builtin"
	[less]="@builtin"               [curl]="@builtin"

	# Solved differently on macOS.
	[wl-clipboard]="@none:macOS uses pbcopy/pbpaste — no install needed"
	[xclip]="@none:macOS uses pbcopy/pbpaste — no install needed"
	[xsel]="@none:macOS uses pbcopy/pbpaste — no install needed"
	[xdg-utils]="@none:macOS uses open(1) — no install needed"
	[iproute2]="@none:macOS has no ip(8); ifconfig and netstat cover it"
)

# Install hint for one or more packages, phrased for the current platform:
#   Linux  → "sudo apt install fzf"
#   macOS  → "brew install fzf"
# Packages macOS already provides say so instead of suggesting a bad install.
# Formulae and casks cannot share one brew invocation, and a note about a
# built-in is not a command, so the three are emitted separately. Earlier this
# returned on the first non-formula, silently dropping every package after it.
_mo_pkg_hint() {
	if ! _mo_is_macos; then
		print -- "sudo apt install $*"
		return
	fi

	local pkg mapped
	local -a formulae=() casks=() notes=() parts=()
	for pkg in "$@"; do
		mapped="${_MO_PKG_MACOS[$pkg]:-$pkg}"
		case "$mapped" in
			@xcode)    notes+=("xcode-select --install") ;;
			@builtin)  notes+=("${pkg} ships with macOS — check your PATH") ;;
			@none:*)   notes+=("${mapped#@none:}") ;;
			"--cask "*) casks+=("${mapped#--cask }") ;;
			*)         formulae+=("$mapped") ;;
		esac
	done

	(( ${#formulae} )) && parts+=("brew install ${formulae[*]}")
	(( ${#casks}    )) && parts+=("brew install --cask ${casks[*]}")
	local out="${(j: && :)parts}"
	if (( ${#notes} )); then
		# Two packages can carry the same note — xclip and wl-copy both resolve
		# to "macOS uses pbcopy/pbpaste" — and printing it once per package put
		# the identical sentence on the line twice.
		notes=(${(u)notes})
		if [[ -n "$out" ]]; then
			# Parenthesised rather than appended after "; ". This string is
			# shown under "Install recommended packages" as a line to paste,
			# and "; macOS uses pbcopy/pbpaste" is not a command.
			out+=" (${(j:; :)notes})"
		else
			out="${(j:; :)notes}"
		fi
	fi
	print -- "$out"
}

_mo_brew_prefix() {
	_mo_is_macos || return 1
	if [[ -x /opt/homebrew/bin/brew ]]; then
		print -- /opt/homebrew
	elif [[ -x /usr/local/bin/brew ]]; then
		print -- /usr/local
	elif command -v brew &>/dev/null; then
		brew --prefix
	fi
}

# -- trash ----------------------------------------------------------------------
# Linux uses trash-cli, which implements the FreeDesktop spec and records the
# original path for us. macOS ships /usr/bin/trash, which only moves the file:
# Finder's "Put Back" location lives in a private database inside
# ~/.Trash/.DS_Store and is not readable from a shell (verified — it is in
# neither the file's xattrs nor the plain-text of that file), so mo-trash keeps
# its own index there instead.

_mo_trash_tool() {
	if _mo_is_macos; then
		command -v trash &>/dev/null && print -- trash
	else
		command -v trash-put &>/dev/null && print -- trash-put
	fi
}

_mo_trash_dir() {
	if _mo_is_macos; then
		print -- "${HOME}/.Trash"
	else
		print -- "${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
	fi
}

# Move paths to the trash, printing "<original>\t<landed basename>" per file so
# a caller can index them. Returns non-zero if any move failed.
#
# The landed name is read from the tool, never guessed: /usr/bin/trash renames
# on collision ("notes.txt" -> "notes.txt 00-32-27-841.txt"), and an index built
# from the source basename would then point at somebody else's file — restoring
# it would overwrite the wrong path.
#
# Tab and newline are legal in filenames, and the index that mo-trash keeps is
# one tab-separated record per line. Both path fields are stored with \\, \t
# and \n escaped, and decoded only at the point a reader touches the
# filesystem. Every name mo-trash passes around — index rows, trash-list
# output, the fzf picker — is in this escaped, single-line form.
#
# Both return through REPLY, not stdout: $(...) would strip a trailing newline
# from a decoded name, and forking once per index row made listing a few
# thousand entries take seconds.
_mo_trash_encode() {
	REPLY="$1"
	REPLY=${REPLY//\\/\\\\}
	REPLY=${REPLY//$'\t'/\\t}
	REPLY=${REPLY//$'\n'/\\n}
}
# The encoded form contains no backslash sequence other than \\, \t and \n,
# so echo-style escape processing is an exact inverse.
_mo_trash_decode() { REPLY="${(g::)1}" }

_mo_trash_put() {
	local tool
	tool=$(_mo_trash_tool) || return 1
	[[ -n "$tool" ]] || return 1

	# Hand the tool absolute paths, never the name as typed. A relative name
	# beginning with "-" is read as an option — /usr/bin/trash has no "--" of
	# its own and answers "Un-recognized argument" — so `rm -- -x.txt` could
	# not reach the trash at all.
	local -a srcs=()
	local f
	for f in "$@"; do srcs+=("${f:A}"); done

	if ! _mo_is_macos; then
		command "$tool" "${srcs[@]}" || return 1
		local a b
		for f in "${srcs[@]}"; do
			_mo_trash_encode "$f"; a=$REPLY
			_mo_trash_encode "${f:t}"; b=$REPLY
			printf '%s\t%s\n' "$a" "$b"
		done
		return 0
	fi

	# trash -v reports:  # Moved "<src>" to "<dest>"
	# One call per file, because the report is the only way to learn the name
	# the file landed under (the tool renames on collision) and a newline in
	# the name spreads the report over several lines. We already know <src>
	# exactly, so strip it as a literal prefix rather than parsing the line.
	local out rc=0 dest a b
	for f in "${srcs[@]}"; do
		out=$(command "$tool" -v "$f" 2>&1) || rc=$?
		if (( rc != 0 )); then print -r -- "$out" >&2; return $rc; fi
		dest=${out#"# Moved \"${f}\" to \""}
		if [[ "$dest" == "$out" || "$dest" != *\" ]]; then
			# The file is in the trash; only its landed name is unknown. Say so
			# rather than silently leaving it out of the index.
			print -r -- "rm: trashed ${f}, but could not read where it landed: ${out}" >&2
			continue
		fi
		dest=${dest%\"}
		_mo_trash_encode "$f"; a=$REPLY
		_mo_trash_encode "${dest:t}"; b=$REPLY
		printf '%s\t%s\n' "$a" "$b"
	done
}

# True when the platform's trash tool can list and restore by original path.
# trash-cli can; macOS's trash cannot, so mo-trash keeps its own index.
_mo_trash_has_restore() { _mo_is_linux }

# True when the trash directory can be enumerated. macOS protects ~/.Trash with
# TCC: readdir fails with EPERM unless the terminal has Full Disk Access, while
# opening a known path inside it still works. Without this check a directory
# scan looks like an empty trash, so "nothing to prune" and "trash is empty" get
# reported as success on a trash that is full.
_mo_trash_dir_readable() {
	local dir="${1:-$(_mo_trash_dir)}"
	[[ -d "$dir" ]] || return 1
	command ls "$dir" >/dev/null 2>&1
}

