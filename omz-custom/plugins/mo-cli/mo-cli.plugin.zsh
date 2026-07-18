
_MO_INSTALL_DIR="${HOME}/.master-oogway"

_mo_version() {
	if git -C "$_MO_INSTALL_DIR" rev-parse --git-dir &>/dev/null; then
		git -C "$_MO_INSTALL_DIR" log -1 \
			--format="master-oogway %cd-%h" --date=format:"%Y-%m-%d_%H%M%S"
	else
		echo "master-oogway (unknown — $_MO_INSTALL_DIR is not a git repo)"
	fi
}

_mo_lan_scan_script() { echo "${_MO_INSTALL_DIR}/omz-custom/plugins/mo-cli/lan_scan.sh"; }

# Client side: SendEnv DRAGON__* + HashKnownHosts no in ~/.ssh/config.
_mo_lan_ssh_client() {
	local ssh_config="${HOME}/.ssh/config"
	local begin="# BEGIN master-oogway:sendenv"
	local end="# END master-oogway:sendenv"
	if grep -qF "$begin" "$ssh_config" 2>/dev/null; then
		echo "master-oogway: SendEnv already in $ssh_config"
		return 0
	fi
	mkdir -p "${HOME}/.ssh"; chmod 700 "${HOME}/.ssh"
	printf '\n%s\nHost *\n    SendEnv DRAGON__*\n    HashKnownHosts no\n%s\n' \
		"$begin" "$end" >> "$ssh_config"
	chmod 600 "$ssh_config"
	echo "master-oogway: added SendEnv DRAGON__* + HashKnownHosts no to $ssh_config"
}

# Server side: AcceptEnv DRAGON__* drop-in, validated with sshd -t (sudo).
_mo_lan_ssh_server() {
	local dropin="/etc/ssh/sshd_config.d/99-master-oogway-acceptenv.conf"
	if [[ ! -f /etc/ssh/sshd_config ]]; then
		echo "master-oogway: sshd not found — skipping AcceptEnv (not a server)"
		return 0
	fi
	if [[ -f "$dropin" ]]; then
		echo "master-oogway: AcceptEnv already in $dropin"
		return 0
	fi
	echo "master-oogway: adding $dropin so this host accepts forwarded DRAGON__* (sudo)"
	local tmp; tmp=$(mktemp)
	printf '# master-oogway: accept forwarded dragon theme vars over SSH\nAcceptEnv DRAGON__*\n' > "$tmp"
	sudo mkdir -p /etc/ssh/sshd_config.d
	sudo cp "$tmp" "$dropin"; command rm -f "$tmp"
	if ! sudo sshd -t 2>/dev/null; then
		echo "master-oogway: sshd -t failed — drop-in removed" >&2
		sudo rm -f "$dropin"; return 1
	fi
	sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true
	echo "master-oogway: added $dropin and reloaded sshd"
}

# Daily crontab line running the scan. Idempotent (marker-matched).
_mo_lan_cron() {
	local script; script=$(_mo_lan_scan_script)
	local marker="# master-oogway:lan-scan"
	if crontab -l 2>/dev/null | grep -qF "$marker"; then
		echo "master-oogway: lan-scan cron already installed"
		return 0
	fi
	{ crontab -l 2>/dev/null; printf '17 4 * * * %s >/dev/null 2>&1 %s\n' "$script" "$marker"; } \
		| crontab -
	echo "master-oogway: installed daily lan-scan cron (04:17)"
}

