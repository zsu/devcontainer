FROM python:3-bookworm

ARG USERNAME=node
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    fzf \
    gh \
    git \
    gnupg2 \
    htop \
    iproute2 \
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
    tmux \
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

RUN git config --system --add safe.directory /workspace

ENV CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude
ENV XDG_CONFIG_HOME=/home/${USERNAME}/.config
ENV HISTFILE=/commandhistory/.bash_history
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

USER ${USERNAME}
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN pipx install git+https://github.com/ZeroSumQuant/claude-conversation-extractor.git

WORKDIR /workspace

CMD ["sleep", "infinity"]
