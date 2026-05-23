# mo-network

Network helpers.

**Dependencies:** `curl` (natip), `fzf` (sshto), `python3` (serve) — each checked at call time.

| Command | Description |
|---------|-------------|
| `natip` | print your public IP address |
| `serve [port]` | start a local HTTP file server (default port 8000); set `SERVE_BIND=0.0.0.0` to expose to the network |
| `sshto` | fuzzy-select an SSH host from `~/.ssh/config` and `~/.ssh/config.d/*` (Include directives followed recursively) and connect |
