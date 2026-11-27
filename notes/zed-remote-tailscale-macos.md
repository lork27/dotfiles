# Zed Remote Development over Tailscale SSH to a macOS node (exit_code 0 bug)

Date: 2026-11-26. Machines involved: herdr machine `trabajo` = `lorca@lorcas-macbook-pro-trabajo` (macOS, Apple Silicon), reached via Tailscale.

## Symptom

`zed ssh://lorca@lorcas-macbook-pro-trabajo/Users/lorca/Development` fails with:

> Failed to connect over SSH — Client exited with exit_code 0

Local Zed log shows detection succeeding, then instant failure:

```
[remote::transport::ssh] Remote home directory discovered: Some("/Users/lorca")
[remote::remote_client] failed to establish connection: Client exited with exit_code 0
```

## Root cause

The ssh connection is intercepted by **Tailscale SSH on the remote node** (process chain shows
`tailscaled be-child ssh-monitor ...` → `/usr/bin/login -f -pq -h <ip> <user> <shell -c cmd>`).

On macOS, tailssh runs remote commands through `/usr/bin/login`, which **swallows the exit status**:
every remote ssh command returns 0 to the client, even failures.

```
ssh root@hermes 'exit 3'  # → 3   (Linux, normal)
ssh lorca@lorcas-macbook-pro-trabajo 'exit 3'  # → 0   (broken)
```

Known upstream bug: tailscale/tailscale#18256 ("Exit status not propagated to ssh client from macOS").

Consequence for Zed (v1.30.2):

1. Zed checks whether the remote server binary exists via exit code → falsely "exists".
2. Zed skips installing it (remote `~/.zed_server/` was empty).
3. Zed starts the proxy running the missing binary → it "exits with exit_code 0" → error.

## Fix / workaround

Manually install the remote server binary on the remote at the **exact** path/name Zed expects.
Newer Zed uses `~/.zed_server/zed-remote-server-stable-<version-with-build-stamp>`
(NOT the old `~/.local/share/zed/remote server/...`).

The exact expected path can be discovered by spying on Zed's ssh invocations:

```
ps -eww -o args= | grep "ssh .*lorcas-macbook"
# shows e.g.:
# cd; env .zed_server/zed-remote-server-stable-1.30.2+stable.398.610ea4b8de1c6e887f03563f067278002f41256e proxy --identifier workspace-NN
```

Re-install snippet (run after every Zed update):

```bash
ver=$(/Applications/Zed.app/Contents/MacOS/Zed --version | head -1 | awk '{print $NF}')
tag=${ver%%+*}
curl -sL "https://github.com/zed-industries/zed/releases/download/v$tag/zed-remote-server-macos-aarch64.gz" | gunzip | \
ssh lorca@lorcas-macbook-pro-trabajo "mkdir -p \$HOME/.zed_server && cat > \"\$HOME/.zed_server/zed-remote-server-stable-$ver\" && chmod +x \"\$HOME/.zed_server/zed-remote-server-stable-$ver\""
```

Caveats:

- Only works while a matching GitHub release asset exists for your Zed version.
- Alternative root fix: disable Tailscale's SSH-serving on the node so the real sshd handles
  connections and exit codes propagate, then Zed self-installs. (Would require plain key-based
  ssh to work to that host; herdr/tailssh auth currently relies on Tailscale.)

## Debugging tricks used

- `herdr machine list` → alias `trabajo` maps to `lorca@lorcas-macbook-pro-trabajo`.
- `ssh <target> 'ps -o pid,ppid,args -p $$; ...'` → revealed tailssh/login command chain.
- Zed logs: `~/Library/Logs/Zed/Zed.log`.
- Remote-side leftovers to inspect: `~/.zed_server/`, `~/Library/Application Support/Zed/server_state/`,
  `~/Library/Logs/Zed/server-<id>.log`.
- Reproducing Zed's proxy manually:
  `ssh -T <target> "cd; env '.zed_server/zed-remote-server-<name>' proxy --identifier test"` —
  stays alive once the binary exists; exits 0 on stdin EOF otherwise.
