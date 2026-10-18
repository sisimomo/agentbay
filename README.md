# agentbay

`agentbay` is a reusable AI-agent development environment for macOS. It gives
you an isolated Linux VM where AI coding agents can work on your projects,
without giving them access to the rest of your machine.

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
- Docker available inside the VM, with its own images and containers

### Your projects
- Your host `~/dev` folder is available at the same path inside the VM
- Paths and Git repositories work the same on the host and in the VM
- Git name and email are carried over from the host; nothing else from your host Git config is shared

### AI tooling
- Claude Code and Herdr are installed and preconfigured
- Agent skills are installed for Claude Code: [context7-mcp](https://github.com/upstash/context7) and all of [Superpowers](https://github.com/obra/superpowers)
- MCP tools are shared through MetaMCP running on the host
- The MetaMCP auth token stays on the host and is never stored in the VM

### Persistence
- Claude Code state survives VM recreation
- MetaMCP database is always kept

## Requirements

On the macOS host:

- Docker Desktop
- Microsandbox CLI (`msb`)
- Git, with `user.name` and `user.email` configured
- `~/.microsandbox/config.json` marking the local image registry as plain HTTP
  (the flat root disk only accepts images pulled from a registry; `./agentbay build`
  pushes to a `registry:2` container on `localhost:5050`):

```json
{ "registries": { "hosts": { "localhost:5050": { "insecure": true } } } }
```

## Getting started

1. Start the host services: copy `docker-compose/.env.example` to `docker-compose/.env`, set `BETTER_AUTH_SECRET`, then run `docker compose up -d` in `docker-compose/`.
2. Copy `.env.example` to `.env` and set `METAMCP_AUTH_TOKEN` to the token issued by MetaMCP (http://localhost:12008).
3. Build, create and enter the VM:

```bash
./agentbay build
./agentbay create
./agentbay zsh
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
| `./agentbay herdr` | Run Herdr in the VM |
| `./agentbay exec -- <command>` | Run a command in the VM |
| `./agentbay recreate` | Remove and recreate the VM, keeping its data |
| `./agentbay build --recreate` | Rebuild the image and recreate the VM |

After changing `Containerfile` or anything under `config/`, run
`./agentbay build --recreate`.
