# games:source gibt es nur für amd64
FROM --platform=linux/amd64 ghcr.io/pterodactyl/games:source

ENV DEBIAN_FRONTEND=noninteractive

# Root für Setup
USER root

# APT robust + Git + OpenSSH-Server + gosu
RUN set -eux; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /var/lib/apt/lists/partial; \
    apt-get update -o Acquire::Retries=3; \
    apt-get install -y --no-install-recommends git ca-certificates openssh-server gosu; \
    rm -rf /var/lib/apt/lists/*; \
    # sshd vorbereiten
    mkdir -p /var/run/sshd /etc/ssh/sshd_config.d; \
    printf '%s\n' \
      'Port 2222' \
      'Protocol 2' \
      'PermitRootLogin no' \
      'PasswordAuthentication no' \
      'ChallengeResponseAuthentication no' \
      'UsePAM yes' \
      'X11Forwarding no' \
      'AllowUsers container' \
      'ClientAliveInterval 120' \
      'ClientAliveCountMax 2' \
    > /etc/ssh/sshd_config; \
    # VS Code Server & Caches (persistentes Volume)
    mkdir -p /home/container/.vscode-server /home/container/.cache /home/container/.npm

# VS Code Server persistent
ENV VSCODE_SERVER_DIR=/home/container/.vscode-server \
    XDG_CACHE_HOME=/home/container/.cache \
    NPM_CONFIG_CACHE=/home/container/.npm \
    HOME=/home/container \
    USER=container

# Boot-Wrapper als EntryPoint
COPY boot.sh /usr/local/bin/boot.sh
RUN chmod +x /usr/local/bin/boot.sh

EXPOSE 2222/tcp

# ***BOOT ALS ROOT*** (boot.sh dropt dann auf 'container')
ENTRYPOINT ["/usr/local/bin/boot.sh"]
