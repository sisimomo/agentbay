# agentbay

`agentbay` is a reusable AI-agent development environment for macOS. It
builds a Linux image for [Microsandbox](https://microsandbox.dev/), mounts your
host's `~/dev` directory into the VM, and starts Docker inside the VM. The
repository also runs MetaMCP and PostgreSQL with Docker Compose so tools inside
the VM can use the MetaMCP server on the host.

The normal workflow is: start the Compose services, build the image, create the
VM, and enter it with `./agentbay`.

## Initial requirements

Run the following on the macOS host:

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- The [Microsandbox CLI](https://microsandbox.dev/platform/local)
- A Git installation with `user.name` and `user.email` configured
- A clone of this repository at any local path

Verify the tools before continuing:

```bash
docker version
msb --version
msb doctor
git config --global user.name
git config --global user.email
```

The VM expects projects to live under `~/dev`. That directory is mounted at the
same path inside the VM, so paths and Git repositories work the same way on the
host and in the guest. The configuration repository itself can be cloned
anywhere; `./agentbay` resolves its own `Containerfile`, `sandbox.yaml`, and
`.env` relative to the script.

## Docker Compose setup

Docker Compose runs the host-side MetaMCP service and its PostgreSQL database.
Start it before creating the VM:

```bash
cd /path/to/agentbay/docker-compose
cp .env.example .env
openssl rand -hex 32
# Put the generated value in BETTER_AUTH_SECRET in docker-compose/.env
docker compose up -d
docker compose ps
```

MetaMCP is available on the host at `http://localhost:12008`. The VM connects
to the same service at
`http://host.microsandbox.internal:12008/metamcp/aivm/mcp`.

Create the repository-root `.env` file and add the bearer token issued by
MetaMCP. `./agentbay` loads this file when it creates or starts the VM and
when running `exec` or `herdr`, so Microsandbox can resolve the secret at runtime:

```bash
cd /path/to/agentbay
cp .env.example .env
# Edit .env and replace the placeholder METAMCP_AUTH_TOKEN
```

To stop the services without removing the database data:

```bash
cd /path/to/agentbay/docker-compose
docker compose down
```

PostgreSQL data is stored in `docker-compose/postgres_data/`. Keep that
directory to preserve the MetaMCP database between restarts.

## Build and enter AgentBay

From the repository root:

```bash
cd /path/to/agentbay
./agentbay build
./agentbay create
./agentbay exec -- zsh -l
```

You are now in the VM as the `dev-ai-vm` user. The image starts Docker inside
the VM, so `docker ps` uses the guest Docker daemon.

When `./agentbay create` runs, it initializes Codex, Herdr, and Git identity
configuration. It forwards only the host Git `user.name` and `user.email`; the
host `.gitconfig`, credential helpers, and other host-specific settings are not
mounted into the VM.

The MetaMCP token stays on the host. Microsandbox substitutes it only into
request headers sent to `host.microsandbox.internal`; it is not substituted
into URLs or request bodies.

## How `./agentbay` works

`./agentbay` is the repository's lifecycle wrapper around Docker and Microsandbox.
It uses the local `Containerfile`, `sandbox.yaml`, and repository `.env` so the
main workflow does not require memorizing long underlying commands.

| Command | Purpose |
| --- | --- |
| `./agentbay build` | Build the image and load it into Microsandbox. |
| `./agentbay create` | Create the VM and initialize its configuration. |
| `./agentbay exec -- <command>` | Run a command inside the VM. |
| `./agentbay start` | Start an existing VM. |
| `./agentbay stop` | Stop the VM while preserving its named volumes. |
| `./agentbay status` | Show the VM status. |
| `./agentbay herdr` | Run Herdr inside the VM. |
| `./agentbay recreate` | Remove and recreate the VM while keeping named volumes. |
| `./agentbay build --recreate` | Rebuild the image, load it, and recreate the VM. |

For example, after changing `Containerfile` or anything under `config/`:

```bash
./agentbay build --recreate
```

This removes only the VM. It keeps the named volumes, the host project mount,
and the Docker Compose database data.

## Direct `msb` commands

Use the underlying commands when debugging or when you need an option that the
wrapper does not expose:

```bash
docker build -f Containerfile -t agentbay:local .
docker save agentbay:local | msb load
msb create --conf /path/to/agentbay/sandbox.yaml --name agentbay \
  --net-default-egress deny \
  --net-rule "allow@public,allow@host:tcp:12008,allow@dns"
msb exec -t agentbay -- zsh -l
```

Do not run `msb volume rm` unless you intend to erase persisted Codex state or
guest Docker images. The project bind mount is not part of the image and is
preserved independently of the VM.

For troubleshooting:

```bash
msb ps -a
msb volume ls
msb logs agentbay --source all
```
