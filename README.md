# agentbay

`agentbay` is a reusable AI-agent development environment for macOS. It gives
you an isolated Linux VM where AI coding agents can work on your projects,
without giving them access to the rest of your machine.

This is the TouchTunes work version: it adds the company VPN, AWS and Maven
credentials, and the TouchTunes skills, plugins and MCP servers.

## Technologies

- [Microsandbox](https://microsandbox.dev/) — runs the Linux VM
- [Docker](https://www.docker.com/) — builds the VM image, runs inside the VM, and runs the host services with Docker Compose
- [MetaMCP](https://github.com/metatool-ai/metamcp) with PostgreSQL — MCP server shared with the VM
- [Claude Code](https://claude.com/claude-code) — the AI agent
- [Herdr](https://herdr.dev/) — agent session manager
- Zsh and Git — shell and version control

## Features

### Isolated environment
- Linux VM that runs separately from your Mac
- Outbound network access is restricted to what the VM needs
- The company VPN is reachable through the Mac's VPN connection (all private
  `10.0.0.0/8`, `172.16.0.0/12` and `192.168.0.0/16` ranges, so your home LAN
  is reachable too); use full internal hostnames, short names don't resolve
- Docker available inside the VM, with its own images and containers

### Your projects
- Your host `~/dev` folder is available at the same path inside the VM
- Paths and Git repositories work the same on the host and in the VM
- Git name and email are carried over from the host; nothing else from your host Git config is shared
- Java, Maven, Node, Python, uv and the AWS CLI are installed; Testcontainers
  container reuse is turned on

### AI tooling
- Claude Code and Herdr are installed and preconfigured
- Agent skills are installed for Claude Code: [context7-mcp](https://github.com/upstash/context7) and all of [Superpowers](https://github.com/obra/superpowers)
- Also installed: all of [mattpocock/skills](https://github.com/mattpocock/skills),
  the [multi-agent-review](https://github.com/riekelt/multi-agent-review)
  plugin, and the TouchTunes `touchtunes-backend-knowledge` plugin (from
  `~/dev/backend-skills-plugin`)
- MCP servers: MetaMCP (shared from the host), context7, AWS pricing and AWS
  documentation, and the eleven soundwave QA servers (`api-mcp`, `kafka-mcp`,
  `oracle-mcp`, ...)
- The MetaMCP auth token comes from `.env`, never from a tracked file

### Persistence
- Claude Code state survives VM recreation
- MetaMCP database is always kept

## Requirements

On the macOS host:

- Docker Desktop
- Microsandbox CLI (`msb`)
- Git, with `user.name` and `user.email` configured
- The company VPN connected, for anything internal
- These repos checked out under `~/dev`: `backend-skills-plugin` and
  `soundwave-monorepo` (with `repos/soundwave-qa-agents`). `./agentbay create`
  fails if one is missing.
- `~/.microsandbox/config.json` marking the local image registry as plain HTTP
  (the flat root disk only accepts images pulled from a registry; `./agentbay build`
  pushes to a `registry:2` container on `localhost:5050`):

```json
{ "registries": { "hosts": { "localhost:5050": { "insecure": true } } } }
```

## Getting started

1. Start the host services: copy `docker-compose/.env.example` to `docker-compose/.env`, set `BETTER_AUTH_SECRET`, then run `docker compose up -d` in `docker-compose/`.
2. Copy `.env.example` to `.env` and set `METAMCP_AUTH_TOKEN` to the token issued by MetaMCP (http://localhost:12008).
3. Create the AWS and Maven files described in [Secrets](#secrets).
4. Build, create and enter the VM:

```bash
./agentbay build
./agentbay create
./agentbay zsh
```

## Secrets

Secrets live in gitignored files you write by hand. `./agentbay build` stops
if one is missing.

| File | Content |
| --- | --- |
| `.env` | `METAMCP_AUTH_TOKEN` (passed to the VM as an env var) |
| `config/home/.m2/settings.xml` | A copy of your `~/.m2/settings.xml` |
| `config/home/.aws/credentials` | AWS keys: `[default]`, `[dev]` (same keys as `default`) and `[test]` |

The files under `config/home/` are copied into the image like the rest of
that folder. They never reach Git, but they are inside the local image and
the local registry (`localhost:5050`).

`config/home/.aws/credentials`:

```ini
[default]
aws_access_key_id = AKIAEXAMPLEDEFAULT
aws_secret_access_key = example-default-secret

[dev]
aws_access_key_id = AKIAEXAMPLEDEFAULT
aws_secret_access_key = example-default-secret

[test]
aws_access_key_id = AKIAEXAMPLETEST
aws_secret_access_key = example-test-secret
```

## Commands

| Command | Purpose |
| --- | --- |
| `./agentbay build` | Build the image and push/pull it via the local registry |
| `./agentbay create` | Create the VM and initialize its configuration |
| `./agentbay start` | Start an existing VM |
| `./agentbay stop` | Stop the VM, keeping its data |
| `./agentbay status` | Show the VM status |
| `./agentbay zsh` | Open a shell in the VM |
| `./agentbay install [dir]` | Symlink the CLI into `dir` (default `~/.local/bin`) so it runs from anywhere |
| `./agentbay herdr` | Run Herdr in the VM |
| `./agentbay exec -- <command>` | Run a command in the VM |
| `./agentbay ssh-setup` | Configure `ssh agentbay` on the host (also run by `create`) |
| `./agentbay recreate` | Remove and recreate the VM, keeping its data |
| `./agentbay build --recreate` | Rebuild the image and recreate the VM |

After changing `Containerfile` or anything under `config/`, run
`./agentbay build --recreate`.

### SSH from the host

The VM runs no `sshd`; `ssh agentbay` goes through msb's built-in SSH server
(`msb ssh serve --stdio`), so nothing listens on a port. `./agentbay ssh-setup`
is idempotent and:

- creates `~/.ssh/agentbay-id_ed25519` (no passphrase, used only for the VM)
  and authorizes it with `msb ssh authorize`;
- writes the `Host agentbay` block to `~/.ssh/config.d/agentbay`;
- prepends `Include config.d/agentbay` to `~/.ssh/config`.

This also makes `scp`, `rsync` and IDE remote-SSH work against `agentbay`.

## Where does a setting go?

| Kind | Where |
| --- | --- |
| Tools for every VM | `config/mise.toml` or a `Containerfile` section |
| Hand-written config files | `config/home/` (mirrors the VM home) |
| Secrets | gitignored files in `config/home/`; env vars in `.env` |
| Steps that need host paths or network | a file in `scripts/on-create.d/` |
| Steps on every start | a file in `scripts/on-start.d/` |

Steps are numbered (`10-…`, `20-…`) and run in filename order; the first
failure stops the rest. Each step is standalone:
`bash scripts/on-create.d/30-testcontainers.sh` runs just that one.
