# Work agentbay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn this agentbay checkout into the TouchTunes work environment that replaces AIVM.

**Architecture:** Same shape as personal agentbay. Tools go in the image (`Containerfile`, `config/mise.toml`), hand-written config and gitignored secret files in `config/home/` (built into the image), and per-VM setup as numbered standalone scripts in `scripts/on-create.d/` and `scripts/on-start.d/`, run in filename order by `scripts/run-parts.sh`.

**Tech Stack:** bash, Docker, microsandbox (`msb`), mise, Claude Code CLI, jq.

**Spec:** `docs/superpowers/specs/2026-10-28-work-agentbay-design.md`

## Global Constraints

- `msb` exists only on the Mac, not in the AIVM guest where this plan may run. Steps marked **[Mac]** are run by the user; the implementer stops and asks for their output.
- Do not touch `docker-compose/` (user handles host services).
- No secret values in tracked files. Secrets: gitignored `config/home/.aws/{credentials,config}`, `config/home/.m2/settings.xml` (built into the image — accepted), and `.env`. Never enable msb secrets (TLS interception, commit 65b4e29).
- VM: `cpus: 4`, `memory: "18G"`, `--root-disk flat:60G`.
- Network rules: keep `allow@public`, `allow@dns`, `allow@host:tcp:12008`; remove `allow@192.168.1.29:tcp:22`; add `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- MetaMCP URL: `http://host.microsandbox.internal:12008/metamcp/aivm/mcp`.
- Host paths: `/Users/svallieres/dev/backend-skills-plugin`, `/Users/svallieres/dev/soundwave-monorepo/repos/soundwave-qa-agents`. A step depending on one exits non-zero with `<script>: missing <path>` on stderr if absent.
- Each step script: `#!/usr/bin/env bash`, `set -euo pipefail`, a top comment saying what and why, runnable alone with `bash <file>`.
- Not included: hyperframes, cocoindex-code, rtk, tt-sdd-harness, openspec, Orca hooks, T3 Code.

## Review Focus

- **A step fails midway.** Expected: `run-parts.sh` stops, exits non-zero, and names the failing file; later steps don't run. Pinned by Task 2 Step 1.
- **Non-`.sh` or non-executable files in the dir** (README, `.swp`). Expected: only `*.sh` run, executable bit not required. Pinned by Task 2 Step 1.
- **on-create run twice by hand.** Expected: succeeds (copies guarded by "if absent", marketplace/plugin add tolerate existing). Pinned by Task 5 Step 3.
- **Secret file missing on build.** Expected: `./agentbay build` fails before `docker build`, naming the file and pointing to the README. Pinned by Task 4 Step 2.
- **Secret file committed by accident.** Expected: `git check-ignore` matches all three secret files. Pinned by Task 4 Step 3.

---

### Task 1: Repo setup and network spike (gate)

- [ ] **Step 1: Detach and branch**
```bash
git remote remove origin
git switch -c work-setup
git add docs/superpowers && git commit -m "docs: work agentbay design and plan"
```
Expected: `git remote -v` prints nothing.

- [ ] **Step 2 [Mac]: msb grammar.** Ask the user for `msb run --help` output. Confirm `--net-rule` accepts CIDRs. If not, stop and report.

- [ ] **Step 3 [Mac]: throwaway VM on the VPN.** First find one real internal host:port from `soundwave-qa-agents/.mcp-config` or server configs (never print credentials). Ask the user, VPN connected, to run:
```bash
msb run -d --name vpn-spike --net-default-egress deny \
  --net-rule 'allow@public,allow@dns,allow@10.0.0.0/8,allow@172.16.0.0/12,allow@192.168.0.0/16' \
  ubuntu:26.04 -- sleep infinity
msb exec vpn-spike -- sh -c 'apt-get update -qq && apt-get install -y -qq netcat-openbsd iproute2 >/dev/null; ip -4 addr; ip -4 route'
msb exec vpn-spike -- getent hosts <host>
msb exec vpn-spike -- nc -vz -w 5 <host> <port>
msb rm --force vpn-spike
```
Expected: host resolves to a VPN address, `nc` succeeds, guest subnet doesn't overlap a VPN-routed range (e.g. `192.168.5.0/24`).

