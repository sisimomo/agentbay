# Environment

You are running inside a Linux microVM (Microsandbox) on the user's macOS
host. The user's tools, credentials and SSH keys live on the host, not here.

## What you can't do

- **No SSH keys for git.** The user's git SSH keys stay on the host, so SSH
  git remotes (`git@github.com:...`) don't work from the VM.
- **No `gh` CLI and no GitHub credentials.** For anything on GitHub (PRs,
  issues, reviews, file contents, branches), use the GitHub tools from the
  `metamcp` MCP server. Don't install `gh` or ask for a token.
- **No `git push`, `git fetch` or `git pull`.** Commit locally; the user syncs
  with the remote from the host. When work is ready to share, say so.

## Network

- Internal hosts: use full hostnames (short names don't resolve). If one is
  unreachable, the VPN on the host is probably down: tell the user instead of
  retrying.
- `localhost` is the VM, not the Mac. Services running on the Mac aren't
  reachable from here, except MetaMCP.

## Tools

- You have passwordless `sudo`.
- Toolchains come from mise: Java 25, Maven 3.9, Node, Python, Go, uv, AWS CLI.
- Docker runs inside the VM, with its own daemon, images and containers. It
  can't see the host's containers. Testcontainers reuse is enabled.
- AWS profiles: `default`, `dev`, `test`, all in `us-east-1`.

## AWS access

- The AWS credentials belong to a restricted IAM user with only the policies
  this VM needs. You don't have admin access.
- An `AccessDenied` error is expected, not a bug. Don't try to work around
  it with other profiles, role assumptions or IAM changes. Tell the user
  which action and resource were denied; they can grant more access
  temporarily if needed.
