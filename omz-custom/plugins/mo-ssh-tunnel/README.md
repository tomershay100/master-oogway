# mo-ssh-tunnel

SSH port-forwarding with a readable `tunnel <left> to <right>` syntax.

| Command | Description |
|---------|-------------|
| `tunnel [host:]<port> to [host:]<port>` | open an SSH tunnel between two endpoints |
| `tunnel -b ...` | same, run in the background (`ssh -f`) |

Each side is `[host:]port`. Host defaults to `localhost`. The SSH target and direction are inferred automatically:

| Pattern | Direction | Effect |
|---------|-----------|--------|
| `local:port to remote:port` | `-L` | connect to local port, packets exit on remote |
| `remote:port to local:port` | `-R` | connect on remote, packets exit locally |
| `port to port` | `-L` loopback | both sides local |

**Examples:**

```zsh
tunnel 9898 to momo:22               # connect to local :9898, reaches momo:22
tunnel 8080 to momo:8989             # connect to local :8080, reaches momo:8989
tunnel momo:9000 to localhost:8080   # connect on momo:9000, reaches your local :8080
tunnel 9000 to 9001                  # loopback: :9000 reaches local :9001
tunnel 0.0.0.0:9898 to momo:8700    # bind all interfaces on :9898 → momo:8700
```

**Dependencies:** `ssh`