- [ ] **Step 4: Gate.** All pass → continue. Any fail → stop and report exact output to the user.

---

### Task 2: Step-script layout (`run-parts`)

**Files:**
- Create: `scripts/run-parts.sh`, `scripts/test-run-parts.sh`
- Create: `scripts/on-create.d/10-templates.sh`, `20-git.sh`, `40-skills.sh` (moved verbatim from `scripts/on-create.sh`)
- Create: `scripts/on-start.d/10-docker.sh` (moved from `scripts/on-start.sh`)
- Delete: `scripts/on-create.sh`, `scripts/on-start.sh`
- Modify: `Containerfile` (lifecycle section), `agentbay` (`create_vm`, `start`), `scripts/entrypoint.sh`

**Interfaces:**
- Produces: `run-parts.sh <dir>` — runs `bash <file>` for each `<dir>/*.sh` in `LC_ALL=C` sort order; on failure prints `run-parts: <file> failed` to stderr and exits with that status. Image paths: `/usr/local/lib/agentbay/{run-parts.sh,on-create.d,on-start.d}`. Entry commands stay `/usr/local/bin/agentbay-on-create` and `agentbay-on-start`, now two-line wrappers calling `run-parts.sh` on their dir, so `./agentbay` and `entrypoint.sh` keep working unchanged.