master-oogway() {
	local sub="${1:-help}"
	case "$sub" in
		update)
			"$_MO_INSTALL_DIR/install.sh"
			;;
		uninstall)
			"$_MO_INSTALL_DIR/install.sh" --uninstall
			;;
		version|-v|--version)
			_mo_version
			;;
		configure)
			(( $+functions[dragon-configure] )) \
				|| { echo "master-oogway: dragon-configure not found — is the dragon theme loaded?" >&2; return 1; }
			dragon-configure "${@:2}"
			;;
		edit)
			${EDITOR:-vim} "${HOME}/.zshrc"
			;;
		path)
			echo "$_MO_INSTALL_DIR"
			;;
		lan-ssh)
			local action="${2:-help}"
			local script; script=$(_mo_lan_scan_script)
			case "$action" in
				setup)
					if ! command -v nmap &>/dev/null; then
						if command -v dig &>/dev/null; then
							echo "master-oogway: nmap not found — using slower dig fallback (/24 only). Install nmap for full scans: sudo apt install nmap" >&2
						else
							echo "master-oogway: lan-ssh needs nmap to scan the LAN — install it first: sudo apt install nmap" >&2
							return 1
						fi
					fi
					_mo_lan_ssh_client
					_mo_lan_ssh_server
					_mo_lan_cron
					echo "master-oogway: running first scan..."
					"$script" || echo "master-oogway: scan failed — check subnet/nmap, retry with 'master-oogway lan-ssh refresh'" >&2
					;;
				refresh)
					"$script"
					;;
				status)
					local alias_file="${MO_CONFIG_DIR:-$HOME/.config/master-oogway}/custom-zsh/lan-hosts.zsh"
					grep -qF "# master-oogway:lan-scan" <(crontab -l 2>/dev/null) \
						&& echo "cron: installed" || echo "cron: not installed"
					if [[ -f "$alias_file" ]]; then
						echo "aliases: $(grep -c '^alias ' "$alias_file") in $alias_file"
					else
						echo "aliases: none yet ($alias_file missing)"
					fi
					;;
				*)
					echo "Usage: master-oogway lan-ssh <setup|refresh|status>" >&2
					return 1
					;;
			esac
			;;
		diff-zshrc)
			local tool="${2:-}"
			local conf_dir="${MO_CONFIG_DIR:-$HOME/.config/master-oogway}"
			local snapshot="${conf_dir}/zshrc.snapshot"
			local zshrc="${conf_dir}/zshrc"
			[[ -f "$snapshot" ]] || { echo "master-oogway: snapshot not found at $snapshot" >&2; return 1; }
			[[ -f "$zshrc" ]]    || { echo "master-oogway: $zshrc not found" >&2; return 1; }
			if diff -q "$snapshot" "$zshrc" &>/dev/null; then
				echo "$zshrc matches the installed template — no diff."
				return 0
			fi
			if [[ -n "$tool" ]]; then
				# ${=tool} splits on whitespace so 'code --diff' works.
				${=tool} "$snapshot" "$zshrc"
			elif command -v git &>/dev/null && [[ -n "$(git config --get diff.tool 2>/dev/null)" ]]; then
				git difftool --no-index "$snapshot" "$zshrc"
			else
				diff -u "$snapshot" "$zshrc"
			fi
			;;
		help|-h|--help)
			cat <<EOF
Usage: master-oogway <command> [args]

Commands:
  update               Pull latest master-oogway and re-run install.sh
  uninstall            Run install.sh --uninstall (interactive)
  version              Print the installed dragon version (date + commit)
  configure [args]     Open dragon-configure (forwards args, e.g. --pick, --preset short)
  edit                 Open ~/.zshrc in \$EDITOR
  diff-zshrc [tool]    Show diff between your ~/.zshrc and the template snapshot
					   from your last install/update. [tool] overrides;
					   otherwise uses git's diff.tool if set, else \`diff -u\`.
  path                 Print the master-oogway install dir
  lan-ssh <cmd>        LAN SSH forwarding + host aliases:
                         setup    ~/.ssh/config SendEnv + sshd AcceptEnv + daily
                                  scan cron + first scan (sudo for AcceptEnv)
                         refresh  Re-scan the LAN now, rewrite host aliases
                         status   Show cron + alias-file state
  help                 Show this message

Install dir: $_MO_INSTALL_DIR
EOF
			;;
		*)
			echo "master-oogway: unknown command '$sub' — see 'master-oogway help'" >&2
			return 1
			;;
	esac
}
