# syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# Base image and environment
# -----------------------------------------------------------------------------
FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive

# Keep the guest home separate from the project bind mount: the host ~/dev
# is mounted at its same absolute path and must not hide guest-home state.
ENV HOME=/home/dev-ai-vm \
    SHELL=/bin/zsh \
    MISE_CONFIG_FILE=/home/dev-ai-vm/mise.toml \
    MISE_DATA_DIR=/home/dev-ai-vm/.local/share/mise \
    PATH=/home/dev-ai-vm/.local/share/mise/shims:/home/dev-ai-vm/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# -----------------------------------------------------------------------------
# Base development utilities and non-root developer account
# -----------------------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash bash-completion build-essential ca-certificates curl git jq nano zsh gettext-base \
        sudo unzip zip wget gnupg lsb-release iptables uidmap dbus-user-session \
    && rm -rf /var/lib/apt/lists/* \
    && userdel -r ubuntu 2>/dev/null || true \
    && useradd --create-home --shell /bin/zsh --uid 1000 dev-ai-vm \
    && printf 'dev-ai-vm ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/dev-ai-vm \
    && chmod 0440 /etc/sudoers.d/dev-ai-vm

# -----------------------------------------------------------------------------
# Docker Engine
#
# Docker is installed in the image and started inside the guest by the
# entrypoint workload (SysV init script, no systemd). The README never mounts
# the host docker.sock.
#
# Docker uses its default overlay2 driver. That needs an ext4 root disk, so the
# VM is created with --root-disk flat (see create_vm in ./agentbay) and
# /var/lib/docker is not a separate mount.
# -----------------------------------------------------------------------------
RUN curl -fsSL https://get.docker.com | sh

RUN usermod -aG docker dev-ai-vm

# -----------------------------------------------------------------------------
# mise-managed toolchains
# -----------------------------------------------------------------------------
RUN curl -fsSL https://mise.run | sh \
    && install -m 0755 /home/dev-ai-vm/.local/bin/mise /usr/local/bin/mise

COPY config/mise.toml /home/dev-ai-vm/mise.toml
RUN chown -R dev-ai-vm:dev-ai-vm /home/dev-ai-vm \
    && su - dev-ai-vm -c 'mise trust /home/dev-ai-vm/mise.toml && mise install --yes'

RUN cat > /etc/profile.d/mise.sh <<'EOF'
export MISE_CONFIG_FILE=/home/dev-ai-vm/mise.toml
export MISE_DATA_DIR=/home/dev-ai-vm/.local/share/mise
export PATH="$MISE_DATA_DIR/shims:$HOME/.local/bin:$PATH"
eval "$(/usr/local/bin/mise activate bash)"
EOF

# -----------------------------------------------------------------------------
# ccstatusline (Claude Code status line)
# -----------------------------------------------------------------------------
RUN su - dev-ai-vm -c 'mise exec -- npm install --global ccstatusline@latest'

# -----------------------------------------------------------------------------
# User configuration
# -----------------------------------------------------------------------------
COPY --chown=dev-ai-vm:dev-ai-vm config/home/ /home/dev-ai-vm/

# -----------------------------------------------------------------------------
# Lifecycle scripts
#
#   agentbay-on-create  once, right after the VM is created (./agentbay create)
#   agentbay-on-start   on every start (entrypoint, and ./agentbay start)
# -----------------------------------------------------------------------------
COPY --chmod=0755 scripts/on-create.sh /usr/local/bin/agentbay-on-create
COPY --chmod=0755 scripts/on-start.sh /usr/local/bin/agentbay-on-start
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/agentbay-entrypoint

# -----------------------------------------------------------------------------
# Interactive shell defaults
# -----------------------------------------------------------------------------
RUN cat >> /etc/bash.bashrc <<'EOF'

alias claude='command claude --dangerously-skip-permissions'

if [[ "${HERDR_ENV:-}" == "1" ]] && command -v claude &>/dev/null; then
  if [[ $- == *i* ]] && [[ -z "${HERDR_AGENT_STARTED:-}" ]]; then
    export HERDR_AGENT_STARTED=1
    claude
  fi
fi
EOF

# -----------------------------------------------------------------------------
# Runtime
# -----------------------------------------------------------------------------
WORKDIR /home/dev-ai-vm
USER dev-ai-vm
ENTRYPOINT ["/usr/local/bin/agentbay-entrypoint"]
