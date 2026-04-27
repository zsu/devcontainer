FROM python:3-bookworm

ARG USERNAME=node
ARG USER_UID=1000
ARG USER_GID=1000
ARG ZELLIJ_VERSION=0.43.1

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    aggregate \
    ca-certificates \
    curl \
    dnsutils \
    fzf \
    gh \
    git \
    gnupg2 \
    htop \
    iproute2 \
    ipset \
    iptables \
    jq \
    man-db \
    nano \
    nfs-common \
    nodejs \
    npm \
    procps \
    pipx \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    cron \
    unzip \
    vim \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash "${USERNAME}" \
    && mkdir -p /workspace /commandhistory /home/${USERNAME}/.claude /home/${USERNAME}/.config \
    && chown -R "${USERNAME}:${USERNAME}" /workspace /commandhistory /home/${USERNAME}

RUN echo "${USERNAME} ALL=(root) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && passwd -l root

RUN arch="$(dpkg --print-architecture)" \
    && case "${arch}" in \
        amd64) zellij_arch="x86_64-unknown-linux-musl" ;; \
        arm64) zellij_arch="aarch64-unknown-linux-musl" ;; \
        *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/zellij.tar.gz "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${zellij_arch}.tar.gz" \
    && tar -xzf /tmp/zellij.tar.gz -C /tmp \
    && install /tmp/zellij /usr/local/bin/zellij \
    && rm -f /tmp/zellij /tmp/zellij.tar.gz

RUN npm install -g @anthropic-ai/claude-code \
    && git config --system --add safe.directory /workspace \
    && git config --system --add safe.directory '/workspaces/*'

RUN printf '#!/bin/bash\n[ -d /workspaces ] && [ -n "$(ls /workspaces/ 2>/dev/null)" ] && rm -rf /workspace && ln -sf "/workspaces/$(ls /workspaces/ | head -1)" /workspace\n' \
    > /usr/local/bin/init-workspace.sh \
    && chmod +x /usr/local/bin/init-workspace.sh

COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod 0755 /usr/local/bin/init-firewall.sh

ENV CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude
ENV XDG_CONFIG_HOME=/home/${USERNAME}/.config
ENV HISTFILE=/commandhistory/.bash_history
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

USER ${USERNAME}
RUN pipx install git+https://github.com/ZeroSumQuant/claude-conversation-extractor.git

WORKDIR /workspace

CMD ["sleep", "infinity"]
