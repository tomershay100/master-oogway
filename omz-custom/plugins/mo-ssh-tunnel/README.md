# mo-ssh-tunnel

SSH port-forwarding with a readable `tunnel <left> to <right>` syntax. Direction (`-L`/`-R`) is inferred automatically from which side is local vs remote.

| Command | Description |
|---------|-------------|
| `tunnel [host:]<port> to [host:]<port>` | open an SSH tunnel between two endpoints |
| `tunnel -b [host:]<port> to [host:]<port>` | same, run in the background (`ssh -f`) |

Each side is `[host:]port`. Host defaults to `localhost`.

| Pattern | Direction | Effect |
|---------|-----------|--------|
| `local:port to remote:port` | `-L` | connect to local port, traffic exits on remote |
| `remote:port to local:port` | `-R` | connect on remote, traffic exits locally |
| `port to port` | `-L` loopback | both sides local |

## Examples

```zsh
tunnel 9898 to momo:22              # local :9898 → momo:22
tunnel momo:9000 to localhost:8080  # momo:9000 → local :8080 (reverse)
tunnel 9000 to 9001                 # loopback: :9000 → local :9001
tunnel 0.0.0.0:9898 to momo:8700   # bind all interfaces locally on :9898 → momo:8700
tunnel momo:80 to 0.0.0.0:8080     # expose momo:80 on all remote interfaces (requires GatewayPorts yes in sshd)
```

**Dependencies:** `ssh`
