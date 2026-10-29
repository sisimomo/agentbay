# Work agentbay — design

## Intent

Replace AIVM (Lima VM + a Go tool + `~/.aivm/aivm.yaml` plugin scripts) with
agentbay for professional (TouchTunes) use. AIVM is being sunset: it was a lot
of custom code to maintain for something microsandbox already does. The work
setup keeps agentbay's shape — one `Containerfile`, a thin `./agentbay` bash
wrapper, `sandbox.yaml`, `on-create`/`on-start` scripts, host-side MetaMCP via
Docker Compose — and adds only what work needs.

The source of truth for "what work needs" is the current AIVM config, copied
at `/Users/svallieres/dev/aivm-copy/aivm.yaml` (plus its `docker-compose/`).

## Goals

- Same day-to-day flow as personal agentbay: `./agentbay build`, `create`,
  `herdr`. Herdr inside the VM is the only way in.
- Every work tool, plugin, skill and MCP server that works in AIVM today works
  in the microsandbox VM.
- The VM can reach the whole company VPN (via the Mac's VPN connection).
- No secrets committed; secrets live in gitignored files (`config/home/…`, `.env`).

## Non-goals

- Keeping AIVM features agentbay never had: idle auto-stop/delete, T3 Code GUI
  and tunnel, base-image snapshots, multi-agent support (Copilot/Cursor/
  OpenCode), session tracking, staleness prompts.
- Orca agent hooks — dropped (user only uses Herdr).
- The unused `tt-tools-mcp` Dockerfile in `aivm-copy/docker-compose/` — dropped.
- MetaMCP host services / `docker-compose/` changes — user does these.
- Things the running AIVM has that are dropped by user decision:
  `hyperframes` plugin, `cocoindex-code` (+ `ccc` skill), `rtk`, `openspec`,
  `tt-sdd-harness` (and so the `ai-engineering` copy).
- The `soundwave-tools` marketplace (`sow` plugin) needs nothing here: it is
  declared and enabled in `soundwave-monorepo/.claude/settings.json`, so it
  comes with that project through the `~/dev` mount.
- Migrating AIVM's Claude session history (`aivm-copy/.claude/projects`,
  ~900 MB) into the new VM. *My call; can be added later as a one-off copy
  into the `agentbay-claude-projects` volume.*

## Anti-goals

- Reintroducing a plugin/integration framework or any generator. Plain files
  and plain shell, like personal agentbay.
- Secrets in plaintext in tracked files. (AIVM's `aivm.yaml` has AWS keys and
  a MetaMCP bearer token inline; the user may want to rotate the token.)
- Enabling msb secrets — that turns on TLS interception for all HTTPS (see
  commit 65b4e29). Pass values as plain env vars, like `METAMCP_AUTH_TOKEN`.

## Repository

- This checkout (`/Users/svallieres/dev/opensource/agentbay`) *becomes* the
  work version. Name stays `agentbay`, VM name stays `agentbay`.
- First step: `git remote remove origin` (it points to the personal
  `sisimomo/agentbay` GitHub repo). No new remote for now.
- Keep the personal pieces that still apply (context7 MCP, superpowers skills,
  zsh/starship/herdr config, ccstatusline).

## What changes

### VM resources (`sandbox.yaml`, `./agentbay`)
- `memory: 18G` (was 12G), root disk `flat:60G` (was 40G), `cpus: 4`.

### Mounts (`sandbox.yaml`)
- Keep `~/dev` bind at the same path. `backend-skills-plugin` lives under
  `~/dev`, so it is already visible.
- No Maven mount. The user copies their `settings.xml` to
  `config/home/.m2/settings.xml` (gitignored); the existing `COPY config/home/`
  puts it at `~/.m2/settings.xml` in the image. Dependencies download inside
  the VM and are re-downloaded after a recreate (accepted). *User's choice.*

### Network (`./agentbay create_vm`)
- Keep: `allow@public`, `allow@dns`, `allow@host:tcp:12008`.
- Remove: personal `allow@192.168.1.29:tcp:22`.
- Add: whole company VPN. The Mac's VPN (`utun4`) routes all of `10.0.0.0/8`,
  several `172.16–172.31` /24s and ~60 `192.168.x.0/24`s. Allow the three
  RFC1918 blocks in full: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
  *My call (user asked for "the whole VPN"): simpler than ~65 rules and
  survives VPN route changes; side effect is the home LAN is reachable too.*
- **Must verify first (spike before building the rest):**
  1. msb `--net-rule` accepts CIDR ranges (existing rule only shows a single IP).
  2. Internal hostnames (search domain `touchtunes.com`) resolve inside the VM
     through msb's DNS while the Mac is on the VPN.
  3. Traffic from the VM to a VPN address actually goes out through the Mac's
     VPN, and the microsandbox guest network doesn't collide with a
     VPN-routed range (the VPN routes `192.168.5.0/24`).
  If (2) or (3) fails, stop and bring it back to the user — the fix (custom
  DNS, different guest subnet, etc.) changes the design.

