# _mo_lan_trust.zsh — SSH wrapper for mo-lan-ssh (sourced by mo-lan-ssh.plugin.zsh)
#
# Wraps `ssh` for LAN hosts only. For every other target the wrapper does one
# associative-array lookup then falls through to `command ssh` with zero overhead.
#
# What it does for LAN targets (and only for them):
#   1. Probe with BatchMode=yes — does pubkey auth work within probe_timeout?
#      - Yes  → just ssh.
#      - Host key changed → ssh-keygen -R then re-probe. If OK → just ssh.
#      - Permission denied (password offered) → ssh-copy-id then ssh.
#
# Disable entirely with MO_LAN_AUTO_TRUST=false.

# Parse ssh argv to find the destination (first non-flag arg, skipping
# values of option-taking flags). Returns empty string if no target found.
_mo_lan_extract_target() {
    local arg next_is_value=false
    for arg in "$@"; do
        if $next_is_value; then
            next_is_value=false
            continue
        fi
        case "$arg" in
            -[BbcDEeFIiJLlmOoPpRSWwQ])
                next_is_value=true
                ;;
            -*)
                ;;
            *)
                print -- "$arg"
                return
                ;;
        esac
    done
}

_mo_lan_ssh_wrapper() {
    # Non-interactive stdin (pipe/script) → exec replaces the wrapper with the
    # real ssh binary directly (no shell waiting for a child).
    [[ -t 0 ]] || exec command ssh "$@"

    [[ "${MO_LAN_AUTO_TRUST:-true}" == "false" ]] && { command ssh "$@"; return; }

    local target target_host
    target=$(_mo_lan_extract_target "$@")
    target_host="${target##*@}"

    # Not a LAN host → pass through with zero ceremony
    if [[ -z "$target_host" || -z "${_MO_LAN_HOSTSET[$target_host]:-}" ]]; then
        command ssh "$@"
        return
    fi

    local probe_err probe_rc
    probe_err=$(command ssh -o BatchMode=yes \
                            -o ConnectTimeout="$MO_LAN_PROBE_TIMEOUT" \
                            -o StrictHostKeyChecking=accept-new \
                            "$target" true 2>&1)
    probe_rc=$?

    if (( probe_rc == 0 )); then
        command ssh "$@"
        return
    fi

    # Key mismatch → trust the LAN, purge, re-probe.
    if [[ "$probe_err" == *"REMOTE HOST IDENTIFICATION HAS CHANGED"* \
       || "$probe_err" == *"Host key verification failed"* ]]; then
        print -P "%F{yellow}[mo-lan-ssh]%f Host key changed for $target_host — purging old key (LAN host: trusted)"
        ssh-keygen -R "$target_host" >/dev/null 2>&1
        probe_err=$(command ssh -o BatchMode=yes \
                                -o ConnectTimeout="$MO_LAN_PROBE_TIMEOUT" \
                                -o StrictHostKeyChecking=accept-new \
                                "$target" true 2>&1)
        probe_rc=$?
        if (( probe_rc == 0 )); then
            command ssh "$@"
            return
        fi
    fi

    # No working key and password auth offered → run ssh-copy-id to bootstrap.
    if [[ "$probe_err" == *"Permission denied"* \
       && ( "$probe_err" == *"password"* || "$probe_err" == *"keyboard-interactive"* ) ]]; then
        print -P "%F{cyan}[mo-lan-ssh]%f No working key for $target_host — running ssh-copy-id"
        if command ssh-copy-id "$target" </dev/tty; then
            print -P "%F{green}[mo-lan-ssh]%f Key installed; reconnecting…"
        else
            print -P "%F{yellow}[mo-lan-ssh]%f ssh-copy-id failed — falling through to interactive ssh"
        fi
    elif [[ "$probe_err" == *"Permission denied"* ]]; then
        # Pubkey-only server and our keys aren't authorized — ssh-copy-id can't
        # bootstrap without password auth. Tell the user the manual path.
        print -P "%F{yellow}[mo-lan-ssh]%f $target_host accepts only pubkey auth; bootstrap manually:" >&2
        print -P "%F{245}  ssh-copy-id -f -i ~/.ssh/<your-key.pub> $target%f" >&2
    fi
    # Network errors / protocol mismatch / etc. — say nothing, let real ssh
    # emit the actual error.
    command ssh "$@"
}