- [ ] **Step 1: Write `scripts/test-run-parts.sh`** (plain bash, temp dir): files `20-b.sh` (appends `b`), `10-a.sh` (appends `a`), `notes.md`, non-executable `30-c.sh` (appends `c`) → output `abc`; add `15-fail.sh` (`exit 3`) → exit status 3, stderr contains `15-fail.sh failed`, and `c` not appended. Print `ok: <case>`.
- [ ] **Step 2: Run** `bash scripts/test-run-parts.sh` → FAIL (no runner).
- [ ] **Step 3: Implement** `run-parts.sh`; move existing steps into the `.d` files; update `Containerfile` to `COPY` the dirs and wrappers.
- [ ] **Step 4: Verify**
```bash
bash scripts/test-run-parts.sh
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable /mnt/agentbay /mnt/scripts/*.sh /mnt/scripts/*/*.sh
docker build -t agentbay-test . && docker run --rm --entrypoint bash agentbay-test -c 'ls /usr/local/lib/agentbay/on-create.d && agentbay-on-start'
```
Expected: all `ok:`; no shellcheck output; listing shows the three files; Docker daemon starts (container may need `--privileged`; if it can't start Docker in plain Docker, verify only that `agentbay-on-start` reaches `service docker start`).
- [ ] **Step 5: Commit** `git commit -am "refactor: numbered on-create.d/on-start.d step scripts"` (plus `git add` new files).

---

### Task 3: VM sizing, network rules, image tools

**Files:** Modify `sandbox.yaml` (`memory`), `agentbay` (`create_vm`), `config/mise.toml`, `Containerfile`.

- [ ] **Step 1: Edit.** `memory: "18G"`; `--root-disk flat:60G`; `--net-rule` per Global Constraints using the grammar from Task 1, with a comment that the RFC1918 blocks are the company VPN via the Mac. mise: `uv = "latest"`, `aws-cli = "latest"` (if arm64 fails, use the official AWS CLI v2 zip in a `Containerfile` section). apt: `libaio1t64`.
- [ ] **Step 2: Verify**
```bash
bash -n agentbay
docker build -t agentbay-test . && docker run --rm --entrypoint bash agentbay-test -lc 'uv --version && aws --version && ls /usr/lib/*/libaio.so.1t64'
```
Expected: three lines, exit 0.
- [ ] **Step 3: Commit** `git commit -am "feat: work VM sizing, company VPN egress, uv/awscli/libaio"`

---

### Task 4: Secret files

**Files:** Modify `.gitignore`, `agentbay` (`build_image`), `README.md`.

- [ ] **Step 1: Ignore.** `.gitignore`: `/config/home/.aws/` and `/config/home/.m2/settings.xml`.
- [ ] **Step 2: Preflight in `build_image`** before `docker build`: for each of `config/home/.aws/credentials`, `config/home/.aws/config`, `config/home/.m2/settings.xml`, `die "missing <path> (see README: Secrets)"` if absent. Verify: `mv config/home/.aws /tmp/aws-bak 2>/dev/null; ./agentbay build` → message naming `config/home/.aws/credentials`, exit 1, no `docker build` line printed; restore.
- [ ] **Step 3: Verify ignore**
```bash
git check-ignore -q config/home/.aws/credentials config/home/.aws/config config/home/.m2/settings.xml && echo ok
```
Expected: `ok`.
- [ ] **Step 4: README "Secrets"** — copy `~/.m2/settings.xml` to `config/home/.m2/settings.xml`; create `config/home/.aws/credentials` (`[default]`, `[dev]` same keys as default, `[test]`) and `config/home/.aws/config` (`[default]`, `[profile dev]`, `[profile test]`, `region = us-east-1`), with a format example using placeholder keys. Say they are gitignored but built into the local image. `.env` still holds `METAMCP_AUTH_TOKEN`.
- [ ] **Step 5: Commit** `git commit -am "feat: AWS and Maven secrets as gitignored config files"`

---

### Task 5: Claude Code config, skills, plugins, testcontainers

**Files:** Modify `config/home/.claude/settings.json`, `config/home/.claude.json`, `scripts/on-create.d/40-skills.sh`. Create `scripts/on-create.d/30-testcontainers.sh`, `scripts/on-create.d/50-plugins.sh`.

- [ ] **Step 1: Config.**
  - `settings.json`: add `"outputStyle": "Concise"`.
  - `.claude.json` `mcpServers`: `metamcp.url` → value in Global Constraints. Add `aws-pricing-mcp-server` `{"type":"stdio","command":"uvx","args":["awslabs.aws-pricing-mcp-server@latest"],"env":{"FASTMCP_LOG_LEVEL":"ERROR","AWS_PROFILE":"default","AWS_REGION":"us-east-1"}}` and `aws-documentation-mcp-server` (args `awslabs.aws-documentation-mcp-server@latest`, env `FASTMCP_LOG_LEVEL=ERROR`, `AWS_DOCUMENTATION_PARTITION=aws`). Add the eleven QA servers `api-mcp docdb-mcp iot-mcp kafka-mcp moji-mcp mysql-mcp oracle-mcp rabbitmq-mcp tunes-mysql-mcp virtual-jukebox-mcp virtual-mobile-mcp`, each `{"type":"stdio","command":"/Users/svallieres/dev/soundwave-monorepo/.claude/mcp/qa-mcp.sh","args":["<name>"]}`.
  - Verify: `jq -e '.mcpServers|length==15' config/home/.claude.json && jq -e '.outputStyle=="Concise"' config/home/.claude/settings.json`.
- [ ] **Step 2: Scripts.** `30-testcontainers.sh` writes `testcontainers.reuse.enable=true` to `~/.testcontainers.properties` (600). `40-skills.sh` adds `npx --yes skills add mattpocock/skills --skill '*' -g -a claude-code -y --copy`. `50-plugins.sh`: `claude plugin marketplace add riekelt/multi-agent-review` then `claude plugin install multi-agent-review@multi-agent-review --scope user`, treating "already" as success.
- [ ] **Step 3: Verify (network)**
```bash
docker build -t agentbay-test . && docker run --rm --entrypoint bash agentbay-test -lc '
  d=/usr/local/lib/agentbay/on-create.d
  bash $d/30-testcontainers.sh && grep -qx testcontainers.reuse.enable=true ~/.testcontainers.properties
  bash $d/50-plugins.sh && bash $d/50-plugins.sh && claude plugin list | grep -q multi-agent-review && echo ok'
```
Expected: `ok`.
- [ ] **Step 4: Commit** `git commit -am "feat: work MCP servers, mattpocock skills, multi-agent-review, testcontainers reuse"` (plus `git add` new files).

---

### Task 6: backend-skills and QA MCP setup

**Files:** Create `scripts/on-create.d/60-backend-skills.sh`, `scripts/on-create.d/70-qa-mcp.sh`.

- [ ] **Step 1: Implement**, with overridable `BSP_SRC=/Users/svallieres/dev/backend-skills-plugin`, `QA_DIR=/Users/svallieres/dev/soundwave-monorepo/repos/soundwave-qa-agents`:
  - `60-backend-skills.sh`: missing-path check; copy to `$HOME/backend-skills-plugin` if absent (comment: copied so the installer never writes into the host repo); `SKIP_TT_ASSISTANT=1 DEBIAN_FRONTEND=noninteractive bash "$HOME/backend-skills-plugin/install.sh"`; `rm -rf` the five `tt-assistant-{action-tracker,adr-generator,enroll-speaker,meeting-extract,meeting-transcribe}` under `$HOME/.claude/plugins/local/touchtunes-backend-knowledge`.
  - `70-qa-mcp.sh`: missing-path check; `"$QA_DIR/scripts/setup-mcp.sh" --force` (comment: regenerates machine-specific `.mcp-config` in the shared tree; retires AIVM's copy).
- [ ] **Step 2: Verify missing paths**
```bash
BSP_SRC=/nonexistent bash scripts/on-create.d/60-backend-skills.sh 2>&1 | grep -q 'missing /nonexistent'
QA_DIR=/nonexistent bash scripts/on-create.d/70-qa-mcp.sh 2>&1 | grep -q 'missing /nonexistent'
```
Expected: both exit 0. Do not run the real scripts here — they rewrite shared `.mcp-config`; real verification is Task 8.
- [ ] **Step 3: Commit** `git add scripts/on-create.d && git commit -m "feat: install TouchTunes backend skills and QA MCP config on create"`

---

### Task 7: README

**Files:** Modify `README.md`.

- [ ] **Step 1: Update** Requirements / Getting started / Features / Commands: VPN egress (home LAN reachable too), secret files (Task 4), host repos expected under `~/dev`, installed skills/plugins/MCP servers, and the configuration-layout table from the spec ("where does a setting go"). Keep tone and length. No `docker-compose/` changes.
- [ ] **Step 2: Verify** `docker run --rm -v "$PWD:/w" davidanson/markdownlint-cli2:v0.14.0 /w/README.md` — no new errors.
- [ ] **Step 3: Commit** `git commit -am "docs: work setup layout and requirements"`

---

### Task 8 [Mac]: End-to-end verification

Ask the user, with VPN connected and MetaMCP running, to run and paste failures:
```bash
./agentbay build && ./agentbay create
./agentbay exec -- claude mcp list            # metamcp, context7, aws-*, 11 QA servers connected
./agentbay exec -- aws sts get-caller-identity
./agentbay exec -- aws sts get-caller-identity --profile test
./agentbay exec -- bash -lc 'cd ~/dev/<a work Maven repo> && mvn -q -DskipTests verify'
./agentbay exec -- docker run --rm hello-world
./agentbay exec -- claude plugin list         # touchtunes-backend-knowledge, multi-agent-review
./agentbay herdr                              # Claude starts; skills: superpowers, context7, mattpocock
```
Expected: all succeed. Fix failures via superpowers:systematic-debugging and re-commit.