### Secrets
Secrets are plain gitignored files the user writes by hand under
`config/home/`, built into the image by the existing `COPY config/home/`
(user's choice: no mounts). Accepted cost: they are in the image and the
local registry (`localhost:5050`).
- `config/home/.aws/credentials` and `config/home/.aws/config` (`[default]`,
  `[dev]`, `[test]`, region `us-east-1`; `dev` = same keys as `default`,
  matching AIVM).
- `config/home/.m2/settings.xml` (see Mounts).
- `./agentbay build` fails with a clear message if any of the three is missing.
- `METAMCP_AUTH_TOKEN` stays in `.env` → `sandbox.yaml` env as today
  (`.claude.json` expands it).
- README documents the expected files and their format.

### Image (`Containerfile`, `config/mise.toml`)
- mise: add `uv`, `awscli` (or apt/official installer — builder's choice).
  Java 25, Maven 3.9, Node, Python already there.
- apt: `libaio1t64` (Oracle Instant Client, needed by backend-skills).

### Claude Code config (`config/home/...`)
- `settings.json`: add `"outputStyle": "Concise"`. Keep the rest, including
  agentbay's model/effort settings (AIVM had `effortLevel: medium`). *My call.*
- `.claude.json` `mcpServers`:
  - Keep `context7`.
  - `metamcp`: work MetaMCP endpoint is named `aivm`
    (`.../metamcp/aivm/mcp`). *My call: point the URL at the existing `aivm`
    endpoint so nothing in MetaMCP's UI needs to change.*
  - Add `aws-pricing-mcp-server` and `aws-documentation-mcp-server` (stdio via
    `uvx`, env exactly as in `aivm.yaml` integrations).
  - Add the eleven QA MCP servers listed in `soundwave-monorepo/.mcp.json`
    (`api-mcp`, `docdb-mcp`, `iot-mcp`, `kafka-mcp`, `moji-mcp`, `mysql-mcp`,
    `oracle-mcp`, `rabbitmq-mcp`, `tunes-mysql-mcp`, `virtual-jukebox-mcp`,
    `virtual-mobile-mcp`), each stdio:
    `command: /Users/svallieres/dev/soundwave-monorepo/.claude/mcp/qa-mcp.sh`,
    `args: ["<name>"]` — same as today's AIVM `~/.claude.json` (which lacked
    `rabbitmq-mcp`). `moji-mcp` only needs to start: its tools need kubectl +
    a browser kube login, which AIVM never had either. *My call.*
- Do not set `ENABLE_CLAUDEAI_MCP_SERVERS`; `disableClaudeAiConnectors` already
  covers it.

### Organization of configuration
Where a setting lives depends on what it is:

| Kind | Where |
| --- | --- |
| Tools identical on every VM | `config/mise.toml` or a commented `Containerfile` section |
| Hand-written config files | `config/home/…` (mirrors the guest home, copied into the image) |
| Secrets | gitignored files under `config/home/…`, and `.env` for env vars |
| Steps needing host paths/network at creation | one file per concern in `scripts/on-create.d/` |
| Steps on every start | one file per concern in `scripts/on-start.d/` |

`scripts/run-parts.sh <dir>` runs every `*.sh` in that dir in filename order
and stops at the first failure. Files are numbered (`10-…`, `20-…`) — the
number is the only ordering mechanism (user's choice over an explicit list).
Each file is standalone bash: `bash scripts/on-create.d/NN-x.sh` runs it alone.
No dependency graph, templating or generator.

on-create steps (existing ones move into this layout):
- `10-templates.sh` — existing `*.tmpl` rendering.
- `20-git.sh` — existing Git identity.
- `30-testcontainers.sh` — `~/.testcontainers.properties` with
  `testcontainers.reuse.enable=true`.
- `40-skills.sh` — existing context7 + superpowers, plus `mattpocock/skills`
  (all skills). Overlap with superpowers is accepted (user's choice).
- `50-plugins.sh` — `multi-agent-review` from GitHub marketplace
  `riekelt/multi-agent-review`, user scope.
- `60-backend-skills.sh` — copy `/Users/svallieres/dev/backend-skills-plugin`
  to `$HOME/backend-skills-plugin` if absent, run its `install.sh` with
  `SKIP_TT_ASSISTANT=1 DEBIAN_FRONTEND=noninteractive`, then delete the five
  `tt-assistant-*` skills — same as AIVM's `tt_backend_skills_plugin`.
- `70-qa-mcp.sh` — `soundwave-qa-agents/scripts/setup-mcp.sh --force`, so the
  machine-specific `.mcp-config` is regenerated for this VM. Must run after
  backend-skills (it reads config that plugin writes into `~/.claude.json`).
  `.mcp-config` lives in the shared `~/dev` tree, so this breaks AIVM's copy —
  fine, AIVM is sunset.

on-start: `10-docker.sh` — existing Docker start.

Every step that depends on a host path fails loudly if the path is missing,
rather than skipping silently.

### Host services (`docker-compose/`)
Out of scope: the user handles MetaMCP / `docker-compose/` themselves.

### README
Update for: the gitignored secret files under `config/home/`, `.env`, the
VPN rules, the host repos the VM expects under `~/dev` (`backend-skills-plugin`,
`soundwave-monorepo` with `repos/soundwave-qa-agents`), and the configuration
layout table above.

## Left to the builder
- Exact install method for uv/awscli.

## Done when
- `./agentbay build && ./agentbay create` succeeds from a clean state.
- In the VM: `claude mcp list` shows metamcp, context7, aws-*, and all QA MCP
  servers connected; `aws sts get-caller-identity` works for `default` and
  `--profile test`; `mvn -v` and a Maven build of one work repo succeed; an
  internal VPN hostname resolves and a VPN-only port is reachable; Docker and
  Testcontainers run; Herdr launches Claude with the touchtunes-backend-knowledge
  and multi-agent-review plugins, and superpowers, context7 and mattpocock
  skills loaded.
