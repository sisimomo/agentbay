# syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# Base image and environment
# -----------------------------------------------------------------------------
FROM ubuntu:24.04

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
        bash bash-completion build-essential ca-certificates curl git jq nano zsh \
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
# entrypoint. The README never mounts the host docker.sock.
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
# Context7 integration
#
# Context7 is installed through npm; it is not a mise-managed toolchain. It
# uses the Node/npm runtime that mise installed above.
# -----------------------------------------------------------------------------
RUN su - dev-ai-vm -c 'mise exec -- npm install --global ctx7@latest'

# -----------------------------------------------------------------------------
# User configuration
# -----------------------------------------------------------------------------
COPY config/codex/config.toml /usr/local/share/microsandbox/codex-config.toml
COPY config/herdr/config.toml /usr/local/share/microsandbox/herdr-config.toml
COPY config/zshrc /home/dev-ai-vm/.zshrc
COPY scripts/init-config.sh /usr/local/bin/microsandbox-init-config
COPY scripts/init-runtime.sh /usr/local/bin/microsandbox-init
COPY scripts/entrypoint.sh /usr/local/bin/microsandbox-entrypoint

RUN chmod 0755 /usr/local/bin/microsandbox-init-config /usr/local/bin/microsandbox-init /usr/local/bin/microsandbox-entrypoint \
    && mkdir -p /home/dev-ai-vm/.config/herdr \
    && chown -R dev-ai-vm:dev-ai-vm /home/dev-ai-vm/.config \
    && mkdir -p /home/dev-ai-vm/.codex \
    && chown -R dev-ai-vm:dev-ai-vm /home/dev-ai-vm/.codex \
    && mkdir -p /home/dev-ai-vm \
    && chown dev-ai-vm:dev-ai-vm /home/dev-ai-vm /home/dev-ai-vm/.zshrc \
    && chown dev-ai-vm:dev-ai-vm /usr/local/share/microsandbox/herdr-config.toml

# -----------------------------------------------------------------------------
# Interactive shell defaults
# -----------------------------------------------------------------------------
RUN cat >> /etc/bash.bashrc <<'EOF'

if [[ $- == *i* ]]; then
  /usr/local/bin/microsandbox-init
fi

alias codex='command codex --dangerously-bypass-approvals-and-sandbox'

if [[ "${HERDR_ENV:-}" == "1" ]] && command -v codex &>/dev/null; then
  if [[ $- == *i* ]] && [[ -z "${HERDR_AGENT_STARTED:-}" ]]; then
    export HERDR_AGENT_STARTED=1
    codex
  fi
fi
EOF

# -----------------------------------------------------------------------------
# Runtime
# -----------------------------------------------------------------------------
WORKDIR /home/dev-ai-vm
USER dev-ai-vm
ENTRYPOINT ["/usr/local/bin/microsandbox-entrypoint"]
CMD ["zsh", "-l"]
