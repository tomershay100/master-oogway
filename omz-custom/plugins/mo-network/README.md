# mo-network

Network helpers.

| Command | Description |
|---------|-------------|
| `natip` | print your public IP address |
| `serve [port]` | start a local HTTP file server (default port 8000) |
| `sshto` | fuzzy-select an SSH host from `~/.ssh/config` and `~/.ssh/config.d/*` and connect |

`serve` binds to `127.0.0.1` by default. Set `SERVE_BIND=0.0.0.0` to expose to the network.

**Dependencies:** `curl` for `natip`; `python3` for `serve`; `fzf` for `sshto` — each checked at call time.
